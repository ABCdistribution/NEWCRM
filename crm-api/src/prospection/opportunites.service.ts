import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, User } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { ProspectsService } from './prospects.service';
import { CreateOpportuniteDto, QueryOpportunitesDto, UpdateOpportuniteDto } from './dto/opportunite.dto';

const opportuniteSelect = {
  id: true,
  type: true,
  statut: true,
  libelle: true,
  valeurEstimee: true,
  dateDebut: true,
  dateFin: true,
  createdAt: true,
  prospect: { select: { id: true, enseigne: true, ville: true, statut: true } },
  client: { select: { id: true, codeAs400: true, enseigne: true, ville: true } },
  assignedTo: { select: { id: true, displayName: true } },
  articles: { select: { id: true, codeAs400: true, libelle: true } },
} satisfies Prisma.OpportuniteSelect;

/**
 * Opportunités commerciales (référencement / OP / mise en avant), portées par un
 * prospect OU un client. Même scoping que les prospects : le périmètre d'un CS /
 * DR couvre les opportunités de ses prospects et de ses clients de secteur.
 */
@Injectable()
export class OpportunitesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly prospects: ProspectsService,
  ) {}

  /** Périmètre de visibilité (prospect scopé OU client du périmètre OU assignée à soi). */
  private scope(user: User): Prisma.OpportuniteWhereInput {
    if (user.role === 'CHEF_SECTEUR') {
      return {
        OR: [
          { prospect: this.prospects.scope(user).where },
          { client: { secteur: { managerId: user.id } } },
          { assignedToId: user.id },
        ],
      };
    }
    if (user.role === 'DIRECTEUR_REGIONAL') {
      return user.regionId
        ? {
            OR: [
              { prospect: { secteur: { regionId: user.regionId } } },
              { client: { secteur: { regionId: user.regionId } } },
              { assignedToId: user.id },
            ],
          }
        : { assignedToId: user.id };
    }
    return {};
  }

  async findAll(user: User, query: QueryOpportunitesDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    const where: Prisma.OpportuniteWhereInput = {
      deletedAt: null,
      ...this.scope(user),
      ...(query.type ? { type: query.type } : {}),
      ...(query.statut ? { statut: query.statut } : {}),
      ...(query.prospectId ? { prospectId: query.prospectId } : {}),
      ...(query.clientId ? { clientId: query.clientId } : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.opportunite.findMany({
        where,
        select: opportuniteSelect,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.opportunite.count({ where }),
    ]);

    return { data, total, page, limit };
  }

  async create(user: User, dto: CreateOpportuniteDto) {
    if (Boolean(dto.prospectId) === Boolean(dto.clientId)) {
      throw new BadRequestException('Fournir exactement un des deux : prospectId ou clientId');
    }
    if (dto.prospectId) {
      // Vérifie existence + périmètre (404 sinon) et marque l'activité.
      await this.prospects.findOne(user, dto.prospectId);
      await this.prisma.prospect.update({
        where: { id: dto.prospectId },
        data: { lastActivityAt: new Date() },
      });
    } else {
      const client = await this.prisma.client.findFirst({
        where: { id: dto.clientId!, deletedAt: null },
      });
      if (!client) throw new NotFoundException(`Client ${dto.clientId} introuvable`);
    }

    return this.prisma.opportunite.create({
      data: {
        type: dto.type,
        prospectId: dto.prospectId ?? null,
        clientId: dto.clientId ?? null,
        libelle: dto.libelle?.trim() || null,
        valeurEstimee: dto.valeurEstimee ?? null,
        dateDebut: dto.dateDebut ? new Date(dto.dateDebut) : null,
        dateFin: dto.dateFin ? new Date(dto.dateFin) : null,
        assignedToId: dto.assignedToId ?? user.id,
        ...(dto.articleIds?.length ? { articles: { connect: dto.articleIds.map((id) => ({ id })) } } : {}),
      },
      select: opportuniteSelect,
    });
  }

  async update(user: User, id: string, dto: UpdateOpportuniteDto) {
    const existante = await this.prisma.opportunite.findFirst({
      where: { id, deletedAt: null, ...this.scope(user) },
    });
    if (!existante) throw new NotFoundException(`Opportunité ${id} introuvable`);

    return this.prisma.opportunite.update({
      where: { id },
      data: {
        ...(dto.statut !== undefined ? { statut: dto.statut } : {}),
        ...(dto.libelle !== undefined ? { libelle: dto.libelle?.trim() || null } : {}),
        ...(dto.valeurEstimee !== undefined ? { valeurEstimee: dto.valeurEstimee } : {}),
        ...(dto.dateDebut !== undefined ? { dateDebut: dto.dateDebut ? new Date(dto.dateDebut) : null } : {}),
        ...(dto.dateFin !== undefined ? { dateFin: dto.dateFin ? new Date(dto.dateFin) : null } : {}),
        ...(dto.assignedToId !== undefined ? { assignedToId: dto.assignedToId } : {}),
        ...(dto.articleIds !== undefined
          ? { articles: { set: dto.articleIds.map((articleId) => ({ id: articleId })) } }
          : {}),
      },
      select: opportuniteSelect,
    });
  }
}
