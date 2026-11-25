import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { perimetreEquipe } from '../common/perimetre-users.util';
import { filtreModifieDepuis, filtreSupprimes, selectHorodatage, TRI_MODIFIE_DEPUIS } from '../common/modifie-depuis';

/** Filtre des auteurs de visites visibles par `me` : null = pas de filtre (siège, direction, admin) ; CS / DR = équipe + soi ; COMMERCIAL = soi. */
export function auteursDeVisitesVisibles(me: { id: string; role: string; regionId?: string | null }): Prisma.UserWhereInput | null {
  if (me.role !== 'CHEF_SECTEUR' && me.role !== 'DIRECTEUR_REGIONAL') return me.role === 'COMMERCIAL' ? { id: me.id } : null;
  const equipe = perimetreEquipe(me);
  return { OR: [{ id: me.id }, ...(equipe ? [equipe] : [])] };
}

/** Étapes du parcours de visite de l'app mobile (clés de `VisiteStep.etape`). */
export const ETAPES_VISITE = ['debut', 'arrivee', 'rayonArrivee', 'colis', 'dn', 'indispensables', 'articlesPem', 'commande', 'questionnaire', 'op', 'rayonFin'] as const;
/** Étapes qui portent des photos (`VisitePhoto.etape`). */
export const ETAPES_PHOTO = ['arrivee', 'rayonArrivee', 'rayonFin'] as const;

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
  idCommandeApk?: string | null; // exclusif avec raisonAbsenceCommandeId
  raisonAbsenceCommandeId?: string | null;
  reponses?: { questionId: string; valeur: string }[];
  commandeEnRayon?: boolean | null; // nul = pas répondu
  colis?: string[]; // codes de colis (dédoublonnés ici)
  kits?: { code: string; references: number }[]; // kits constatés en rayon (DN)
  promosOp?: { promoId: string; presente: boolean }[]; // pointage OP
  indispensables?: { articleId: string; present: boolean }[]; // produits indispensables relevés présent / absent
  etapes?: { etape: string; horodatage: string }[]; // chrono des étapes faites
  typeVisite?: 'COMMERCIALE' | 'PEM'; // défaut COMMERCIALE (PEM si propositionPemId est fourni)
  propositionPemId?: string | null; // visite PEM : proposition réalisée par cette visite
  articlesPem?: { articleId: string; present: boolean; misEnAvant: boolean }[]; // visite PEM : relevé des articles PEM
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
  async findAll(
    promoteurId: string | null,
    opts: { page?: number; search?: string; equipe?: Prisma.UserWhereInput; modifieDepuis?: Date; dateDepuis?: Date } = {},
  ) {
    const page = opts.page && opts.page > 0 ? opts.page : 1;
    const limit = 30;
    // Synchro incrémentale : visites modifiées depuis l'instant donné, supprimées logiquement comprises (ET avec le
    // périmètre promoteur / équipe ci-dessous, qui reste appliqué).
    const depuis = opts.modifieDepuis;
    const where = {
      ...(promoteurId ? { promoteurId } : {}),
      // CS / DR : visites de leurs équipes (et les leurs) uniquement.
      ...(opts.equipe ? { promoteur: opts.equipe } : {}),
      ...filtreSupprimes(depuis),
      ...filtreModifieDepuis(depuis),
      // Fenêtre de dates (l'app mobile ne garde que les visites récentes).
      ...(opts.dateDepuis ? { createdAt: { gte: opts.dateDepuis } } : {}),
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
        orderBy: depuis ? TRI_MODIFIE_DEPUIS : { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          createdAt: true,
          ...selectHorodatage(depuis),
          motif: true,
          dnAbc: true,
          dnConcurrence: true,
          dnGondoleHaute: true,
          dnGondoleBasse: true,
          pem: true,
          pmcCommentaire: true,
          idCommandeApk: true,
          raisonAbsenceCommande: { select: { id: true, libelle: true } },
          client: { select: { id: true, codeAs400: true, enseigne: true, ville: true, niveauClass: true } },
          promoteur: { select: { id: true, displayName: true, idRepr: true } },
          // Parcours de visite (app mobile), en lecture légère.
          commandeEnRayon: true,
          colis: { select: { code: true }, orderBy: { createdAt: 'asc' } },
          kits: { select: { code: true, nbReferences: true }, orderBy: { createdAt: 'asc' } },
          steps: { select: { etape: true, horodatage: true }, orderBy: { horodatage: 'asc' } },
          // Pointage OP : les anciennes lignes sans promoId sont écartées ; libellé de la promo (ou de son article).
          promos: {
            where: { promoId: { not: null } },
            select: { promoId: true, presente: true, promo: { select: { libelle: true, article: { select: { libelle: true } } } } },
          },
          // Produits indispensables relevés (présent / absent).
          indispensables: {
            select: { articleId: true, present: true, article: { select: { libelle: true, codeAs400: true } } },
            orderBy: { createdAt: 'asc' },
          },
          // Visite PEM : proposition réalisée et relevé des articles PEM.
          typeVisite: true,
          propositionPem: { select: { id: true } },
          pemArticles: {
            select: { articleId: true, present: true, misEnAvant: true, article: { select: { libelle: true, codeAs400: true } } },
            orderBy: { createdAt: 'asc' },
          },
          // Métadonnées seulement : jamais le contenu binaire dans la liste.
          photos: { select: { id: true, etape: true }, orderBy: { createdAt: 'asc' } },
          _count: { select: { photos: true } },
        },
      }),
      this.prisma.visite.count({ where }),
    ]);

    const data = rows.map(({ colis, kits, promos, propositionPem, pemArticles, ...v }) => ({
      ...v,
      propositionPemId: propositionPem?.id ?? null,
      articlesPem: pemArticles,
      colis: colis.map((c) => c.code),
      kits: kits.map((k) => ({ code: k.code, references: k.nbReferences })),
      promosOp: promos.map((p) => ({
        promoId: p.promoId,
        presente: p.presente,
        libelle: p.promo?.libelle ?? p.promo?.article?.libelle ?? null,
      })),
    }));

    return {
      data,
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

    // Visite PEM : parcours distinct (photos, articles PEM, questionnaire), toujours sur un magasin.
    const typeVisite = dto.typeVisite ?? (dto.propositionPemId ? 'PEM' : 'COMMERCIALE');
    if (dto.propositionPemId && typeVisite !== 'PEM') {
      throw new BadRequestException("propositionPemId n'est accepté que pour une visite PEM");
    }
    if (typeVisite !== 'PEM' && dto.articlesPem?.length) {
      throw new BadRequestException("articlesPem n'est accepté que pour une visite PEM");
    }
    if (typeVisite === 'PEM' && !dto.clientId) {
      throw new BadRequestException('Une visite PEM porte sur un magasin : clientId est obligatoire');
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

    // La proposition réalisée doit être celle du promoteur, pour ce magasin, et encore ouverte.
    let propositionPem: { id: string; planningId: string | null } | null = null;
    if (dto.propositionPemId) {
      const proposition = await this.prisma.propositionPem.findUnique({
        where: { id: dto.propositionPemId },
        select: { id: true, clientId: true, promoteurId: true, statut: true, planningId: true },
      });
      if (!proposition) throw new NotFoundException(`Proposition PEM ${dto.propositionPemId} introuvable`);
      if (proposition.promoteurId !== promoteur.id) {
        throw new ForbiddenException("Cette visite PEM n'est pas attribuée à votre compte");
      }
      if (proposition.clientId !== dto.clientId) {
        throw new BadRequestException('La proposition PEM concerne un autre magasin que celui de la visite');
      }
      if (proposition.statut !== 'PROPOSEE' && proposition.statut !== 'ACCEPTEE') {
        throw new ConflictException("Cette visite PEM n'est plus ouverte");
      }
      propositionPem = { id: proposition.id, planningId: proposition.planningId };
    }

    // Fin de visite : soit une commande liée, soit une raison d'absence de commande — jamais les deux.
    if (dto.idCommandeApk && dto.raisonAbsenceCommandeId) {
      throw new BadRequestException('Fournir au plus un des deux : idCommandeApk ou raisonAbsenceCommandeId');
    }
    if (dto.raisonAbsenceCommandeId) {
      const raison = await this.prisma.raisonAbsenceCommande.findFirst({
        where: { id: dto.raisonAbsenceCommandeId, deletedAt: null },
        select: { id: true },
      });
      if (!raison) throw new NotFoundException(`Raison ${dto.raisonAbsenceCommandeId} introuvable`);
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

    // Parcours : colis, kits, chrono et pointage OP. Un code, une étape ou une promo n'est gardé qu'une fois.
    const colis = [...new Set((dto.colis ?? []).map((c) => c.trim()).filter(Boolean))];
    // Kits : table dédiée (code + nombre de références constatées) plutôt que VisiteDN, qui relève par type / marque / gamme / métrage.
    const kits = [...new Map((dto.kits ?? []).map((k) => [k.code.trim(), k.references] as const)).entries()];
    const etapes = [...new Map((dto.etapes ?? []).map((e) => [e.etape, new Date(e.horodatage)] as const)).entries()];
    if (etapes.some(([, d]) => Number.isNaN(d.getTime()))) throw new BadRequestException("Horodatage d'étape invalide");
    const promosOp = [...new Map((dto.promosOp ?? []).map((p) => [p.promoId, p.presente] as const)).entries()];
    if (promosOp.length) {
      const trouvees = new Set(
        (await this.prisma.promo.findMany({ where: { id: { in: promosOp.map(([id]) => id) } }, select: { id: true } })).map((p) => p.id),
      );
      const inconnues = promosOp.map(([id]) => id).filter((id) => !trouvees.has(id));
      if (inconnues.length) {
        throw new BadRequestException(`Promotion(s) introuvable(s) pour le pointage OP : ${inconnues.join(', ')}`);
      }
    }

    // Produits indispensables : un article n'est gardé qu'une fois (le dernier relevé gagne) et doit exister.
    const indispensables = [...new Map((dto.indispensables ?? []).map((i) => [i.articleId, i.present] as const)).entries()];
    if (indispensables.length) {
      const trouves = new Set(
        (
          await this.prisma.article.findMany({
            where: { id: { in: indispensables.map(([id]) => id) }, deletedAt: null },
            select: { id: true },
          })
        ).map((a) => a.id),
      );
      const inconnus = indispensables.map(([id]) => id).filter((id) => !trouves.has(id));
      if (inconnus.length) {
        throw new BadRequestException(`Article(s) introuvable(s) pour les produits indispensables : ${inconnus.join(', ')}`);
      }
    }

    // Articles PEM : un article n'est gardé qu'une fois (le dernier relevé gagne) et doit exister ; « mis en avant »
    // n'a de sens que pour un article présent.
    const articlesPem = [
      ...new Map((dto.articlesPem ?? []).map((a) => [a.articleId, { present: a.present, misEnAvant: a.present && a.misEnAvant }] as const)).entries(),
    ];
    if (articlesPem.length) {
      const trouves = new Set(
        (
          await this.prisma.article.findMany({
            where: { id: { in: articlesPem.map(([id]) => id) }, deletedAt: null },
            select: { id: true },
          })
        ).map((a) => a.id),
      );
      const inconnus = articlesPem.map(([id]) => id).filter((id) => !trouves.has(id));
      if (inconnus.length) {
        throw new BadRequestException(`Article(s) introuvable(s) pour la vérification PEM : ${inconnus.join(', ')}`);
      }
    }

    // Tout est créé dans une seule transaction : un rejeu (idApk déjà connu) ne duplique donc rien.
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
          idCommandeApk: dto.idCommandeApk ?? null,
          raisonAbsenceCommandeId: dto.raisonAbsenceCommandeId ?? null,
          commandeEnRayon: dto.commandeEnRayon ?? null,
          typeVisite,
        },
      });
      // Pas de colis si la réponse est « non » : comme dans l'app, qui efface les colis dans ce cas.
      if (colis.length && dto.commandeEnRayon !== false) {
        await tx.visiteColis.createMany({ data: colis.map((code) => ({ visiteId: creee.id, code })), skipDuplicates: true });
      }
      if (kits.length) {
        await tx.visiteKit.createMany({
          data: kits.map(([code, nbReferences]) => ({ visiteId: creee.id, code, nbReferences })),
          skipDuplicates: true,
        });
      }
      if (etapes.length) {
        await tx.visiteStep.createMany({ data: etapes.map(([etape, horodatage]) => ({ visiteId: creee.id, etape, horodatage })) });
      }
      if (promosOp.length) {
        await tx.visitePromo.createMany({
          data: promosOp.map(([promoId, presente]) => ({ visiteId: creee.id, promoId, presente })),
          skipDuplicates: true,
        });
      }
      if (indispensables.length) {
        await tx.visiteIndispensable.createMany({
          data: indispensables.map(([articleId, present]) => ({ visiteId: creee.id, articleId, present })),
          skipDuplicates: true,
        });
      }
      if (articlesPem.length) {
        await tx.visitePemArticle.createMany({
          data: articlesPem.map(([articleId, a]) => ({ visiteId: creee.id, articleId, present: a.present, misEnAvant: a.misEnAvant })),
          skipDuplicates: true,
        });
      }
      if (propositionPem) {
        // La proposition passe à REALISEE et son compteur de reports repart de zéro pour le cycle suivant. La garde sur
        // le statut évite qu'une autre visite réalise la même proposition en parallèle.
        const maj = await tx.propositionPem.updateMany({
          where: { id: propositionPem.id, statut: { in: ['PROPOSEE', 'ACCEPTEE'] } },
          data: { statut: 'REALISEE', visiteId: creee.id, nbReports: 0 },
        });
        if (maj.count === 0) throw new ConflictException("Cette visite PEM n'est plus ouverte");
        if (propositionPem.planningId) {
          await tx.planning.updateMany({ where: { id: propositionPem.planningId, deletedAt: null }, data: { fait: true } });
        }
      }
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
    }).catch(async (e: unknown) => {
      // Deux envois simultanés du même idApk : la contrainte unique rejette le second, qui renvoie la visite déjà créée.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const concurrente = await this.prisma.visite.findUnique({ where: { idApk: dto.idApk } });
        if (concurrente?.promoteurId === promoteur.id) return { ...concurrente, dejaSynchronisee: true as const };
      }
      throw e;
    });

    return { id: visite.id, idApk: dto.idApk, dejaSynchronisee: 'dejaSynchronisee' in visite };
  }

  // --- Photos de rayon (ABC Pilot Mobile) -----------------------------------

  /** Un promoteur ne voit que ses visites ; l'encadrement voit tout (comme GET /visites). */
  private async visiteAccessible(me: { id: string; role: string; regionId?: string | null }, visiteId: string) {
    const auteurs = auteursDeVisitesVisibles(me);
    const visite = await this.prisma.visite.findFirst({
      where: { id: visiteId, deletedAt: null, ...(auteurs ? { promoteur: auteurs } : {}) },
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
    etape?: string, // étape du parcours (arrivee, rayonArrivee, rayonFin), déjà validée par le DTO
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
    // Une seule photo par étape du parcours : la nouvelle remplace celle de la même étape (reprise de la photo), dans la
    // même transaction pour ne jamais laisser l'étape sans photo. Les photos sans étape (anciennes) ne sont pas touchées.
    const cree = await this.prisma.$transaction(async (tx) => {
      const nouvelle = await tx.visitePhoto.create({
        data: {
          visiteId,
          fichier: photo.originalname || 'photo.jpg',
          taille: photo.size,
          mime: photo.mimetype,
          donnees: Uint8Array.from(photo.buffer),
          idApk: idApk ?? null,
          etape: etape ?? null,
          appName: 'helios-mobile',
        },
        select: { id: true, createdAt: true },
      });
      if (etape) {
        await tx.visitePhoto.deleteMany({ where: { visiteId, etape, id: { not: nouvelle.id } } });
      }
      return nouvelle;
    });
    return { ...cree, dejaSynchronise: false };
  }

  async listPhotos(me: { id: string; role: string }, visiteId: string) {
    await this.visiteAccessible(me, visiteId);
    return this.prisma.visitePhoto.findMany({
      where: { visiteId },
      orderBy: { createdAt: 'asc' },
      select: { id: true, fichier: true, taille: true, mime: true, etape: true, createdAt: true },
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
