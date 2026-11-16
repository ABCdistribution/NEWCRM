import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { QueryArticlesDto } from './dto/query-articles.dto';
import {
  filtreModifieDepuis,
  filtreSupprimes,
  lireModifieDepuis,
  selectHorodatage,
  TRI_MODIFIE_DEPUIS,
} from '../common/modifie-depuis';

// Promotion en cours : active, bornes de dates facultatives.
function promoEnCours(maintenant: Date): Prisma.PromoWhereInput {
  return {
    actif: true,
    AND: [
      { OR: [{ dateDebut: null }, { dateDebut: { lte: maintenant } }] },
      { OR: [{ dateFin: null }, { dateFin: { gte: maintenant } }] },
    ],
  };
}

// Le filtre promo dépend de l'instant de la requête → select construit à l'appel.
function articleSelect(maintenant: Date, depuis?: Date) {
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
    // Synchro incrémentale uniquement (modifieDepuis).
    ...selectHorodatage(depuis),
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
      where: promoEnCours(maintenant),
      take: 1,
      select: { libelle: true },
    },
    // Mise en avant merchandising.
    pem: { where: { actif: true }, take: 1, select: { id: true } },
    // Substitution en cas de rupture : première règle par ordre de création (même ordre que le détail).
    switchsSource: {
      orderBy: [{ createdAt: 'asc' as const }, { id: 'asc' as const }],
      take: 1,
      select: { cibleId: true },
    },
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

// Select de la fiche détaillée (GET /articles/:id) : distinct de celui de la liste, qui reste léger.
function articleDetailSelect(maintenant: Date) {
  return {
    id: true,
    codeAs400: true,
    libelle: true,
    gencode: true,
    idIta: true,
    typeArticle: true,
    statut: true,
    sousStatut: true,
    retourAutorise: true,
    actif: true,
    codeTva: true,
    pcb: true,
    stock: true,
    famillePlan: true,
    familleAcd: true,
    sousFamilleAcd: true,
    sousFamille: true,
    details: true,
    avantages: true,
    marque: { select: { nom: true } },
    gamme: { select: { nom: true } },
    famille: { select: { nom: true } },
    // Tous les tarifs non supprimés ; le premier (codeTarif croissant) donne le prix indicatif.
    tarifs: {
      where: { deletedAt: null },
      orderBy: [{ codeTarif: 'asc' as const }, { id: 'asc' as const }],
      select: { codeTarif: true, montant: true },
    },
    // Promotions en cours (même définition que la liste), sans limite.
    promos: {
      where: promoEnCours(maintenant),
      orderBy: [{ dateDebut: 'asc' as const }, { id: 'asc' as const }],
      select: { libelle: true, dateDebut: true, dateFin: true },
    },
    pem: { where: { actif: true }, take: 1, select: { id: true } },
    // Règles de remplacement en cas de rupture : l'ordre de création sert à fixer `substitutionId`.
    switchsSource: {
      orderBy: [{ createdAt: 'asc' as const }, { id: 'asc' as const }],
      select: {
        cibleId: true,
        seuil: true,
        cible: {
          select: {
            id: true,
            codeAs400: true,
            libelle: true,
            gencode: true,
            stock: true,
            actif: true,
            deletedAt: true,
            marque: { select: { nom: true } },
          },
        },
      },
    },
  } satisfies Prisma.ArticleSelect;
}

type ArticleDetailRow = Prisma.ArticleGetPayload<{ select: ReturnType<typeof articleDetailSelect> }>;

function detaille({ tarifs, promos, pem, switchsSource, ...article }: ArticleDetailRow) {
  const remplacements = switchsSource
    // Écartés : remplaçants supprimés, règle dont la cible est l'article lui-même, doublons de cible (la plus
    // ancienne règle l'emporte, `switchsSource` étant trié par date de création).
    .filter(
      (s, i, toutes) =>
        s.cible.deletedAt === null && s.cibleId !== article.id && toutes.findIndex((t) => t.cibleId === s.cibleId) === i,
    )
    .map(({ seuil, cible: { deletedAt: _deletedAt, ...cible } }) => ({ seuil: seuil ?? null, article: cible }))
    // Tri stable par libellé du remplaçant (code AS400 en cas d'égalité).
    .sort(
      (a, b) =>
        a.article.libelle.localeCompare(b.article.libelle, 'fr', { sensitivity: 'base' }) ||
        a.article.codeAs400.localeCompare(b.article.codeAs400),
    );
  const tarifsNum = tarifs.map((t) => ({ codeTarif: t.codeTarif ?? null, montant: Number(t.montant) }));
  return {
    ...article,
    tarifs: tarifsNum,
    prixIndicatif: tarifsNum[0]?.montant ?? null,
    enPromo: promos.length > 0,
    promoLibelle: promos[0]?.libelle ?? null,
    misEnAvant: pem.length > 0,
    // Identique à la liste (même tri : création puis id) : cible de la première règle, brute, même si le remplaçant est
    // supprimé. `remplacements`, filtré et trié par libellé, ne commence donc pas forcément par cette cible.
    substitutionId: switchsSource[0]?.cibleId ?? null,
    promos: promos.map((p) => ({
      libelle: p.libelle ?? null,
      dateDebut: p.dateDebut ? p.dateDebut.toISOString() : null,
      dateFin: p.dateFin ? p.dateFin.toISOString() : null,
    })),
    remplacements,
  };
}

@Injectable()
export class ArticlesService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(query: QueryArticlesDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    const maintenant = new Date();
    // Synchro incrémentale : articles modifiés depuis l'instant donné, supprimés logiquement compris (ET avec les autres filtres).
    const depuis = lireModifieDepuis(query.modifieDepuis);
    // Conditions combinées en ET (la recherche a son propre OU, comme le filtre promo / PEM).
    const conditions: Prisma.ArticleWhereInput[] = [];
    if (query.search) {
      conditions.push({
        OR: [
          { codeAs400: { contains: query.search, mode: 'insensitive' } },
          { libelle: { contains: query.search, mode: 'insensitive' } },
          { gencode: { contains: query.search, mode: 'insensitive' } },
          { marque: { is: { nom: { contains: query.search, mode: 'insensitive' } } } },
        ],
      });
    }
    // Promos / PEM : promotion en cours (même définition que `articleSelect`) ou mise en avant active.
    if (query.promo === 'true') {
      conditions.push({
        OR: [
          { promos: { some: promoEnCours(maintenant) } },
          { pem: { some: { actif: true } } },
        ],
      });
    }
    const where: Prisma.ArticleWhereInput = {
      ...filtreSupprimes(depuis),
      ...filtreModifieDepuis(depuis),
      ...(query.actif !== undefined ? { actif: query.actif === 'true' } : {}),
      ...(query.rappel === 'true' ? { retourAutorise: true } : {}),
      ...(query.marqueId ? { marqueId: query.marqueId } : {}),
      ...(conditions.length > 0 ? { AND: conditions } : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.article.findMany({
        where,
        select: articleSelect(maintenant, depuis),
        skip: (page - 1) * limit,
        take: limit,
        orderBy: depuis ? TRI_MODIFIE_DEPUIS : { libelle: 'asc' },
      }),
      this.prisma.article.count({ where }),
    ]);

    return { data: data.map(enrichi), total, page, limit };
  }

  /** Marques ayant au moins un article au catalogue, par ordre alphabétique (sélecteur de la page Produits). */
  async marques() {
    const lignes = await this.prisma.marque.findMany({
      select: { id: true, nom: true, _count: { select: { articles: { where: { deletedAt: null } } } } },
      orderBy: { nom: 'asc' },
    });
    return lignes.filter((m) => m._count.articles > 0).map((m) => ({ id: m.id, nom: m.nom, nbArticles: m._count.articles }));
  }

  async findOne(id: string) {
    const article = await this.prisma.article.findFirst({
      where: { id, deletedAt: null },
      select: articleDetailSelect(new Date()),
    });
    if (!article) throw new NotFoundException(`Article ${id} introuvable`);
    return detaille(article);
  }
}
