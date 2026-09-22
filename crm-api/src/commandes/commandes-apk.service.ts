import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCommandeApkDto } from './dto/create-commande-apk.dto';

/**
 * Commande saisie sur l'app mobile, en attente d'intégration ERP.
 * Idempotente par `idCommandeApk` : l'outbox mobile peut rejouer sans doublon
 * (même mécanique que les visites, voir VisitesService).
 */
@Injectable()
export class CommandesApkService {
  constructor(private readonly prisma: PrismaService) {}

  async create(promoteur: { id: string }, dto: CreateCommandeApkDto) {
    const existante = await this.prisma.commandeApk.findUnique({
      where: { idCommandeApk: dto.idCommandeApk },
    });
    if (existante) {
      if (existante.promoteurId !== promoteur.id) {
        throw new ForbiddenException('Cet identifiant de commande appartient à un autre promoteur');
      }
      return { id: existante.id, idCommandeApk: dto.idCommandeApk, dejaSynchronisee: true };
    }

    const client = await this.prisma.client.findFirst({
      where: { id: dto.clientId, deletedAt: null },
    });
    if (!client) throw new NotFoundException(`Magasin ${dto.clientId} introuvable`);

    const articleIds = [...new Set(dto.lignes.map((l) => l.articleId))];
    const connus = await this.prisma.article.findMany({
      where: { id: { in: articleIds }, deletedAt: null },
      select: { id: true },
    });
    if (connus.length !== articleIds.length) {
      const trouves = new Set(connus.map((a) => a.id));
      const manquant = articleIds.find((id) => !trouves.has(id));
      throw new NotFoundException(`Article ${manquant} introuvable`);
    }

    const commande = await this.prisma.commandeApk.create({
      data: {
        idCommandeApk: dto.idCommandeApk,
        promoteurId: promoteur.id,
        clientId: dto.clientId,
        dateCommande: new Date(dto.dateCommande),
        commentaire: dto.commentaire?.trim() || null,
        lignes: {
          create: dto.lignes.map((l, i) => ({
            ordre: i + 1,
            articleId: l.articleId,
            quantite: l.quantite,
            prixIndicatif: l.prixIndicatif ?? null,
          })),
        },
      },
    });

    return { id: commande.id, idCommandeApk: dto.idCommandeApk, dejaSynchronisee: false };
  }

  /** Détail d'une commande mobile avec ses lignes (scopé : un commercial ne voit que les siennes). */
  async findOne(user: { id: string; role: string }, id: string) {
    const commande = await this.prisma.commandeApk.findFirst({
      where: { id, ...(user.role === 'COMMERCIAL' ? { promoteurId: user.id } : {}) },
      select: {
        id: true,
        idCommandeApk: true,
        dateCommande: true,
        commentaire: true,
        client: { select: { id: true, codeAs400: true, enseigne: true, ville: true } },
        promoteur: { select: { id: true, displayName: true } },
        lignes: {
          orderBy: { ordre: 'asc' },
          select: {
            ordre: true,
            quantite: true,
            prixIndicatif: true,
            article: { select: { id: true, codeAs400: true, libelle: true, gencode: true, pcb: true } },
          },
        },
      },
    });
    if (!commande) throw new NotFoundException(`Commande mobile ${id} introuvable`);

    const erp = await this.prisma.commande.findFirst({
      where: { idCommandeApk: commande.idCommandeApk },
      select: { id: true, numero: true },
    });

    return {
      ...commande,
      integree: erp !== null,
      numeroErp: erp?.numero ?? null,
      totalIndicatif: commande.lignes.reduce(
        (s, l) => s + l.quantite * Number(l.prixIndicatif ?? 0),
        0,
      ),
    };
  }

  /** Commandes mobiles du promoteur connecté (la direction voit tout). */
  async findAll(
    user: { id: string; role: string },
    query: { page?: number; limit?: number; clientId?: string },
  ) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const where = {
      ...(user.role === 'COMMERCIAL' ? { promoteurId: user.id } : {}),
      ...(query.clientId ? { clientId: query.clientId } : {}),
    };

    const [rows, total] = await Promise.all([
      this.prisma.commandeApk.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { dateCommande: 'desc' },
        select: {
          id: true,
          idCommandeApk: true,
          dateCommande: true,
          commentaire: true,
          client: { select: { id: true, codeAs400: true, enseigne: true, ville: true } },
          promoteur: { select: { id: true, displayName: true } },
          lignes: { select: { quantite: true, prixIndicatif: true } },
        },
      }),
      this.prisma.commandeApk.count({ where }),
    ]);

    // Une commande mobile est « intégrée » quand l'import Minos a ramené une
    // commande ERP portant son IDCRM — aucun statut à maintenir, on croise.
    const integrees = rows.length
      ? new Set(
          (
            await this.prisma.commande.findMany({
              where: { idCommandeApk: { in: rows.map((r) => r.idCommandeApk) } },
              select: { idCommandeApk: true },
            })
          ).map((c) => c.idCommandeApk),
        )
      : new Set<string | null>();

    return {
      data: rows.map(({ lignes, ...r }) => ({
        ...r,
        integree: integrees.has(r.idCommandeApk),
        nbLignes: lignes.length,
        totalIndicatif: lignes.reduce((s, l) => s + l.quantite * Number(l.prixIndicatif ?? 0), 0),
      })),
      total,
      page,
      limit,
    };
  }
}
