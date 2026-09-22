import { Injectable, Logger } from '@nestjs/common';
import { Role } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { LdapService, LdapFdvEntry } from './ldap.service';
import { regionFromSt } from '../common/regions.util';

/** Rôle imposé par l'OU du compte (consigne AD) — appliqué à la création ET à la mise à jour. */
const ROLE_PAR_OU: Record<LdapFdvEntry['ou'], Role> = {
  'Promoteur des ventes': Role.COMMERCIAL,
  'Chef de secteur': Role.CHEF_SECTEUR,
  Directeur: Role.DIRECTEUR_REGIONAL,
  'Responsable Merchandising': Role.COMMERCIAL,
};

/** Champs en conflit d'unicité d'une erreur P2002 (Prisma 7 + driver adapter : meta.target n'est plus fiable). */
function champsConflit(err: unknown): string {
  const e = err as {
    meta?: {
      target?: unknown;
      driverAdapterError?: { cause?: { constraint?: { fields?: unknown[] } } };
    };
  };
  const t = e?.meta?.target;
  const f = e?.meta?.driverAdapterError?.cause?.constraint?.fields;
  return [...(Array.isArray(t) ? t : t ? [t] : []), ...(Array.isArray(f) ? f : [])].join(',');
}

function estP2002(err: unknown): boolean {
  return (err as { code?: string })?.code === 'P2002';
}

export interface AdSyncResult {
  lus: number;
  crees: number;
  maj: number;
  photos: number; // comptes dont la photo AD a été rapatriée
  directeursLies: number;
  sansRegion: string[]; // logins sans région française reconnue
  sansManager: string[]; // logins sans manager résolu (hors directeurs eux-mêmes)
  conflitsIdRepr: string[]; // codes déjà portés par un autre compte
}

/**
 * Synchronisation en masse AD → CRM de la force de vente française :
 * provisionne les promoteurs / chefs de secteur / directeurs, rattache
 * chaque compte à sa région (attribut `st`) et à son directeur (attribut `manager`).
 * Le rôle suit l'OU (consigne AD) ; l'activation d'un compte existant n'est jamais touchée.
 */
@Injectable()
export class AdSyncService {
  private readonly logger = new Logger(AdSyncService.name);

  constructor(
    private readonly ldap: LdapService,
    private readonly prisma: PrismaService,
  ) {}

  async syncForceDeVente(): Promise<AdSyncResult> {
    const entries = await this.ldap.listForceDeVente();
    const result: AdSyncResult = {
      lus: entries.length,
      crees: 0,
      maj: 0,
      photos: 0,
      directeursLies: 0,
      sansRegion: [],
      sansManager: [],
      conflitsIdRepr: [],
    };

    // Cache code région → id (création à la volée).
    const regionIds = new Map<string, string>();
    const regionId = async (st: string | null): Promise<string | null> => {
      const ref = regionFromSt(st);
      if (!ref) return null;
      if (!regionIds.has(ref.code)) {
        const region = await this.prisma.region.upsert({
          where: { code: ref.code },
          update: {},
          create: { code: ref.code, nom: ref.nom },
        });
        regionIds.set(ref.code, region.id);
      }
      return regionIds.get(ref.code)!;
    };

    // --- Passe 1 : upsert des comptes (sans la hiérarchie) -----------------
    const idParDn = new Map<string, string>(); // DN (minuscule) → user.id
    const idParUsername = new Map<string, string>();

    for (const e of entries) {
      const rId = await regionId(e.region);
      if (!rId) result.sansRegion.push(e.username);

      const existant = await this.prisma.user.findUnique({ where: { username: e.username } });
      let userId: string;
      if (existant) {
        // Mise à jour : identité + profil (poste, email, photo AD) + région + code repr —
        // rôle et activation préservés. La photo n'est jamais effacée si l'AD n'en a pas.
        const data: {
          displayName: string;
          regionId: string | null;
          poste: string | null;
          role?: Role;
          idRepr?: string;
          email?: string;
          photo?: Uint8Array<ArrayBuffer>;
        } = {
          displayName: e.displayName,
          regionId: rId,
          poste: e.poste,
        };
        // L'OU fait foi pour le rôle (consigne AD) — un ADMIN n'est jamais rétrogradé.
        if (existant.role !== 'ADMIN' && existant.role !== ROLE_PAR_OU[e.ou]) {
          data.role = ROLE_PAR_OU[e.ou];
        }
        if (e.idRepr && existant.idRepr !== e.idRepr) data.idRepr = e.idRepr;
        if (e.email && existant.email !== e.email) data.email = e.email;
        if (e.photo) data.photo = Uint8Array.from(e.photo);
        try {
          await this.prisma.user.update({ where: { id: existant.id }, data });
        } catch (err) {
          if (!estP2002(err)) throw err;
          // Conflit d'unicité (idRepr ou email déjà portés par un autre compte) :
          // on lâche le champ fautif — ou les deux si le champ n'est pas identifiable.
          const cible = champsConflit(err);
          if (cible.includes('idRepr') || !cible) {
            if (data.idRepr) result.conflitsIdRepr.push(`${e.username} (${e.idRepr})`);
            delete data.idRepr;
          }
          if (cible.includes('email') || !cible) delete data.email;
          try {
            await this.prisma.user.update({ where: { id: existant.id }, data });
          } catch (err2) {
            if (!estP2002(err2)) throw err2;
            delete data.idRepr;
            delete data.email;
            await this.prisma.user.update({ where: { id: existant.id }, data });
          }
        }
        result.maj += 1;
        if (e.photo) result.photos += 1;
        userId = existant.id;
      } else {
        const creer = (idRepr: string | null, email: string | null) =>
          this.prisma.user.create({
            data: {
              username: e.username,
              displayName: e.displayName,
              email,
              role: ROLE_PAR_OU[e.ou],
              idRepr,
              regionId: rId,
              poste: e.poste,
              photo: e.photo ? Uint8Array.from(e.photo) : null,
            },
          });
        let user;
        try {
          user = await creer(e.idRepr, e.email);
        } catch (err) {
          if (!estP2002(err)) throw err;
          const cible = champsConflit(err);
          if (cible.includes('email') && !cible.includes('idRepr')) {
            // Email déjà pris (autre compte) : on garde le code, on lâche l'email.
            user = await creer(e.idRepr, null);
          } else {
            // Code repr déjà porté (doublons AD : 109, 104, 701…) — cascade prudente.
            result.conflitsIdRepr.push(`${e.username} (${e.idRepr})`);
            try {
              user = await creer(null, e.email);
            } catch (err2) {
              if (!estP2002(err2)) throw err2;
              user = await creer(null, null);
            }
          }
        }
        result.crees += 1;
        if (e.photo) result.photos += 1;
        userId = user.id;
      }
      idParDn.set(e.dn.toLowerCase(), userId);
      idParUsername.set(e.username.toLowerCase(), userId);
    }

    // --- Passe 2 : hiérarchie (manager → directeurId) ----------------------
    for (const e of entries) {
      const userId = idParUsername.get(e.username.toLowerCase())!;
      const estSonPropreManager =
        e.managerDn != null && e.managerDn.toLowerCase() === e.dn.toLowerCase();
      const directeurId =
        e.managerDn && !estSonPropreManager ? (idParDn.get(e.managerDn.toLowerCase()) ?? null) : null;

      if (directeurId) result.directeursLies += 1;
      else if (e.ou !== 'Directeur' && !estSonPropreManager) result.sansManager.push(e.username);

      await this.prisma.user.update({ where: { id: userId }, data: { directeurId } });
    }

    this.logger.log(
      `Synchro AD force de vente : ${result.lus} lus, ${result.crees} créés, ${result.maj} mis à jour, ${result.directeursLies} rattachés à un directeur`,
    );
    return result;
  }
}
