import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface CreationVisite {
  idApk: string;
  clientId?: string | null; // exactement un de clientId / prospectId
  prospectId?: string | null;
  planningId?: string | null;
  motif?: string | null;
  dnAbc?: number | null;
  dnConcurrence?: number | null;
  dnGondoleHaute?: number | null;
  dnGondoleBasse?: number | null;
  commentaire?: string | null;
  reponses?: { questionId: string; valeur: string }[];
}

/**
 * Compte-rendu de visite remonté par l'app mobile (ou saisi plus tard sur le web).
 * Idempotent par `idApk` : l'outbox mobile peut rejouer sans créer de doublon.
 */
@Injectable()
export class VisitesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Visites paginées, les plus récentes d'abord. `promoteurId` null = vue
   * globale (rôles siège : ADV, direction, marketing, admin…) ; sinon la vue
   * est scopée sur ce promoteur (cas du commercial connecté).
   */
  async findAll(promoteurId: string | null, opts: { page?: number; search?: string } = {}) {
    const page = opts.page && opts.page > 0 ? opts.page : 1;
    const limit = 30;
    const where = {
      ...(promoteurId ? { promoteurId } : {}),
      deletedAt: null,
      ...(opts.search
        ? {
            client: {
              OR: [
                { enseigne: { contains: opts.search, mode: 'insensitive' as const } },
                { ville: { contains: opts.search, mode: 'insensitive' as const } },
                { codeAs400: { contains: opts.search, mode: 'insensitive' as const } },
              ],
            },
          }
        : {}),
    };

    const [rows, total] = await Promise.all([
      this.prisma.visite.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          createdAt: true,
          motif: true,
          dnAbc: true,
          dnConcurrence: true,
          dnGondoleHaute: true,
          dnGondoleBasse: true,
          pem: true,
          pmcCommentaire: true,
          client: { select: { id: true, codeAs400: true, enseigne: true, ville: true, niveauClass: true } },
          promoteur: { select: { id: true, displayName: true, idRepr: true } },
          _count: { select: { photos: true } },
        },
      }),
      this.prisma.visite.count({ where }),
    ]);

    return {
      data: rows,
      total,
      page,
      limit,
      scope: promoteurId ? ({ type: 'mine' } as const) : ({ type: 'global' } as const),
    };
  }

  async create(promoteur: { id: string }, dto: CreationVisite) {
    // Idempotence : la visite a peut-être déjà été synchronisée.
    const existante = await this.prisma.visite.findUnique({ where: { idApk: dto.idApk } });
    if (existante) {
      if (existante.promoteurId !== promoteur.id) {
        throw new ForbiddenException('Cet identifiant de visite appartient à un autre promoteur');
      }
      return { id: existante.id, idApk: dto.idApk, dejaSynchronisee: true };
    }

    // Visite magasin OU visite de prospection — exactement l'un des deux.
    if (Boolean(dto.clientId) === Boolean(dto.prospectId)) {
      throw new BadRequestException('Fournir exactement un des deux : clientId ou prospectId');
    }
    if (dto.clientId) {
      const client = await this.prisma.client.findFirst({
        where: { id: dto.clientId, deletedAt: null },
      });
      if (!client) throw new NotFoundException(`Magasin ${dto.clientId} introuvable`);
    } else {
      const prospect = await this.prisma.prospect.findFirst({
        where: { id: dto.prospectId!, deletedAt: null },
      });
      if (!prospect) throw new NotFoundException(`Prospect ${dto.prospectId} introuvable`);
    }

    // La visite peut solder une visite planifiée — uniquement celle du promoteur.
    let planningId: string | null = null;
    if (dto.planningId) {
      const planning = await this.prisma.planning.findFirst({
        where: { id: dto.planningId, promoteurId: promoteur.id, deletedAt: null },
      });
      if (!planning) {
        throw new NotFoundException(`Visite planifiée ${dto.planningId} introuvable pour ce promoteur`);
      }
      planningId = planning.id;
    }

    // Ne garde que les réponses pointant vers des questions existantes.
    const reponses = dto.reponses ?? [];
    const questionsValides = reponses.length
      ? new Set(
          (
            await this.prisma.questionVisite.findMany({
              where: { id: { in: reponses.map((r) => r.questionId) }, deletedAt: null },
              select: { id: true },
            })
          ).map((q) => q.id),
        )
      : new Set<string>();

    const visite = await this.prisma.$transaction(async (tx) => {
      const creee = await tx.visite.create({
        data: {
          promoteurId: promoteur.id,
          clientId: dto.clientId ?? null,
          prospectId: dto.prospectId ?? null,
          idApk: dto.idApk,
          motif: dto.motif?.trim() || null,
          dnAbc: dto.dnAbc ?? null,
          dnConcurrence: dto.dnConcurrence ?? null,
          dnGondoleHaute: dto.dnGondoleHaute ?? null,
          dnGondoleBasse: dto.dnGondoleBasse ?? null,
          pmcCommentaire: dto.commentaire?.trim() || null,
        },
      });
      if (questionsValides.size > 0) {
        await tx.visiteReponse.createMany({
          data: reponses
            .filter((r) => questionsValides.has(r.questionId))
            .map((r) => ({ visiteId: creee.id, questionId: r.questionId, valeur: r.valeur })),
          skipDuplicates: true,
        });
      }
      if (planningId) {
        await tx.planning.update({ where: { id: planningId }, data: { fait: true } });
      }
      if (dto.prospectId) {
        await tx.prospect.update({ where: { id: dto.prospectId }, data: { lastActivityAt: new Date() } });
      }
      return creee;
    });

    return { id: visite.id, idApk: dto.idApk, dejaSynchronisee: false };
  }

  // --- Photos de rayon (Helios Mobile) -----------------------------------

  /** Un promoteur ne voit que ses visites ; l'encadrement voit tout (comme GET /visites). */
  private async visiteAccessible(me: { id: string; role: string }, visiteId: string) {
    const visite = await this.prisma.visite.findFirst({
      where: { id: visiteId, deletedAt: null, ...(me.role === 'COMMERCIAL' ? { promoteurId: me.id } : {}) },
      select: { id: true, promoteurId: true },
    });
    if (!visite) throw new NotFoundException(`Visite ${visiteId} introuvable`);
    return visite;
  }

  async addPhoto(
    me: { id: string; role: string },
    visiteId: string,
    photo: { originalname: string; mimetype: string; size: number; buffer: Buffer },
    idApk?: string,
  ) {
    const visite = await this.visiteAccessible(me, visiteId);
    if (visite.promoteurId !== me.id && me.role !== 'ADMIN') {
      throw new ForbiddenException("Seul l'auteur de la visite peut y ajouter des photos");
    }
    if (!photo.mimetype?.startsWith('image/')) throw new BadRequestException('Le fichier doit être une image.');
    // Rejeu de l'outbox mobile : la photo existe déjà → on la renvoie.
    if (idApk) {
      const existante = await this.prisma.visitePhoto.findUnique({
        where: { idApk },
        select: { id: true, visiteId: true, createdAt: true },
      });
      if (existante) {
        if (existante.visiteId !== visiteId) throw new BadRequestException('idApk déjà utilisé pour une autre visite');
        return { id: existante.id, createdAt: existante.createdAt, dejaSynchronise: true };
      }
    }
    const cree = await this.prisma.visitePhoto.create({
      data: {
        visiteId,
        fichier: photo.originalname || 'photo.jpg',
        taille: photo.size,
        mime: photo.mimetype,
        donnees: Uint8Array.from(photo.buffer),
        idApk: idApk ?? null,
        appName: 'helios-mobile',
      },
      select: { id: true, createdAt: true },
    });
    return { ...cree, dejaSynchronise: false };
  }

  async listPhotos(me: { id: string; role: string }, visiteId: string) {
    await this.visiteAccessible(me, visiteId);
    return this.prisma.visitePhoto.findMany({
      where: { visiteId },
      orderBy: { createdAt: 'asc' },
      select: { id: true, fichier: true, taille: true, mime: true, createdAt: true },
    });
  }

  async getPhoto(me: { id: string; role: string }, visiteId: string, photoId: string) {
    await this.visiteAccessible(me, visiteId);
    const p = await this.prisma.visitePhoto.findFirst({
      where: { id: photoId, visiteId },
      select: { fichier: true, mime: true, donnees: true },
    });
    // Les anciennes photos (appli historique) ne sont pas stockées en base.
    if (!p?.donnees) throw new NotFoundException(`Photo ${photoId} introuvable`);
    return { nom: p.fichier, mime: p.mime ?? 'image/jpeg', donnees: p.donnees };
  }
}
