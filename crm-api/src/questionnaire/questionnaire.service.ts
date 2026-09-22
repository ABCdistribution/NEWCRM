import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { TypeQuestion } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';

const select = {
  id: true,
  libelle: true,
  type: true,
  ordre: true,
  obligatoire: true,
  actif: true,
  _count: { select: { reponses: true } },
} as const;

/**
 * Questionnaire de fin de visite : structure administrée dans helios,
 * consommée telle quelle par l'app mobile (questions actives, ordonnées).
 */
@Injectable()
export class QuestionnaireService {
  constructor(private readonly prisma: PrismaService) {}

  /** Questions actives ordonnées (rendu mobile) ou toutes (édition helios). */
  list(tous = false) {
    return this.prisma.questionVisite.findMany({
      where: { deletedAt: null, ...(tous ? {} : { actif: true }) },
      select,
      orderBy: { ordre: 'asc' },
    });
  }

  async create(libelle: string, type: TypeQuestion, obligatoire: boolean, creeParId: string) {
    const dernier = await this.prisma.questionVisite.aggregate({
      _max: { ordre: true },
      where: { deletedAt: null },
    });
    return this.prisma.questionVisite.create({
      data: { libelle, type, obligatoire, ordre: (dernier._max.ordre ?? 0) + 1, creeParId },
      select,
    });
  }

  async update(
    id: string,
    data: { libelle?: string; type?: TypeQuestion; obligatoire?: boolean; actif?: boolean },
  ) {
    await this.findOne(id);
    return this.prisma.questionVisite.update({ where: { id }, data, select });
  }

  /** Échange l'ordre avec la question voisine (haut/bas). */
  async deplacer(id: string, direction: 'haut' | 'bas') {
    const question = await this.findOne(id);
    const voisine = await this.prisma.questionVisite.findFirst({
      where: {
        deletedAt: null,
        ordre: direction === 'haut' ? { lt: question.ordre } : { gt: question.ordre },
      },
      orderBy: { ordre: direction === 'haut' ? 'desc' : 'asc' },
    });
    if (!voisine) return this.list(true); // déjà en bout de liste

    await this.prisma.$transaction([
      this.prisma.questionVisite.update({ where: { id: question.id }, data: { ordre: voisine.ordre } }),
      this.prisma.questionVisite.update({ where: { id: voisine.id }, data: { ordre: question.ordre } }),
    ]);
    return this.list(true);
  }

  /** Suppression logique — les réponses déjà remontées restent rattachées. */
  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.questionVisite.update({ where: { id }, data: { deletedAt: new Date() } });
    return { id, deleted: true };
  }

  private async findOne(id: string) {
    const question = await this.prisma.questionVisite.findFirst({ where: { id, deletedAt: null } });
    if (!question) throw new NotFoundException(`Question ${id} introuvable`);
    return question;
  }
}
