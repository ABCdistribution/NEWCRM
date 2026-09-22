import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const DATE_FMT = new Intl.DateTimeFormat('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Relance le promoteur d'une visite planifiée non effectuée.
   * Aujourd'hui : notification in-app (selios) ; demain : la même API alimentera
   * l'app mobile (+ push Firebase quand elle existera).
   */
  async relancerVisite(planningId: string, emetteurId: string) {
    const planning = await this.prisma.planning.findFirst({
      where: { id: planningId, deletedAt: null },
      select: {
        id: true,
        fait: true,
        datePassage: true,
        promoteurId: true,
        client: { select: { enseigne: true, ville: true } },
      },
    });
    if (!planning) throw new NotFoundException('Visite planifiée introuvable');
    if (planning.fait) throw new ConflictException('Cette visite a déjà été effectuée');

    const lieu = [planning.client.enseigne.trim(), planning.client.ville?.trim()]
      .filter(Boolean)
      .join(' — ');
    const quand = DATE_FMT.format(new Date(planning.datePassage));

    return this.prisma.notification.create({
      data: {
        userId: planning.promoteurId,
        emetteurId,
        type: 'RELANCE_VISITE',
        titre: 'Relance visite',
        message: `${lieu} : la visite du ${quand} n'a pas été effectuée. Merci de la replanifier ou de la réaliser.`,
        lien: '/tournees',
      },
      select: { id: true, userId: true, titre: true, message: true, createdAt: true },
    });
  }

  /** Boîte de réception de l'utilisateur courant : 20 dernières + compteur non lues. */
  async boite(userId: string) {
    const [items, nonLues] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
        select: {
          id: true,
          type: true,
          titre: true,
          message: true,
          lien: true,
          luAt: true,
          createdAt: true,
          emetteur: { select: { displayName: true } },
        },
      }),
      this.prisma.notification.count({ where: { userId, luAt: null } }),
    ]);
    return { nonLues, items };
  }

  /** Marque toutes les notifications de l'utilisateur comme lues. */
  async toutMarquerLu(userId: string) {
    const res = await this.prisma.notification.updateMany({
      where: { userId, luAt: null },
      data: { luAt: new Date() },
    });
    return { marquees: res.count };
  }
}
