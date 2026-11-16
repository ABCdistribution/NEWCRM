import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const select = {
  id: true,
  libelle: true,
  ordre: true,
  actif: true,
  _count: { select: { visites: true } },
} as const;

/**
 * Raisons d'absence de commande en fin de visite : liste fermée administrée dans ABC Pilot,
 * proposée telle quelle par l'app mobile (actives, ordonnées).
 */
@Injectable()
export class RaisonsAbsenceService {
  constructor(private readonly prisma: PrismaService) {}

  /** Raisons actives ordonnées (rendu mobile) ou toutes (édition). */
  list(tous = false) {
    return this.prisma.raisonAbsenceCommande.findMany({
      where: { deletedAt: null, ...(tous ? {} : { actif: true }) },
      select,
      orderBy: { ordre: 'asc' },
    });
  }

  async create(libelle: string) {
    const derniere = await this.prisma.raisonAbsenceCommande.aggregate({
      _max: { ordre: true },
      where: { deletedAt: null },
    });
    return this.prisma.raisonAbsenceCommande.create({
      data: { libelle, ordre: (derniere._max.ordre ?? 0) + 1 },
      select,
    });
  }

  async update(id: string, data: { libelle?: string; actif?: boolean }) {
    await this.findOne(id);
    return this.prisma.raisonAbsenceCommande.update({ where: { id }, data, select });
  }

  /** Échange l'ordre avec la raison voisine (haut/bas). */
  async deplacer(id: string, direction: 'haut' | 'bas') {
    const raison = await this.findOne(id);
    const voisine = await this.prisma.raisonAbsenceCommande.findFirst({
      where: {
        deletedAt: null,
        ordre: direction === 'haut' ? { lt: raison.ordre } : { gt: raison.ordre },
      },
      orderBy: { ordre: direction === 'haut' ? 'desc' : 'asc' },
    });
    if (!voisine) return this.list(true); // déjà en bout de liste

    await this.prisma.$transaction([
      this.prisma.raisonAbsenceCommande.update({ where: { id: raison.id }, data: { ordre: voisine.ordre } }),
      this.prisma.raisonAbsenceCommande.update({ where: { id: voisine.id }, data: { ordre: raison.ordre } }),
    ]);
    return this.list(true);
  }

  /** Suppression logique — les visites déjà remontées gardent leur raison. */
  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.raisonAbsenceCommande.update({ where: { id }, data: { deletedAt: new Date() } });
    return { id, deleted: true };
  }

  private async findOne(id: string) {
    const raison = await this.prisma.raisonAbsenceCommande.findFirst({ where: { id, deletedAt: null } });
    if (!raison) throw new NotFoundException(`Raison ${id} introuvable`);
    return raison;
  }
}
