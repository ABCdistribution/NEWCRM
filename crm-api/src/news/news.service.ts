import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, Role } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { CreateNewsDto } from './dto/create-news.dto';
import { UpdateNewsDto } from './dto/update-news.dto';

const EXTRAIT_MAX = 200;

const newsInclude = {
  auteur: { select: { id: true, displayName: true } },
} as const;

type NewsAvecAuteur = Prisma.NewsGetPayload<{ include: typeof newsInclude }>;

/** Rôles autorisés à administrer les news et à voir les brouillons. */
export function peutAdministrerNews(role: string): boolean {
  return role === Role.ADMIN || role === Role.MARKETING;
}

/** Début du contenu, coupé proprement sur un mot et suffixé d'une ellipse. */
export function extraitDe(contenu: string): string {
  const texte = contenu.replace(/\s+/g, ' ').trim();
  if (texte.length <= EXTRAIT_MAX) return texte;
  const coupe = texte.slice(0, EXTRAIT_MAX);
  const dernierEspace = coupe.lastIndexOf(' ');
  return `${(dernierEspace > EXTRAIT_MAX / 2 ? coupe.slice(0, dernierEspace) : coupe).trimEnd()}…`;
}

function formater(n: NewsAvecAuteur) {
  return {
    id: n.id,
    titre: n.titre,
    extrait: extraitDe(n.contenu),
    contenu: n.contenu,
    imageUrl: n.imageUrl,
    publiee: n.publiee,
    publieeAt: n.publieeAt,
    createdAt: n.createdAt,
    updatedAt: n.updatedAt,
    // Auteur d'origine pour les news reprises de l'ancien système, sinon le créateur.
    auteur: { id: n.auteur.id, displayName: n.auteurNom ?? n.auteur.displayName },
  };
}

/**
 * News du siège. Globales (aucun périmètre secteur/région) : la seule restriction de lecture
 * est la visibilité des brouillons, réservée aux administrateurs (MARKETING, ADMIN).
 */
@Injectable()
export class NewsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Filtre de visibilité selon le rôle : non supprimées, et publiées sauf pour les administrateurs. */
  private visibles(role: string): Prisma.NewsWhereInput {
    return peutAdministrerNews(role) ? { deletedAt: null } : { deletedAt: null, publiee: true };
  }

  async list(role: string, page = 1, pageSize = 20) {
    const where = this.visibles(role);
    const [total, items] = await Promise.all([
      this.prisma.news.count({ where }),
      this.prisma.news.findMany({
        where,
        include: newsInclude,
        orderBy: [{ publieeAt: { sort: 'desc', nulls: 'last' } }, { createdAt: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    ]);
    return { items: items.map(formater), total, page, pageSize };
  }

  async get(id: string, role: string) {
    const n = await this.prisma.news.findFirst({
      where: { id, ...this.visibles(role) },
      include: newsInclude,
    });
    if (!n) throw new NotFoundException('News introuvable');
    return formater(n);
  }

  async create(dto: CreateNewsDto, auteurId: string) {
    const publiee = dto.publiee ?? false;
    const n = await this.prisma.news.create({
      data: {
        titre: dto.titre.trim(),
        contenu: dto.contenu.trim(),
        imageUrl: dto.imageUrl ?? null,
        publiee,
        publieeAt: publiee ? new Date() : null,
        auteurId,
      },
      include: newsInclude,
    });
    return formater(n);
  }

  async update(id: string, dto: UpdateNewsDto) {
    const actuelle = await this.prisma.news.findFirst({ where: { id, deletedAt: null } });
    if (!actuelle) throw new NotFoundException('News introuvable');

    const data: Prisma.NewsUpdateInput = {};
    if (dto.titre !== undefined) data.titre = dto.titre.trim();
    if (dto.contenu !== undefined) data.contenu = dto.contenu.trim();
    if (dto.imageUrl !== undefined) data.imageUrl = dto.imageUrl;
    if (dto.publiee !== undefined && dto.publiee !== actuelle.publiee) {
      data.publiee = dto.publiee;
      data.publieeAt = dto.publiee ? new Date() : null;
    }
    const n = await this.prisma.news.update({ where: { id }, data, include: newsInclude });
    return formater(n);
  }

  /** Suppression logique. */
  async remove(id: string) {
    const actuelle = await this.prisma.news.findFirst({ where: { id, deletedAt: null } });
    if (!actuelle) throw new NotFoundException('News introuvable');
    await this.prisma.news.update({ where: { id }, data: { deletedAt: new Date() } });
    return { ok: true };
  }
}
