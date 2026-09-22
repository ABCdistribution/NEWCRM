import { Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from 'ldapts';

/** Profil utilisateur extrait de l'annuaire LDAP. */
export interface LdapProfile {
  username: string;
  displayName: string;
  email: string | null;
  groups: string[]; // DNs des groupes (memberOf)
  photo: Buffer | null; // thumbnailPhoto (JPEG), si présent
  idRepr: string | null; // code représentant (champ fax détourné dans l'AD ABC)
  dn: string; // distinguishedName du compte
  region: string | null; // attribut `st` (state) — région commerciale, verbatim
  managerDn: string | null; // attribut `manager` — DN du responsable hiérarchique
}

/** Fiche minimale d'un responsable résolue depuis son DN. */
export interface LdapManager {
  username: string;
  displayName: string;
  dn: string;
  idRepr: string | null;
  estDirecteur: boolean; // le compte vit dans une OU « Directeur »
}

/** Compte de la force de vente lu lors d'une synchronisation en masse. */
export interface LdapFdvEntry {
  username: string;
  displayName: string;
  email: string | null;
  dn: string;
  ou: 'Promoteur des ventes' | 'Chef de secteur' | 'Directeur' | 'Responsable Merchandising';
  region: string | null; // attribut `st`, verbatim
  managerDn: string | null;
  idRepr: string | null;
  poste: string | null; // attribut `title` — intitulé de poste
  photo: Buffer | null; // thumbnailPhoto (JPEG), si présente dans l'annuaire
}

/** OUs de la force de vente FRANÇAISE (l'Italie vit ailleurs dans l'annuaire). */
const OUS_FDV_FR = ['Promoteur des ventes', 'Chef de secteur', 'Directeur', 'Responsable Merchandising'] as const;

/**
 * Authentification "search-then-bind" contre l'AD on-premise :
 *  1. bind avec un compte de service, recherche de l'utilisateur ;
 *  2. re-bind avec le mot de passe fourni pour valider les identifiants.
 */
@Injectable()
export class LdapService {
  constructor(private readonly config: ConfigService) {}

  async authenticate(username: string, password: string): Promise<LdapProfile> {
    const url = this.config.getOrThrow<string>('LDAP_URL');
    const searchBase = this.config.getOrThrow<string>('LDAP_SEARCH_BASE');
    const bindDn = this.config.getOrThrow<string>('LDAP_BIND_DN');
    const bindPassword = this.config.getOrThrow<string>('LDAP_BIND_PASSWORD');
    const filterTpl =
      this.config.get<string>('LDAP_SEARCH_FILTER') ?? '(sAMAccountName={{username}})';
    const filter = filterTpl.replace('{{username}}', this.escape(username));
    // L'AD ABC stocke le code représentant dans le champ « fax » des commerciaux.
    const idReprAttr = this.config.get<string>('LDAP_ATTR_ID_REPR') ?? 'facsimileTelephoneNumber';

    // 1) recherche via le compte de service
    const searchClient = new Client({ url });
    let userDn: string;
    let profile: LdapProfile;
    try {
      await searchClient.bind(bindDn, bindPassword);
      const { searchEntries } = await searchClient.search(searchBase, {
        scope: 'sub',
        filter,
        attributes: ['sAMAccountName', 'displayName', 'cn', 'mail', 'memberOf', 'thumbnailPhoto', 'st', 'manager', idReprAttr],
        explicitBufferAttributes: ['thumbnailPhoto'], // sinon renvoyé en string (corrompu)
      });
      if (searchEntries.length === 0) {
        throw new UnauthorizedException('Identifiants invalides');
      }
      const entry = searchEntries[0];
      userDn = entry.dn;
      profile = {
        username: this.first(entry['sAMAccountName']) ?? username,
        displayName: this.first(entry['displayName']) ?? this.first(entry['cn']) ?? username,
        email: this.first(entry['mail']),
        groups: this.many(entry['memberOf']),
        photo: this.buffer(entry['thumbnailPhoto']),
        idRepr: this.normalizeIdRepr(this.first(entry[idReprAttr])),
        dn: entry.dn,
        region: this.first(entry['st'])?.trim() || null,
        managerDn: this.first(entry['manager'])?.trim() || null,
      };
    } catch (err) {
      if (err instanceof UnauthorizedException) throw err;
      // Bind du compte de service / connexion échoués => annuaire indisponible.
      throw new ServiceUnavailableException('Annuaire Active Directory (LDAP) injoignable');
    } finally {
      await searchClient.unbind().catch(() => undefined);
    }

    // 2) re-bind avec le mot de passe de l'utilisateur
    const userClient = new Client({ url });
    try {
      await userClient.bind(userDn, password);
    } catch {
      throw new UnauthorizedException('Identifiants invalides');
    } finally {
      await userClient.unbind().catch(() => undefined);
    }

    return profile;
  }

  /**
   * Résout la fiche d'un responsable à partir de son DN (attribut `manager`),
   * via le compte de service. Renvoie null si le DN est introuvable ou l'annuaire
   * indisponible — la synchro hiérarchie ne doit jamais faire échouer un login.
   */
  async resolveManager(managerDn: string): Promise<LdapManager | null> {
    const url = this.config.getOrThrow<string>('LDAP_URL');
    const bindDn = this.config.getOrThrow<string>('LDAP_BIND_DN');
    const bindPassword = this.config.getOrThrow<string>('LDAP_BIND_PASSWORD');
    const idReprAttr = this.config.get<string>('LDAP_ATTR_ID_REPR') ?? 'facsimileTelephoneNumber';

    const client = new Client({ url });
    try {
      await client.bind(bindDn, bindPassword);
      const { searchEntries } = await client.search(managerDn, {
        scope: 'base',
        filter: '(objectClass=user)',
        attributes: ['sAMAccountName', 'displayName', 'cn', idReprAttr],
      });
      if (searchEntries.length === 0) return null;
      const entry = searchEntries[0];
      const username = this.first(entry['sAMAccountName']);
      if (!username) return null;
      return {
        username,
        displayName: this.first(entry['displayName']) ?? this.first(entry['cn']) ?? username,
        dn: entry.dn,
        idRepr: this.normalizeIdRepr(this.first(entry[idReprAttr])),
        estDirecteur: /OU=Directeur/i.test(entry.dn),
      };
    } catch {
      return null;
    } finally {
      await client.unbind().catch(() => undefined);
    }
  }

  /**
   * Liste les comptes actifs de la force de vente française (OUs Promoteur des ventes,
   * Chef de secteur, Directeur, Responsable Merchandising), via le compte de service.
   * Sert à la synchronisation en masse déclenchée par un admin.
   */
  async listForceDeVente(): Promise<LdapFdvEntry[]> {
    const url = this.config.getOrThrow<string>('LDAP_URL');
    const searchBase = this.config.getOrThrow<string>('LDAP_SEARCH_BASE');
    const bindDn = this.config.getOrThrow<string>('LDAP_BIND_DN');
    const bindPassword = this.config.getOrThrow<string>('LDAP_BIND_PASSWORD');
    const idReprAttr = this.config.get<string>('LDAP_ATTR_ID_REPR') ?? 'facsimileTelephoneNumber';

    const client = new Client({ url });
    try {
      await client.bind(bindDn, bindPassword);
      // Comptes utilisateurs actifs uniquement (bit 2 = ACCOUNTDISABLE).
      const { searchEntries } = await client.search(searchBase, {
        scope: 'sub',
        filter: '(&(objectClass=user)(objectCategory=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))',
        attributes: ['sAMAccountName', 'displayName', 'cn', 'mail', 'st', 'manager', 'title', 'thumbnailPhoto', idReprAttr],
        explicitBufferAttributes: ['thumbnailPhoto'], // sinon renvoyé en string (corrompu)
        sizeLimit: 1000,
      });

      const entries: LdapFdvEntry[] = [];
      for (const entry of searchEntries) {
        const ou = OUS_FDV_FR.find((o) => entry.dn.toLowerCase().includes(`ou=${o.toLowerCase()}`));
        const username = this.first(entry['sAMAccountName']);
        if (!ou || !username) continue;
        entries.push({
          username,
          displayName: this.first(entry['displayName']) ?? this.first(entry['cn']) ?? username,
          email: this.first(entry['mail']),
          dn: entry.dn,
          ou,
          region: this.first(entry['st'])?.trim() || null,
          managerDn: this.first(entry['manager'])?.trim() || null,
          idRepr: this.normalizeIdRepr(this.first(entry[idReprAttr])),
          poste: this.first(entry['title'])?.trim() || null,
          photo: this.buffer(entry['thumbnailPhoto']),
        });
      }
      return entries;
    } catch {
      throw new ServiceUnavailableException('Annuaire Active Directory (LDAP) injoignable');
    } finally {
      await client.unbind().catch(() => undefined);
    }
  }

  private first(value: unknown): string | null {
    if (Array.isArray(value)) return value.length ? String(value[0]) : null;
    return value != null ? String(value) : null;
  }

  private many(value: unknown): string[] {
    if (Array.isArray(value)) return value.map((v) => String(v));
    return value != null ? [String(value)] : [];
  }

  /** Extrait un Buffer non vide d'un attribut binaire (Buffer ou tableau de Buffer). */
  private buffer(value: unknown): Buffer | null {
    const b = Array.isArray(value) ? value[0] : value;
    return Buffer.isBuffer(b) && b.length > 0 ? b : null;
  }

  /**
   * Extrait le code représentant lu dans l'AD, SANS le modifier.
   * Le champ étant un « fax » détourné, on n'accepte qu'une valeur numérique courte
   * (1 à 5 chiffres) ; tout le reste (vrai n° de fax, valeurs type « M6 ») est ignoré.
   * L'équivalence avec le format Minos (« 068 » sur 3 chiffres) est gérée au moment
   * des comparaisons, pas au stockage.
   */
  private normalizeIdRepr(raw: string | null): string | null {
    const v = raw?.trim();
    if (!v || !/^\d{1,5}$/.test(v)) return null;
    return v;
  }

  /** Échappe les caractères spéciaux d'un filtre LDAP (RFC 4515). */
  private escape(input: string): string {
    return input.replace(/[\\*()\0/]/g, (c) => '\\' + c.charCodeAt(0).toString(16).padStart(2, '0'));
  }
}
