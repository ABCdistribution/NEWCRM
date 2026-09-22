import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { QueryArticlesDto } from './dto/query-articles.dto';

// Le filtre promo dépend de l'instant de la requête → select construit à l'appel.
function articleSelect(maintenant: Date) {
  return {
    id: true,
    codeAs400: true,
    libelle: true,
    gencode: true,
    typeArticle: true,
    statut: true,
    pcb: true,
    stock: true,
    actif: true,
    marque: { select: { nom: true } },
    gamme: { select: { nom: true } },
    famille: { select: { nom: true } },
    // Premier tarif actif = prix indicatif affiché à la prise de commande mobile.
    tarifs: {
      where: { deletedAt: null },
      orderBy: { codeTarif: 'asc' as const },
      take: 1,
      select: { montant: true },
    },
    // Promo en cours (bornes de dates facultatives).
    promos: {
      where: {
        actif: true,
        AND: [
          { OR: [{ dateDebut: null }, { dateDebut: { lte: maintenant } }] },
          { OR: [{ dateFin: null }, { dateFin: { gte: maintenant } }] },
        ],
      },
      take: 1,
      select: { libelle: true },
    },
    // Mise en avant merchandising.
    pem: { where: { actif: true }, take: 1, select: { id: true } },
    // Substitution en cas de rupture.
    switchsSource: { take: 1, select: { cibleId: true } },
  } satisfies Prisma.ArticleSelect;
}

type ArticleRow = Prisma.ArticleGetPayload<{ select: ReturnType<typeof articleSelect> }>;

function enrichi({ tarifs, promos, pem, switchsSource, ...article }: ArticleRow) {
  return {
    ...article,
    prixIndicatif: tarifs[0] ? Number(tarifs[0].montant) : null,
    enPromo: promos.length > 0,
    promoLibelle: promos[0]?.libelle ?? null,
    misEnAvant: pem.length > 0,
    substitutionId: switchsSource[0]?.cibleId ?? null,
  };
}

@Injectable()
export class ArticlesService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(query: QueryArticlesDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    const where: Prisma.ArticleWhereInput = {
      deletedAt: null,
      ...(query.actif !== undefined ? { actif: query.actif === 'true' } : {}),
      ...(query.rappel === 'true' ? { retourAutorise: true } : {}),
      ...(query.search
        ? {
            OR: [
              { codeAs400: { contains: query.search, mode: 'insensitive' } },
              { libelle: { contains: query.search, mode: 'insensitive' } },
              { gencode: { contains: query.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.article.findMany({
        where,
        select: articleSelect(new Date()),
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { libelle: 'asc' },
      }),
      this.prisma.article.count({ where }),
    ]);

    return { data: data.map(enrichi), total, page, limit };
  }

  async findOne(id: string) {
    const article = await this.prisma.article.findFirst({
      where: { id, deletedAt: null },
      select: articleSelect(new Date()),
    });
    if (!article) throw new NotFoundException(`Article ${id} introuvable`);
    return enrichi(article);
  }
}
