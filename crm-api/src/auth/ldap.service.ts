import { Injectable, Logger, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
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
 * Nombre maximal de comptes lus par la synchro en masse. L'AD plafonne de toute façon une requête non paginée à 1000 ;
 * ldapts ne lève PAS d'erreur à la limite (il rend les 1000 premiers) : atteindre ce nombre signale donc une lecture
 * probablement tronquée, que la synchro remonte à l'administrateur.
 */
export const LIMITE_LECTURE_AD = 1000;

/** Délais par défaut (ms) des échanges avec l'AD ; sans eux, un annuaire muet laisse la requête suspendue sans fin. */
const DELAI_CONNEXION_MS = 10_000;
const DELAI_OPERATION_MS = 120_000;

/** Cause d'une erreur LDAP pour le journal du serveur (nom et message tronqués ; jamais de mot de passe dedans). */
function detailErreur(err: unknown): string {
  const e = err as { name?: unknown; message?: unknown } | null;
  const nom = typeof e?.name === 'string' ? e.name : 'Erreur';
  const message = typeof e?.message === 'string' ? e.message : String(err);
  return `${nom} : ${message}`.replace(/\s+/g, ' ').slice(0, 300);
}

/**
 * Authentification "search-then-bind" contre l'AD on-premise :
 *  1. bind avec un compte de service, recherche de l'utilisateur ;
 *  2. re-bind avec le mot de passe fourni pour valider les identifiants.
 */
@Injectable()
export class LdapService {
  private readonly logger = new Logger(LdapService.name);

  constructor(private readonly config: ConfigService) {}

  /**
   * Délais des échanges avec l'AD, surchargeables par `LDAP_CONNECT_TIMEOUT_MS` et `LDAP_TIMEOUT_MS` (entiers > 0).
   * Les DEUX sont nécessaires : `connectTimeout` ne couvre que l'établissement de la connexion, `timeout` chaque
   * opération (bind, recherche) ; ldapts les laisse tous deux à « illimité » par défaut.
   */
  private delais(): { connectTimeout: number; timeout: number } {
    const lire = (cle: string, defaut: number) => {
      const n = Number(this.config.get<string>(cle));
      return Number.isInteger(n) && n > 0 ? n : defaut;
    };
    return {
      connectTimeout: lire('LDAP_CONNECT_TIMEOUT_MS', DELAI_CONNEXION_MS),
      timeout: lire('LDAP_TIMEOUT_MS', DELAI_OPERATION_MS),
    };
  }

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
   * `tronque` : la lecture a atteint la limite (LIMITE_LECTURE_AD) ; des comptes de la force de vente ont pu être
   * ignorés, l'annuaire contenant plus de comptes actifs que la limite (le filtre d'OU se fait après la lecture).
   */
  async listForceDeVente(): Promise<{ entrees: LdapFdvEntry[]; tronque: boolean }> {
    const url = this.config.getOrThrow<string>('LDAP_URL');
    const searchBase = this.config.getOrThrow<string>('LDAP_SEARCH_BASE');
    const bindDn = this.config.getOrThrow<string>('LDAP_BIND_DN');
    const bindPassword = this.config.getOrThrow<string>('LDAP_BIND_PASSWORD');
    const idReprAttr = this.config.get<string>('LDAP_ATTR_ID_REPR') ?? 'facsimileTelephoneNumber';

    const client = new Client({ url, ...this.delais() });
    try {
      await client.bind(bindDn, bindPassword);
      // Comptes utilisateurs actifs uniquement (bit 2 = ACCOUNTDISABLE).
      const { searchEntries } = await client.search(searchBase, {
        scope: 'sub',
        filter: '(&(objectClass=user)(objectCategory=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))',
        attributes: ['sAMAccountName', 'displayName', 'cn', 'mail', 'st', 'manager', 'title', 'thumbnailPhoto', idReprAttr],
        explicitBufferAttributes: ['thumbnailPhoto'], // sinon renvoyé en string (corrompu)
        sizeLimit: LIMITE_LECTURE_AD,
      });
      const tronque = searchEntries.length >= LIMITE_LECTURE_AD;
      if (tronque) {
        this.logger.warn(
          `Synchro AD : ${searchEntries.length} comptes lus, limite atteinte (${LIMITE_LECTURE_AD}) : des comptes de la force de vente ont pu être ignorés.`,
        );
      }

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
      return { entrees: entries, tronque };
    } catch (err) {
      // La cause (délai dépassé, connexion refusée, compte de service refusé…) n'est jamais montrée au navigateur,
      // mais elle est journalisée : sans cela, rien ne distingue les pannes.
      this.logger.error(`Synchro AD : lecture de l'annuaire impossible (${detailErreur(err)})`);
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
