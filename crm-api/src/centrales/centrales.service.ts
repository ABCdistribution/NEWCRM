import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Enseignes (centrales) pour l'administration. Les magasins sont rattachés à la centrale FEUILLE (`Client.centraleId`) :
 * `nbClients` compte donc les magasins actifs directement rattachés à chaque centrale (0 pour les niveaux parents).
 */
@Injectable()
export class CentralesService {
  constructor(private readonly prisma: PrismaService) {}

  async list() {
    const centrales = await this.prisma.centrale.findMany({
      select: {
        id: true,
        code: true,
        nom: true,
        parentId: true,
        _count: { select: { clients: { where: { deletedAt: null } } } },
      },
    });
    return centrales
      .map(({ _count, ...centrale }) => ({ ...centrale, nbClients: _count.clients }))
      .sort((a, b) => b.nbClients - a.nbClients || a.nom.localeCompare(b.nom, 'fr'));
  }
}
