import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { LdapService, LdapProfile } from './ldap.service';
import { regionFromSt } from '../common/regions.util';

@Injectable()
export class AuthService {
  constructor(
    private readonly ldap: LdapService,
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async login(username: string, password: string) {
    const profile = await this.ldap.authenticate(username, password);
    const existant = await this.prisma.user.findUnique({ where: { username: profile.username } });
    const role = this.resolveRole(profile, existant?.role ?? null);

    // Synchronisation AD → CRM : région (attribut `st`) et directeur (attribut `manager`).
    // Ces résolutions ne doivent jamais faire échouer le login.
    const [regionId, directeurId] = await Promise.all([
      this.syncRegion(profile.region).catch(() => null),
      this.syncDirecteur(profile).catch(() => null),
    ]);

    // Provisionnement : on crée/met à jour l'utilisateur local depuis l'AD.
    // Prisma type le champ Bytes en Uint8Array (pas Buffer).
    const photo = profile.photo ? Uint8Array.from(profile.photo) : null;

    const upsert = (idRepr: string | null) =>
      this.prisma.user.upsert({
        where: { username: profile.username },
        update: {
          displayName: profile.displayName,
          email: profile.email,
          role,
          isActive: true,
          photo,
          regionId,
          directeurId,
          ...(idRepr !== null ? { idRepr } : {}),
        },
        create: {
          username: profile.username,
          displayName: profile.displayName,
          email: profile.email,
          role,
          photo,
          idRepr,
          regionId,
          directeurId,
        },
      });

    let user;
    try {
      user = await upsert(profile.idRepr);
    } catch (err) {
      // idRepr est unique : si le code AD est déjà porté par un autre compte,
      // on n'échoue pas le login — on provisionne sans idRepr (conflit à arbitrer côté admin).
      if ((err as { code?: string })?.code === 'P2002') {
        user = await upsert(null);
      } else {
        throw err;
      }
    }

    if (!user.isActive) {
      throw new UnauthorizedException('Compte désactivé');
    }

    const accessToken = await this.jwt.signAsync({
      sub: user.id,
      username: user.username,
      role: user.role,
    });

    return {
      accessToken,
      user: {
        id: user.id,
        username: user.username,
        displayName: user.displayName,
        email: user.email,
        role: user.role,
      },
    };
  }

  /**
   * Région commerciale depuis l'attribut AD `st` : si le libellé correspond à une
   * région française connue, la Region est créée au besoin (par code) et son id renvoyé.
   * Libellé inconnu (Piemonte, Belgique…) ou vide → null.
   */
  private async syncRegion(label: string | null): Promise<string | null> {
    const ref = regionFromSt(label);
    if (!ref) return null;
    const region = await this.prisma.region.upsert({
      where: { code: ref.code },
      update: {}, // le libellé canonique ne bouge pas
      create: { code: ref.code, nom: ref.nom },
    });
    return region.id;
  }

  /**
   * Directeur depuis l'attribut AD `manager` (DN du responsable) :
   *  - un directeur est son propre manager dans l'AD → pas d'auto-référence (null) ;
   *  - le compte du directeur est provisionné a minima s'il n'a jamais ouvert de session
   *    (rôle DIRECTEUR_REGIONAL si son compte vit dans l'OU « Directeur ») ;
   *  - toute erreur de résolution → null, le login n'échoue jamais pour ça.
   */
  private async syncDirecteur(profile: LdapProfile): Promise<string | null> {
    if (!profile.managerDn) return null;
    if (profile.managerDn.toLowerCase() === profile.dn.toLowerCase()) return null;

    const manager = await this.ldap.resolveManager(profile.managerDn);
    if (!manager || manager.username.toLowerCase() === profile.username.toLowerCase()) return null;

    const existant = await this.prisma.user.findUnique({ where: { username: manager.username } });
    if (existant) return existant.id;

    // Provisionnement minimal — complété (photo, email, région…) à son premier login.
    const creer = (idRepr: string | null) =>
      this.prisma.user.create({
        data: {
          username: manager.username,
          displayName: manager.displayName,
          role: manager.estDirecteur ? Role.DIRECTEUR_REGIONAL : Role.COMMERCIAL,
          idRepr,
        },
      });
    try {
      return (await creer(manager.idRepr)).id;
    } catch (err) {
      if ((err as { code?: string })?.code === 'P2002') {
        // Code repr déjà porté par un autre compte, ou création concurrente du même login.
        const retente = await this.prisma.user.findUnique({ where: { username: manager.username } });
        if (retente) return retente.id;
        return (await creer(null)).id;
      }
      throw err;
    }
  }

  /**
   * Rôle effectif de l'utilisateur, par priorité :
   *  1. allowlist admin explicite (bootstrap) ;
   *  2. groupes AD de rôles (`LDAP_GROUP_*`) s'ils matchent ;
   *  3. rôle déjà attribué en base (manuel ou synchro) — JAMAIS rétrogradé au login ;
   *  4. première connexion : rôle suggéré par l'OU du compte (Directeur, Chef de secteur…).
   */
  private resolveRole(
    profile: { username: string; email: string | null; groups: string[]; dn: string },
    roleActuel: Role | null,
  ): Role {
    if (this.isAdminOverride(profile.username, profile.email)) return Role.ADMIN;
    // Consigne AD : l'OU où le compte est rangé fait foi pour TOUS les utilisateurs
    // (OU=Chef de secteur / Directeur / Promoteur des ventes… sous Force de vente).
    // Les groupes AD ne sont plus utilisés pour les rôles.
    const parOuFdv = this.roleParOuFdv(profile.dn);
    if (parOuFdv) return parOuFdv;
    if (roleActuel) return roleActuel;
    return this.roleParOu(profile.dn);
  }

  /** Rôle imposé par l'OU force de vente — null si le compte n'y est pas rangé. */
  private roleParOuFdv(dn: string): Role | null {
    if (/OU=Chef de secteur/i.test(dn)) return Role.CHEF_SECTEUR;
    if (/OU=Directeur/i.test(dn)) return Role.DIRECTEUR_REGIONAL;
    if (/OU=Promoteur des ventes/i.test(dn) || /OU=Responsable Merchandising/i.test(dn)) return Role.COMMERCIAL;
    return null;
  }

  /** Rôle suggéré par l'OU du compte AD (même logique que la synchro en masse). */
  private roleParOu(dn: string): Role {
    if (/OU=Directeur/i.test(dn)) return Role.DIRECTEUR_REGIONAL;
    if (/OU=Chef de secteur/i.test(dn)) return Role.CHEF_SECTEUR;
    return Role.COMMERCIAL;
  }

  /**
   * Allowlist ADMIN_USERNAMES (login ou email, séparés par des virgules, insensible à la casse).
   * Sert à désigner explicitement les premiers admins sans dépendre des groupes AD.
   */
  private isAdminOverride(username: string, email: string | null): boolean {
    const raw = this.config.get<string>('ADMIN_USERNAMES') ?? '';
    const allow = raw
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean);
    if (allow.length === 0) return false;
    const candidates = [username, email]
      .filter((v): v is string => Boolean(v))
      .map((v) => v.toLowerCase());
    return candidates.some((c) => allow.includes(c));
  }

}
