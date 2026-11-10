import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, Role, User } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { idReprVariants } from '../common/id-repr.util';
import { CARTE_LIMITE_POINTS, canonRepr } from './carte.util';
import { QueryCarteSecteurDto } from './dto/query-carte-secteur.dto';

type Appelant = Pick<User, 'id' | 'role' | 'regionId'>;

interface SecteurVisible {
  id: string;
  code: string;
  nom: string;
  regionId: string | null;
  managerId: string | null;
}

/** Activité d'un collaborateur (ou d'une région) sur le mois : visites, commandes, CA en euros, objectif mensuel et taux. */
export interface Activite {
  visites: number;
  commandes: number;
  ca: number;
  objectif: number | null;
  tauxPct: number | null;
}

/** Collaborateur avec son intitulé de poste AD et son activité du mois. */
export type MembreEquipe = { id: string; displayName: string; poste: string | null } & Activite;

/** Clients réels (non supprimés) du périmètre, hors pseudo-clients sans adresse française. */
const CLIENTS_ACTIFS = { deletedAt: null } as const;

@Injectable()
export class CarteService {
  constructor(private readonly prisma: PrismaService) {}

  private estPrivilegie(me: Appelant): boolean {
    return me.role === Role.ADMIN || me.role === Role.DIRECTION;
  }

  /**
   * Secteurs que `me` peut voir (même logique que `auteursVisibles` des rapports et `UsersService.findAll`) :
   *  - ADMIN / DIRECTION : tous ;
   *  - DIRECTEUR_REGIONAL : ceux de sa région, ceux qu'il manage et ceux dont le chef est dans son équipe directe ;
   *  - CHEF_SECTEUR : uniquement les secteurs dont il est le manager.
   */
  private async secteursVisibles(me: Appelant): Promise<SecteurVisible[]> {
    let where: Prisma.SecteurWhereInput;
    if (this.estPrivilegie(me)) where = {};
    else if (me.role === Role.DIRECTEUR_REGIONAL) {
      where = {
        OR: [
          { managerId: me.id },
          { manager: { directeurId: me.id } },
          ...(me.regionId ? [{ regionId: me.regionId }] : []),
        ],
      };
    } else if (me.role === Role.CHEF_SECTEUR) where = { managerId: me.id };
    else throw new ForbiddenException('Accès réservé à la direction, aux directeurs régionaux et aux chefs de secteur.');

    return this.prisma.secteur.findMany({
      where,
      orderBy: { code: 'asc' },
      select: { id: true, code: true, nom: true, regionId: true, managerId: true },
    });
  }

  // --- GET /dashboard/carte-equipes ----------------------------------------------------------------------------------

  /**
   * Carte des équipes. `annee` / `mois` : période de l'activité affichée (visites, commandes, CA et objectif du mois).
   * Même règle que le tableau de bord de direction : le CA vient des commandes non annulées du code représentant du
   * collaborateur ; son objectif mensuel est la somme des objectifs annuels de ses magasins divisée par 12.
   * Le périmètre est celui des collaborateurs visibles ci-dessous : aucune donnée hors périmètre n'est lue.
   */
  async carteEquipes(me: Appelant, annee: number, mois: number) {
    const secteurs = await this.secteursVisibles(me);
    const secteurIds = secteurs.map((s) => s.id);
    const managerIds = [...new Set(secteurs.map((s) => s.managerId).filter((x): x is string => !!x))];

    // Collaborateurs du périmètre (actifs : directeurs régionaux, chefs de secteur et promoteurs).
    const scopeUsers: Prisma.UserWhereInput[] = [];
    if (me.role === Role.DIRECTEUR_REGIONAL) {
      scopeUsers.push({ directeurId: me.id });
      if (me.regionId) scopeUsers.push({ regionId: me.regionId });
    } else if (me.role === Role.CHEF_SECTEUR) {
      scopeUsers.push({ id: me.id }, { directeurId: me.id });
    }
    if (!this.estPrivilegie(me)) {
      if (secteurIds.length) scopeUsers.push({ secteurId: { in: secteurIds } });
      if (managerIds.length) scopeUsers.push({ id: { in: managerIds } });
    }

    const [users, parSecteur, parCode1, parCode2] = await Promise.all([
      this.prisma.user.findMany({
        where: {
          isActive: true,
          role: { in: [Role.COMMERCIAL, Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL] },
          ...(scopeUsers.length ? { OR: scopeUsers } : {}),
        },
        orderBy: { displayName: 'asc' },
        select: {
          id: true,
          displayName: true,
          role: true,
          poste: true,
          idRepr: true,
          regionId: true,
          secteurId: true,
          directeurId: true,
          secteur: { select: { id: true, code: true, nom: true, regionId: true, managerId: true } },
        },
      }),
      secteurIds.length
        ? this.prisma.client.groupBy({
            by: ['secteurId'],
            where: { ...CLIENTS_ACTIFS, secteurId: { in: secteurIds } },
            _count: { _all: true },
          })
        : [],
      secteurIds.length
        ? this.prisma.client.groupBy({
            by: ['idCommercial1'],
            where: { ...CLIENTS_ACTIFS, secteurId: { in: secteurIds }, idCommercial1: { not: null } },
            _count: { _all: true },
          })
        : [],
      secteurIds.length
        ? this.prisma.client.groupBy({
            by: ['idCommercial2'],
            where: { ...CLIENTS_ACTIFS, secteurId: { in: secteurIds }, idCommercial2: { not: null } },
            _count: { _all: true },
          })
        : [],
    ]);

    const clientsParSecteur = new Map<string, number>();
    for (const r of parSecteur) if (r.secteurId) clientsParSecteur.set(r.secteurId, r._count._all);

    // Un client compte pour le porteur de idCommercial1 et pour celui de idCommercial2.
    const clientsParCode = new Map<string, number>();
    for (const r of parCode1) clientsParCode.set(canonRepr(r.idCommercial1!), (clientsParCode.get(canonRepr(r.idCommercial1!)) ?? 0) + r._count._all);
    for (const r of parCode2) clientsParCode.set(canonRepr(r.idCommercial2!), (clientsParCode.get(canonRepr(r.idCommercial2!)) ?? 0) + r._count._all);

    // --- Activité du mois de chaque collaborateur du périmètre : visites, commandes, CA et objectif ------------------
    const debut = new Date(annee, mois - 1, 1);
    const fin = new Date(annee, mois, 1);
    const codes = new Set<string>();
    for (const u of users) if (u.idRepr) for (const v of idReprVariants(u.idRepr)) codes.add(v);
    const codesListe = [...codes];
    const [cmdRows, objRows, visRows] = await Promise.all([
      codesListe.length
        ? this.prisma.commande.groupBy({
            by: ['idRepr'],
            where: { dateAnnulation: null, dateCommande: { gte: debut, lt: fin }, idRepr: { in: codesListe } },
            _sum: { montantTotal: true },
            _count: { _all: true },
          })
        : [],
      codesListe.length
        ? this.prisma.objectif.findMany({
            where: {
              annee,
              client: {
                deletedAt: null,
                OR: [{ idCommercial1: { in: codesListe } }, { idCommercial2: { in: codesListe } }],
              },
            },
            select: { cibleCa: true, client: { select: { idCommercial1: true, idCommercial2: true } } },
          })
        : [],
      users.length
        ? this.prisma.visite.groupBy({
            by: ['promoteurId'],
            where: { deletedAt: null, createdAt: { gte: debut, lt: fin }, promoteurId: { in: users.map((u) => u.id) } },
            _count: { _all: true },
          })
        : [],
    ]);
    const caParCode = new Map<string, { ca: number; nb: number }>();
    for (const r of cmdRows) {
      const k = canonRepr(r.idRepr!);
      const cur = caParCode.get(k) ?? { ca: 0, nb: 0 };
      caParCode.set(k, { ca: cur.ca + Number(r._sum.montantTotal ?? 0), nb: cur.nb + r._count._all });
    }
    // Un magasin partagé compte pour chacun de ses deux commerciaux (comme dans le tableau de bord de direction).
    const objParCode = new Map<string, number>();
    for (const o of objRows) {
      const mensuel = Number(o.cibleCa) / 12;
      const cs = new Set(
        [o.client.idCommercial1, o.client.idCommercial2].filter((c): c is string => Boolean(c?.trim())).map(canonRepr),
      );
      for (const c of cs) objParCode.set(c, (objParCode.get(c) ?? 0) + mensuel);
    }
    const visParUser = new Map(visRows.map((r) => [r.promoteurId, r._count._all]));
    const activite = (u: { id: string; idRepr: string | null }): Activite => {
      const k = u.idRepr ? canonRepr(u.idRepr) : null;
      const c = k ? caParCode.get(k) : undefined;
      const obj = k && objParCode.has(k) ? Math.round(objParCode.get(k)!) : null;
      const ca = Math.round(c?.ca ?? 0);
      return { visites: visParUser.get(u.id) ?? 0, commandes: c?.nb ?? 0, ca, objectif: obj, tauxPct: obj ? Math.round((ca / obj) * 100) : null };
    };
    const sommeActivite = (l: Activite[]): Activite => {
      const objectif = l.some((a) => a.objectif != null) ? l.reduce((s, a) => s + (a.objectif ?? 0), 0) : null;
      const ca = l.reduce((s, a) => s + a.ca, 0);
      return {
        visites: l.reduce((s, a) => s + a.visites, 0),
        commandes: l.reduce((s, a) => s + a.commandes, 0),
        ca,
        objectif,
        tauxPct: objectif ? Math.round((ca / objectif) * 100) : null,
      };
    };

    const secteursParManager = new Map<string, SecteurVisible[]>();
    for (const s of secteurs) {
      if (!s.managerId) continue;
      secteursParManager.set(s.managerId, [...(secteursParManager.get(s.managerId) ?? []), s]);
    }

    // Chefs de secteur : région propre (AD), sinon celle de leur premier secteur.
    const chefs = users
      .filter((u) => u.role === Role.CHEF_SECTEUR)
      .map((u) => {
        const geres = secteursParManager.get(u.id) ?? [];
        return {
          user: u,
          geres,
          regionId: u.regionId ?? geres[0]?.regionId ?? u.secteur?.regionId ?? null,
          secteur: geres[0] ?? u.secteur ?? null,
          promoteurs: [] as (MembreEquipe & { nbClients: number })[],
        };
      });
    const chefParId = new Map(chefs.map((c) => [c.user.id, c]));

    // Promoteurs. Leur RÉGION est celle de leur propre compte AD (comme dans l'annuaire) ; à défaut, celle de leur chef
    // ou de leur secteur. Sous un chef de secteur ils ne sont listés que s'ils sont de la même région que lui : les
    // autres (chef d'une autre région, ou sans chef) vont dans « promoteurs hors chef de la région ».
    const promoteursRegion = new Map<string, number>(); // regionId -> nb de promoteurs
    const activitePromoteursRegion = new Map<string, Activite[]>(); // regionId -> activité de chaque promoteur
    const promoteursHorsChef = new Map<string, (MembreEquipe & { nbClients: number; chef: string | null })[]>();
    for (const u of users) {
      if (u.role !== Role.COMMERCIAL) continue;
      const chefId = (u.secteurId && managerDuSecteur(secteurs, u.secteurId)) || u.directeurId;
      const chef = chefId ? chefParId.get(chefId) : undefined;
      const regionId = u.regionId ?? chef?.regionId ?? u.secteur?.regionId ?? null;
      const act = activite(u);
      const membre = {
        id: u.id,
        displayName: u.displayName,
        poste: u.poste,
        nbClients: u.idRepr ? (clientsParCode.get(canonRepr(u.idRepr)) ?? 0) : 0,
        ...act,
      };
      if (regionId) {
        promoteursRegion.set(regionId, (promoteursRegion.get(regionId) ?? 0) + 1);
        activitePromoteursRegion.set(regionId, [...(activitePromoteursRegion.get(regionId) ?? []), act]);
      }
      if (chef && (regionId == null || chef.regionId === regionId)) chef.promoteurs.push(membre);
      else if (regionId) {
        promoteursHorsChef.set(regionId, [...(promoteursHorsChef.get(regionId) ?? []), { ...membre, chef: chef?.user.displayName ?? null }]);
      }
    }

    // Directeurs régionaux : comptés dans la région de leur compte AD, comme dans l'annuaire (leurs équipes restent
    // détaillées par chef de secteur).
    const directeursRegion = new Map<string, number>(); // regionId -> nb de directeurs régionaux
    for (const u of users) {
      if (u.role === Role.DIRECTEUR_REGIONAL && u.regionId) {
        directeursRegion.set(u.regionId, (directeursRegion.get(u.regionId) ?? 0) + 1);
      }
    }

    // Régions à renvoyer : toutes pour ADMIN/DIRECTION ; sinon celles du périmètre.
    const regionIds = new Set<string>();
    for (const s of secteurs) if (s.regionId) regionIds.add(s.regionId);
    if (me.role === Role.DIRECTEUR_REGIONAL && me.regionId) regionIds.add(me.regionId);
    for (const c of chefs) if (c.regionId) regionIds.add(c.regionId);
    const regionsDb = await this.prisma.region.findMany({
      where: this.estPrivilegie(me) ? {} : { id: { in: [...regionIds] } },
      orderBy: { nom: 'asc' },
      select: { id: true, code: true, nom: true },
    });

    const regions = regionsDb.map((r) => {
      const chefsRegion = chefs.filter((c) => c.regionId === r.id);
      const nbPromoteurs = promoteursRegion.get(r.id) ?? 0;
      const nbDirecteurs = directeursRegion.get(r.id) ?? 0;
      const directeurs = users
        .filter((u) => u.role === Role.DIRECTEUR_REGIONAL && u.regionId === r.id)
        .map((u) => ({ id: u.id, displayName: u.displayName, poste: u.poste, ...activite(u) }));
      const activiteChefs = chefsRegion.map((c) => activite(c.user));
      return {
        id: r.id,
        code: r.code,
        nom: r.nom,
        nbCollaborateurs: nbDirecteurs + chefsRegion.length + nbPromoteurs,
        nbDirecteurs,
        directeurs,
        promoteursHorsChef: promoteursHorsChef.get(r.id) ?? [],
        // Bilan du mois de la région : somme de l'activité de ses directeurs, chefs de secteur et promoteurs.
        stats: sommeActivite([...directeurs, ...activiteChefs, ...(activitePromoteursRegion.get(r.id) ?? [])]),
        nbChefsSecteur: chefsRegion.length,
        nbPromoteurs,
        nbClients: secteurs
          .filter((s) => s.regionId === r.id)
          .reduce((n, s) => n + (clientsParSecteur.get(s.id) ?? 0), 0),
        chefsSecteur: chefsRegion.map((c) => ({
          id: c.user.id,
          displayName: c.user.displayName,
          poste: c.user.poste,
          secteur: c.secteur ? { id: c.secteur.id, code: c.secteur.code, nom: c.secteur.nom } : null,
          nbClients: c.geres.reduce((n, s) => n + (clientsParSecteur.get(s.id) ?? 0), 0),
          ...activite(c.user),
          promoteurs: c.promoteurs,
        })),
      };
    });

    // La carte (formes des régions) est portée par le front : plus aucun calcul de départements ici.
    return { periode: { annee, mois }, regions };
  }

  // --- GET /dashboard/carte-secteur ----------------------------------------------------------------------------------

  async carteSecteur(me: Appelant, query: QueryCarteSecteurDto) {
    const visibles = await this.secteursVisibles(me);

    if (query.secteurId && !visibles.some((s) => s.id === query.secteurId)) {
      throw new NotFoundException('Secteur introuvable dans votre périmètre.');
    }
    if (query.regionId) {
      const connue =
        visibles.some((s) => s.regionId === query.regionId) ||
        (me.role === Role.DIRECTEUR_REGIONAL && me.regionId === query.regionId) ||
        (this.estPrivilegie(me) &&
          (await this.prisma.region.count({ where: { id: query.regionId } })) > 0);
      if (!connue) throw new NotFoundException('Région introuvable dans votre périmètre.');
    }

    const filtre = Boolean(query.secteurId || query.regionId);
    const retenus = visibles.filter(
      (s) => (!query.secteurId || s.id === query.secteurId) && (!query.regionId || s.regionId === query.regionId),
    );
    const secteurIds = retenus.map((s) => s.id);

    // ADMIN / DIRECTION sans filtre : tout le référentiel (y compris les points sans secteur).
    const toutVoir = this.estPrivilegie(me) && !filtre;
    const perimetre: { secteurId?: { in: string[] } } = toutVoir ? {} : { secteurId: { in: secteurIds } };
    if (!toutVoir && secteurIds.length === 0) return { clients: [], prospects: [], tronque: false, limite: CARTE_LIMITE_POINTS };

    const [clientsDb, prospectsDb] = await Promise.all([
      this.prisma.client.findMany({
        where: { ...CLIENTS_ACTIFS, ...perimetre, latitude: { not: null }, longitude: { not: null } },
        orderBy: { id: 'asc' },
        take: CARTE_LIMITE_POINTS + 1,
        select: {
          id: true,
          enseigne: true,
          raisonSociale: true,
          ville: true,
          codePostal: true,
          latitude: true,
          longitude: true,
          niveauClass: true,
          idCommercial1: true,
          idCommercial2: true,
        },
      }),
      this.prisma.prospect.findMany({
        where: { deletedAt: null, ...perimetre, latitude: { not: null }, longitude: { not: null } },
        orderBy: { id: 'asc' },
        take: CARTE_LIMITE_POINTS + 1,
        select: {
          id: true,
          enseigne: true,
          raisonSociale: true,
          ville: true,
          codePostal: true,
          latitude: true,
          longitude: true,
          statut: true,
          assignedTo: { select: { id: true, displayName: true } },
        },
      }),
    ]);

    const tronque = clientsDb.length > CARTE_LIMITE_POINTS || prospectsDb.length > CARTE_LIMITE_POINTS;
    const clientsRetenus = clientsDb.slice(0, CARTE_LIMITE_POINTS);
    const prospectsRetenus = prospectsDb.slice(0, CARTE_LIMITE_POINTS);

    // Promoteur d'un client : utilisateur COMMERCIAL dont idRepr = idCommercial1 (sinon idCommercial2), « 68 » = « 068 ».
    const codes = new Set<string>();
    for (const c of clientsRetenus) {
      for (const code of [c.idCommercial1, c.idCommercial2]) {
        const t = code?.trim();
        if (t) for (const v of idReprVariants(t)) codes.add(v);
      }
    }
    const promoteurs = codes.size
      ? await this.prisma.user.findMany({
          where: { role: Role.COMMERCIAL, isActive: true, idRepr: { in: [...codes] } },
          select: { id: true, displayName: true, idRepr: true },
        })
      : [];
    const promoteurParCode = new Map(promoteurs.map((u) => [canonRepr(u.idRepr!), { id: u.id, displayName: u.displayName }]));

    return {
      clients: clientsRetenus.map((c) => {
        const code1 = c.idCommercial1?.trim();
        const code2 = c.idCommercial2?.trim();
        return {
          id: c.id,
          nom: c.enseigne || c.raisonSociale,
          ville: c.ville,
          codePostal: c.codePostal,
          latitude: c.latitude as number,
          longitude: c.longitude as number,
          classe: c.niveauClass,
          promoteur:
            (code1 ? promoteurParCode.get(canonRepr(code1)) : undefined) ??
            (code2 ? promoteurParCode.get(canonRepr(code2)) : undefined) ??
            null,
        };
      }),
      prospects: prospectsRetenus.map((p) => ({
        id: p.id,
        nom: p.enseigne || p.raisonSociale,
        ville: p.ville,
        codePostal: p.codePostal,
        latitude: p.latitude as number,
        longitude: p.longitude as number,
        statut: p.statut,
        chefSecteur: p.assignedTo,
      })),
      tronque,
      limite: CARTE_LIMITE_POINTS,
    };
  }
}

/** Chef (managerId) du secteur donné parmi les secteurs visibles. */
function managerDuSecteur(secteurs: SecteurVisible[], secteurId: string): string | null {
  return secteurs.find((s) => s.id === secteurId)?.managerId ?? null;
}
