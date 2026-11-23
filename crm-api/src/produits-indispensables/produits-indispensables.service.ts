import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { filtreClientsDuPerimetre } from '../common/perimetre-clients.util';

const select = {
  id: true,
  centraleId: true,
  articleId: true,
  ordre: true,
  article: {
    select: { id: true, codeAs400: true, libelle: true, gencode: true, marque: { select: { id: true, nom: true } } },
  },
} as const;

const selectAvecCentrale = { ...select, centrale: { select: { id: true, nom: true } } } as const;

/**
 * Produits indispensables par enseigne (= centrale) : liste administrée dans /admin, relevée « présent / absent »
 * par le promoteur pendant la visite. Suppression logique (`deletedAt`), unique par (centrale, article).
 */
@Injectable()
export class ProduitsIndispensablesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Triés par ordre puis libellé. Sans centrale : toutes les enseignes, avec le nom de la centrale. */
  async list(centraleId?: string) {
    const lignes = await this.prisma.produitIndispensable.findMany({
      where: { deletedAt: null, article: { deletedAt: null }, ...(centraleId ? { centraleId } : {}) },
      select: centraleId ? select : selectAvecCentrale,
    });
    return this.trier(lignes);
  }

  /**
   * Liste de la centrale du magasin ; vide si le magasin n'a pas de centrale ou si elle n'a pas de liste. Le magasin
   * doit être dans le périmètre de l'appelant (même règle que « Mes clients ») : sinon 404.
   */
  async listPourClient(clientId: string, user: { id: string; role: string; idRepr: string | null; regionId?: string | null }) {
    const client = await this.prisma.client.findFirst({
      where: { id: clientId, deletedAt: null, ...(await filtreClientsDuPerimetre(this.prisma, user)) },
      select: { centraleId: true },
    });
    if (!client) throw new NotFoundException(`Client ${clientId} introuvable`);
    if (!client.centraleId) return [];
    return this.list(client.centraleId);
  }

  /** Idempotent : renvoie la ligne si elle existe, la restaure si elle était supprimée, la crée sinon. */
  async create(centraleId: string, articleId: string, ordre?: number) {
    const [centrale, article] = await Promise.all([
      this.prisma.centrale.findUnique({ where: { id: centraleId }, select: { id: true } }),
      this.prisma.article.findFirst({ where: { id: articleId, deletedAt: null }, select: { id: true } }),
    ]);
    if (!centrale) throw new NotFoundException(`Enseigne (centrale) ${centraleId} introuvable`);
    if (!article) throw new NotFoundException(`Article ${articleId} introuvable`);

    const cle = { centraleId_articleId: { centraleId, articleId } };
    try {
      const existante = await this.prisma.produitIndispensable.findUnique({ where: cle, select: { id: true, deletedAt: true } });
      if (!existante) {
        return await this.prisma.produitIndispensable.create({ data: { centraleId, articleId, ordre: ordre ?? 0 }, select });
      }
      if (existante.deletedAt || ordre !== undefined) {
        return await this.prisma.produitIndispensable.update({
          where: { id: existante.id },
          data: { deletedAt: null, ...(ordre !== undefined ? { ordre } : {}) },
          select,
        });
      }
      return await this.prisma.produitIndispensable.findUniqueOrThrow({ where: { id: existante.id }, select });
    } catch (e) {
      // Deux créations simultanées de la même paire : la seconde renvoie la ligne déjà créée.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        return this.prisma.produitIndispensable.findUniqueOrThrow({ where: cle, select });
      }
      throw e;
    }
  }

  async update(id: string, ordre: number) {
    await this.findOne(id);
    return this.prisma.produitIndispensable.update({ where: { id }, data: { ordre }, select });
  }

  /** Suppression logique — les relevés de visite déjà remontés sont conservés. */
  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.produitIndispensable.update({ where: { id }, data: { deletedAt: new Date() } });
    return { id, deleted: true };
  }

  private async findOne(id: string) {
    const ligne = await this.prisma.produitIndispensable.findFirst({ where: { id, deletedAt: null }, select: { id: true } });
    if (!ligne) throw new NotFoundException(`Produit indispensable ${id} introuvable`);
    return ligne;
  }

  private trier<T extends { ordre: number; article: { libelle: string } }>(lignes: T[]): T[] {
    return lignes.sort((a, b) => a.ordre - b.ordre || a.article.libelle.localeCompare(b.article.libelle, 'fr'));
  }
}
