import { Injectable } from '@nestjs/common';
import { Role } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';

/** Nombre maximum d'éléments listés par type d'incohérence (le total, lui, est exact). */
const MAX_LISTE = 50;

type PersonneRef = { id: string; displayName: string };

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  /** Indicateurs calculés à la volée : rien n'est stocké, aucun état d'alerte. */
  async apercu() {
    const il7j = new Date(Date.now() - 7 * 24 * 3600 * 1000);

    let db: 'up' | 'down' = 'up';
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch {
      db = 'down';
    }

    const [
      parRole,
      inactifs,
      commerciauxSansSecteur,
      commerciauxSansCode,
      commerciauxSansDirecteur,
      secteurs,
      secteursSansChef,
      dernierImport,
      importsEnEchec7j,
    ] = await Promise.all([
      this.prisma.user.groupBy({ by: ['role'], where: { isActive: true }, _count: { _all: true } }),
      this.prisma.user.count({ where: { isActive: false } }),
      this.prisma.user.count({ where: { isActive: true, role: Role.COMMERCIAL, secteurId: null } }),
      this.prisma.user.count({ where: { isActive: true, role: Role.COMMERCIAL, idRepr: null } }),
      this.prisma.user.count({ where: { isActive: true, role: Role.COMMERCIAL, directeurId: null } }),
      this.prisma.secteur.count(),
      this.prisma.secteur.count({ where: { managerId: null } }),
      this.prisma.erpImportLog.findFirst({ orderBy: { createdAt: 'desc' } }),
      this.prisma.erpImportLog.count({ where: { status: 'FAILED', createdAt: { gte: il7j } } }),
    ]);

    const actifs = parRole.reduce((somme, r) => somme + r._count._all, 0);
    return {
      sante: { api: 'up' as const, db },
      utilisateurs: {
        actifs,
        inactifs,
        parRole: Object.fromEntries(parRole.map((r) => [r.role, r._count._all])),
      },
      organisation: {
        secteurs,
        secteursSansChef,
        commerciauxSansSecteur,
        commerciauxSansDirecteur,
        commerciauxSansCode,
      },
      imports: {
        dernier: dernierImport
          ? {
              id: dernierImport.id,
              fileName: dernierImport.fileName,
              source: dernierImport.source,
              status: dernierImport.status,
              rowsTotal: dernierImport.rowsTotal,
              rowsFailed: dernierImport.rowsFailed,
              date: (dernierImport.finishedAt ?? dernierImport.createdAt).toISOString(),
            }
          : null,
        enEchec7j: importsEnEchec7j,
      },
      // Télémétrie des appareils mobiles : pas encore remontée par l'application.
      mobile: null,
    };
  }

  /** Arbre de l'organisation commerciale + incohérences à corriger. */
  async organisation() {
    const [regions, secteursSansRegion, promoteurs] = await Promise.all([
      this.prisma.region.findMany({
        orderBy: { nom: 'asc' },
        include: {
          membres: {
            where: { role: Role.DIRECTEUR_REGIONAL },
            select: { id: true, displayName: true, isActive: true },
            orderBy: { displayName: 'asc' },
          },
          secteurs: {
            orderBy: { code: 'asc' },
            include: {
              manager: { select: { id: true, displayName: true, isActive: true } },
              membres: {
                where: { role: Role.COMMERCIAL },
                select: { id: true, displayName: true, isActive: true, idRepr: true },
                orderBy: { displayName: 'asc' },
              },
            },
          },
        },
      }),
      this.prisma.secteur.findMany({
        where: { regionId: null },
        select: { id: true, code: true, nom: true },
        orderBy: { code: 'asc' },
      }),
      this.prisma.user.findMany({
        where: { isActive: true, role: Role.COMMERCIAL },
        select: {
          id: true,
          displayName: true,
          secteurId: true,
          directeurId: true,
          directeur: { select: { isActive: true } },
        },
        orderBy: { displayName: 'asc' },
      }),
    ]);

    const liste = <T>(items: T[]) => ({ total: items.length, items: items.slice(0, MAX_LISTE) });
    const ref = (u: PersonneRef): PersonneRef => ({ id: u.id, displayName: u.displayName });
    const tousSecteurs = regions.flatMap((r) => r.secteurs);

    return {
      regions: regions.map((r) => ({
        id: r.id,
        code: r.code,
        nom: r.nom,
        directeurs: r.membres,
        secteurs: r.secteurs.map((s) => ({
          id: s.id,
          code: s.code,
          nom: s.nom,
          manager: s.manager,
          promoteurs: s.membres,
        })),
      })),
      secteursSansRegion,
      incoherences: {
        promoteursSansSecteur: liste(promoteurs.filter((u) => !u.secteurId).map(ref)),
        promoteursSansDirecteur: liste(promoteurs.filter((u) => !u.directeurId).map(ref)),
        promoteursDirecteurInactif: liste(promoteurs.filter((u) => u.directeur && !u.directeur.isActive).map(ref)),
        secteursSansChef: liste(
          tousSecteurs.filter((s) => !s.managerId).map((s) => ({ id: s.id, displayName: `${s.code} — ${s.nom}` })),
        ),
        chefsInactifs: liste(
          tousSecteurs
            .filter((s) => s.manager && !s.manager.isActive)
            .map((s) => ({ id: s.manager!.id, displayName: `${s.manager!.displayName} (${s.code})` })),
        ),
        regionsSansDirecteur: liste(
          regions
            .filter((r) => r.membres.filter((m) => m.isActive).length === 0)
            .map((r) => ({ id: r.id, displayName: r.nom })),
        ),
        secteursSansRegion: liste(secteursSansRegion.map((s) => ({ id: s.id, displayName: `${s.code} — ${s.nom}` }))),
      },
    };
  }
}
