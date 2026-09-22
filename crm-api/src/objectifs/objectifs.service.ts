import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ObjectifsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Grille de saisie annuelle : TOUS les magasins actifs (recherche + pagination),
   * avec l'objectif de l'année et le CA réalisé sur l'année.
   * L'objectif d'un promoteur n'est jamais saisi : il est calculé (somme du portefeuille).
   */
  async grille(annee: number, search?: string, page = 1, limit = 50) {
    const where: Prisma.ClientWhereInput = {
      deletedAt: null,
      actif: true,
      ...(search
        ? {
            OR: [
              { enseigne: { contains: search, mode: 'insensitive' } },
              { raisonSociale: { contains: search, mode: 'insensitive' } },
              { ville: { contains: search, mode: 'insensitive' } },
              { codeAs400: { contains: search } },
            ],
          }
        : {}),
    };

    const [magasins, total, objAgg] = await Promise.all([
      this.prisma.client.findMany({
        where,
        select: {
          id: true,
          codeAs400: true,
          enseigne: true,
          raisonSociale: true,
          ville: true,
          niveauClass: true,
          objectifs: { where: { annee }, select: { cibleCa: true } },
        },
        orderBy: { enseigne: 'asc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.client.count({ where }),
      // Totaux de l'année sur TOUT le périmètre filtré (pas seulement la page).
      this.prisma.objectif.aggregate({
        _count: true,
        _sum: { cibleCa: true },
        where: { annee, client: where },
      }),
    ]);

    // CA réalisé sur l'année, pour les magasins listés uniquement.
    const ids = magasins.map((m) => m.id);
    const debut = new Date(annee, 0, 1);
    const fin = new Date(annee + 1, 0, 1);
    const caRows = ids.length
      ? await this.prisma.$queryRaw<{ clientId: string; ca: number }[]>`
          SELECT co."clientId", COALESCE(SUM(cl.montant), 0)::float8 AS ca
          FROM commandes co
          JOIN commande_lignes cl ON cl."commandeId" = co.id
          WHERE co."clientId" IN (${Prisma.join(ids)})
            AND co."dateAnnulation" IS NULL
            AND co."dateCommande" >= ${debut} AND co."dateCommande" < ${fin}
          GROUP BY 1
        `
      : [];
    const caParClient = new Map(caRows.map((r) => [r.clientId, r.ca]));

    const lignes = magasins.map((m) => ({
      clientId: m.id,
      codeAs400: m.codeAs400,
      nom: (m.enseigne || m.raisonSociale).trim(),
      ville: m.ville?.trim() || null,
      niveauClass: m.niveauClass,
      cibleCa: m.objectifs[0] ? Number(m.objectifs[0].cibleCa) : null,
      caRealise: caParClient.get(m.id) ?? 0,
    }));

    return {
      annee,
      page,
      limit,
      total,
      totaux: {
        magasins: total,
        avecObjectif: objAgg._count,
        cibleCa: Number(objAgg._sum.cibleCa ?? 0),
      },
      lignes,
    };
  }

  /** Crée / modifie / supprime (cibleCa null) l'objectif annuel d'un magasin. */
  async upsert(clientId: string, annee: number, cibleCa: number | null, creeParId: string) {
    const client = await this.prisma.client.findFirst({ where: { id: clientId, deletedAt: null } });
    if (!client) throw new NotFoundException(`Magasin ${clientId} introuvable`);

    if (cibleCa === null) {
      await this.prisma.objectif.deleteMany({ where: { clientId, annee } });
      return { clientId, annee, cibleCa: null };
    }
    if (!(cibleCa >= 0)) throw new BadRequestException('Cible invalide');

    const saved = await this.prisma.objectif.upsert({
      where: { clientId_annee: { clientId, annee } },
      update: { cibleCa, creeParId },
      create: { clientId, annee, cibleCa, creeParId },
    });
    return { ...saved, cibleCa: Number(saved.cibleCa) };
  }
}
