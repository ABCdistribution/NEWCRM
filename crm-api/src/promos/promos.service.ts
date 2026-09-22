import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const articleSelect = {
  id: true,
  codeAs400: true,
  libelle: true,
  gencode: true,
  marque: { select: { nom: true } },
} as const;

/**
 * Promotions (offres sur un article) et mises en avant PEM.
 * Administrées dans helios (rôles ADMIN/DIRECTION/MARKETING), affichées en
 * lecture dans selios et consommées par l'app mobile (badges enPromo / misEnAvant
 * sur GET /articles).
 */
@Injectable()
export class PromosService {
  constructor(private readonly prisma: PrismaService) {}

  // --- Promos -----------------------------------------------------------

  /** Promos, actives d'abord ; `actives` = seulement celles en cours (dates + actif). */
  listPromos(actives = false) {
    const now = new Date();
    return this.prisma.promo.findMany({
      where: actives
        ? {
            actif: true,
            AND: [
              { OR: [{ dateDebut: null }, { dateDebut: { lte: now } }] },
              { OR: [{ dateFin: null }, { dateFin: { gte: now } }] },
            ],
          }
        : {},
      orderBy: [{ actif: 'desc' }, { createdAt: 'desc' }],
      select: {
        id: true,
        libelle: true,
        dateDebut: true,
        dateFin: true,
        actif: true,
        createdAt: true,
        article: { select: articleSelect },
      },
    });
  }

  async createPromo(dto: {
    articleId: string;
    libelle?: string;
    dateDebut?: string;
    dateFin?: string;
  }) {
    await this.ensureArticle(dto.articleId);
    return this.prisma.promo.create({
      data: {
        articleId: dto.articleId,
        libelle: dto.libelle?.trim() || null,
        dateDebut: dto.dateDebut ? new Date(dto.dateDebut) : null,
        dateFin: dto.dateFin ? new Date(dto.dateFin) : null,
      },
      select: {
        id: true,
        libelle: true,
        dateDebut: true,
        dateFin: true,
        actif: true,
        createdAt: true,
        article: { select: articleSelect },
      },
    });
  }

  async updatePromo(
    id: string,
    dto: { libelle?: string; dateDebut?: string | null; dateFin?: string | null; actif?: boolean },
  ) {
    await this.ensurePromo(id);
    return this.prisma.promo.update({
      where: { id },
      data: {
        ...(dto.libelle !== undefined ? { libelle: dto.libelle?.trim() || null } : {}),
        ...(dto.dateDebut !== undefined ? { dateDebut: dto.dateDebut ? new Date(dto.dateDebut) : null } : {}),
        ...(dto.dateFin !== undefined ? { dateFin: dto.dateFin ? new Date(dto.dateFin) : null } : {}),
        ...(dto.actif !== undefined ? { actif: dto.actif } : {}),
      },
      select: {
        id: true,
        libelle: true,
        dateDebut: true,
        dateFin: true,
        actif: true,
        createdAt: true,
        article: { select: articleSelect },
      },
    });
  }

  async removePromo(id: string) {
    await this.ensurePromo(id);
    await this.prisma.promo.delete({ where: { id } });
    return { id, deleted: true };
  }

  // --- Mises en avant PEM -----------------------------------------------

  listPem() {
    return this.prisma.pemArticle.findMany({
      orderBy: [{ actif: 'desc' }, { createdAt: 'desc' }],
      select: { id: true, actif: true, createdAt: true, article: { select: articleSelect } },
    });
  }

  /** Ajoute (ou réactive) une mise en avant pour un article. */
  async addPem(articleId: string) {
    await this.ensureArticle(articleId);
    const existante = await this.prisma.pemArticle.findFirst({ where: { articleId } });
    if (existante) {
      return this.prisma.pemArticle.update({
        where: { id: existante.id },
        data: { actif: true },
        select: { id: true, actif: true, createdAt: true, article: { select: articleSelect } },
      });
    }
    return this.prisma.pemArticle.create({
      data: { articleId },
      select: { id: true, actif: true, createdAt: true, article: { select: articleSelect } },
    });
  }

  async removePem(id: string) {
    const pem = await this.prisma.pemArticle.findUnique({ where: { id } });
    if (!pem) throw new NotFoundException(`Mise en avant ${id} introuvable`);
    await this.prisma.pemArticle.delete({ where: { id } });
    return { id, deleted: true };
  }

  // --- Helpers ----------------------------------------------------------

  private async ensureArticle(articleId: string) {
    const article = await this.prisma.article.findFirst({
      where: { id: articleId, deletedAt: null },
      select: { id: true },
    });
    if (!article) throw new NotFoundException(`Article ${articleId} introuvable`);
  }

  private async ensurePromo(id: string) {
    const promo = await this.prisma.promo.findUnique({ where: { id }, select: { id: true } });
    if (!promo) throw new NotFoundException(`Promo ${id} introuvable`);
  }
}
