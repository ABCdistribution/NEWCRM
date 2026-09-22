import { Injectable } from '@nestjs/common';
import { Prisma } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { idReprVariants } from '../common/id-repr.util';

@Injectable()
export class PerformancesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Performances personnelles d'un commercial, sur un mois donné. */
  async forUser(
    user: { id: string; idRepr: string | null },
    annee: number,
    mois: number,
  ) {
    if (!user.idRepr) {
      // Pas de code représentant → rien à mesurer (compte non relié à l'ERP).
      return { noRepr: true as const };
    }

    const codes = idReprVariants(user.idRepr);
    const debut = new Date(annee, mois - 1, 1);
    const fin = new Date(annee, mois, 1);
    const debutN1 = new Date(annee - 1, mois - 1, 1);
    const finN1 = new Date(annee - 1, mois, 1);

    const whereMois: Prisma.CommandeWhereInput = {
      idRepr: { in: codes },
      dateAnnulation: null,
      dateCommande: { gte: debut, lt: fin },
    };

    const [caMois, caMoisN1, nbCommandes, commandants, portefeuille, sansCommande, courbe, objectif, classement, visitesMois] =
      await Promise.all([
        // CA du mois
        this.prisma.commandeLigne.aggregate({
          _sum: { montant: true },
          where: { commande: whereMois },
        }),
        // CA même mois N-1
        this.prisma.commandeLigne.aggregate({
          _sum: { montant: true },
          where: {
            commande: {
              idRepr: { in: codes },
              dateAnnulation: null,
              dateCommande: { gte: debutN1, lt: finN1 },
            },
          },
        }),
        this.prisma.commande.count({ where: whereMois }),
        // Clients distincts ayant commandé ce mois
        this.prisma.commande.groupBy({ by: ['clientId'], where: { ...whereMois, clientId: { not: null } } }),
        // Mon portefeuille
        this.prisma.client.count({
          where: {
            deletedAt: null,
            OR: [{ idCommercial1: { in: codes } }, { idCommercial2: { in: codes } }],
          },
        }),
        // Magasins du portefeuille SANS commande ce mois (5 premiers)
        this.prisma.client.findMany({
          where: {
            deletedAt: null,
            OR: [{ idCommercial1: { in: codes } }, { idCommercial2: { in: codes } }],
            commandes: { none: { dateAnnulation: null, dateCommande: { gte: debut, lt: fin } } },
          },
          select: { id: true, enseigne: true, raisonSociale: true, ville: true },
          orderBy: { enseigne: 'asc' },
          take: 5,
        }),
        // Courbe CA mensuelle N / N-1
        this.prisma.$queryRaw<{ annee: number; mois: number; ca: number }[]>`
          SELECT EXTRACT(YEAR FROM co."dateCommande")::int AS annee,
                 EXTRACT(MONTH FROM co."dateCommande")::int AS mois,
                 COALESCE(SUM(cl.montant), 0)::float8 AS ca
          FROM commandes co
          JOIN commande_lignes cl ON cl."commandeId" = co.id
          WHERE co."idRepr" IN (${Prisma.join(codes)})
            AND co."dateAnnulation" IS NULL
            AND co."dateCommande" IS NOT NULL
            AND EXTRACT(YEAR FROM co."dateCommande") IN (${annee}, ${annee - 1})
          GROUP BY 1, 2
          ORDER BY 1, 2
        `,
        // Objectif : somme des cibles ANNUELLES des magasins du portefeuille (mensuel = /12).
        this.prisma.objectif.aggregate({
          _sum: { cibleCa: true },
          where: {
            annee,
            client: {
              deletedAt: null,
              OR: [{ idCommercial1: { in: codes } }, { idCommercial2: { in: codes } }],
            },
          },
        }),
        // CA par représentant sur le mois (pour le rang)
        this.prisma.$queryRaw<{ idRepr: string; ca: number }[]>`
          SELECT co."idRepr", COALESCE(SUM(cl.montant), 0)::float8 AS ca
          FROM commandes co
          JOIN commande_lignes cl ON cl."commandeId" = co.id
          WHERE co."idRepr" IS NOT NULL
            AND co."dateAnnulation" IS NULL
            AND co."dateCommande" >= ${debut} AND co."dateCommande" < ${fin}
          GROUP BY 1
        `,
        this.prisma.visite.count({
          where: { promoteurId: user.id, deletedAt: null, createdAt: { gte: debut, lt: fin } },
        }),
      ]);

    const ca = Number(caMois._sum.montant ?? 0);
    const caN1 = Number(caMoisN1._sum.montant ?? 0);

    // Courbes 12 mois
    const courbeN = Array<number>(12).fill(0);
    const courbeN1 = Array<number>(12).fill(0);
    for (const r of courbe) {
      if (r.annee === annee) courbeN[r.mois - 1] = r.ca;
      else if (r.annee === annee - 1) courbeN1[r.mois - 1] = r.ca;
    }

    // Rang : les variantes d'un même code sont fusionnées
    const parRepr = new Map<string, number>();
    for (const r of classement) {
      const key = /^\d+$/.test(r.idRepr) ? String(Number(r.idRepr)) : r.idRepr;
      parRepr.set(key, (parRepr.get(key) ?? 0) + r.ca);
    }
    const maCle = String(Number(user.idRepr));
    const monCa = parRepr.get(maCle) ?? 0;
    const totalReprs = parRepr.size;
    const rang = parRepr.size
      ? 1 + [...parRepr.entries()].filter(([k, v]) => k !== maCle && v > monCa).length
      : null;

    // Top 5 de mes magasins par CA du mois
    const topMagasins = await this.prisma.$queryRaw<
      { id: string; enseigne: string; ca: number; nb: number }[]
    >`
      SELECT c.id, c.enseigne, COALESCE(SUM(cl.montant), 0)::float8 AS ca, COUNT(DISTINCT co.id)::int AS nb
      FROM commandes co
      JOIN commande_lignes cl ON cl."commandeId" = co.id
      JOIN clients c ON c.id = co."clientId"
      WHERE co."idRepr" IN (${Prisma.join(codes)})
        AND co."dateAnnulation" IS NULL
        AND co."dateCommande" >= ${debut} AND co."dateCommande" < ${fin}
      GROUP BY c.id, c.enseigne
      ORDER BY 3 DESC
      LIMIT 5
    `;

    const cibleAnnuelle = Number(objectif._sum.cibleCa ?? 0);
    const cible = cibleAnnuelle > 0 ? Math.round(cibleAnnuelle / 12) : null;

    return {
      noRepr: false as const,
      periode: { annee, mois },
      idRepr: user.idRepr,
      kpis: {
        ca,
        caN1,
        deltaPct: caN1 > 0 ? Math.round(((ca - caN1) / caN1) * 100) : null,
        commandes: nbCommandes,
        panierMoyen: nbCommandes > 0 ? ca / nbCommandes : 0,
        visites: visitesMois,
      },
      objectif: {
        cible,
        tauxPct: cible && cible > 0 ? Math.round((ca / cible) * 100) : null,
      },
      couverture: {
        portefeuille,
        commandants: commandants.length,
        sansCommande: portefeuille - commandants.length,
        exemplesSansCommande: sansCommande.map((c) => ({
          id: c.id,
          nom: (c.enseigne || c.raisonSociale).trim(),
          ville: c.ville?.trim() || null,
        })),
      },
      ca12mois: { anneeN: annee, courbeN, courbeN1 },
      topMagasins: topMagasins.map((m) => ({ ...m, enseigne: m.enseigne.trim() })),
      rang: { position: rang, total: totalReprs },
    };
  }
}
