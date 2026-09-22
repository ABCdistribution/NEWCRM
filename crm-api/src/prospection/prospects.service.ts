import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PipelineEtape, Prisma, User } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import {
  CreateAppelDto,
  CreateEmailDto,
  CreateProspectApkDto,
  CreateProspectDto,
  QueryProspectsDto,
  UpdateProspectDto,
} from './dto/prospect.dto';

/** Probabilité (%) par défaut de chaque étape du pipeline — à valider métier. */
export const PROBABILITE_PAR_ETAPE: Record<PipelineEtape, number> = {
  NOUVEAU: 10, // création de la fiche
  CONTACTE: 25, // prise de contact
  PROPOSITION: 50,
  VISITE: 65,
  NEGOCIATION: 80,
  GAGNE: 100,
  PERDU: 0,
};

/** Ordre d'affichage des colonnes du Kanban (suivi du prospect de la fiche au gagné/perdu). */
const ETAPES_ORDONNEES: PipelineEtape[] = [
  'NOUVEAU',
  'CONTACTE',
  'PROPOSITION',
  'VISITE',
  'NEGOCIATION',
  'GAGNE',
  'PERDU',
];

const prospectListSelect = {
  id: true,
  raisonSociale: true,
  enseigne: true,
  ville: true,
  codePostal: true,
  statut: true,
  probabilite: true,
  potentielCaAnnuel: true,
  source: true,
  motifPerte: true,
  niveauClass: true,
  latitude: true,
  longitude: true,
  clientId: true,
  lastActivityAt: true,
  createdAt: true,
  secteur: { select: { id: true, code: true, nom: true } },
  assignedTo: { select: { id: true, displayName: true } },
} satisfies Prisma.ProspectSelect;

/**
 * Prospection & pipeline (module Helios) : prospects scopés par rôle —
 * chef de secteur : ses secteurs (ou prospects qui lui sont assignés / qu'il a créés) ;
 * directeur régional : sa région ; Direction / ADMIN : tout.
 */
@Injectable()
export class ProspectsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Périmètre de visibilité du rôle sur les prospects. */
  scope(user: User): { where: Prisma.ProspectWhereInput; type: 'secteur' | 'region' | 'global' } {
    if (user.role === 'CHEF_SECTEUR') {
      return {
        type: 'secteur',
        where: {
          OR: [
            { secteur: { managerId: user.id } },
            { assignedToId: user.id },
            { createdById: user.id },
          ],
        },
      };
    }
    if (user.role === 'DIRECTEUR_REGIONAL') {
      // Sa région + ses propres fiches : un prospect créé à la main n'a pas de
      // secteur, il doit rester visible par son créateur (sinon 404 post-création).
      return user.regionId
        ? {
            type: 'region',
            where: {
              OR: [
                { secteur: { regionId: user.regionId } },
                { assignedToId: user.id },
                { createdById: user.id },
              ],
            },
          }
        : { type: 'region', where: { OR: [{ assignedToId: user.id }, { createdById: user.id }] } };
    }
    return { type: 'global', where: {} };
  }

  async findAll(user: User, query: QueryProspectsDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const scope = this.scope(user);

    const where: Prisma.ProspectWhereInput = {
      deletedAt: null,
      ...scope.where,
      ...(query.statut ? { statut: query.statut } : {}),
      ...(query.secteur ? { secteurId: query.secteur } : {}),
      ...(query.assignedTo ? { assignedToId: query.assignedTo } : {}),
      ...(query.search
        ? {
            // AND explicite pour ne pas écraser le OR du scoping.
            AND: [
              {
                OR: [
                  { enseigne: { contains: query.search, mode: 'insensitive' } },
                  { raisonSociale: { contains: query.search, mode: 'insensitive' } },
                  { ville: { contains: query.search, mode: 'insensitive' } },
                ],
              },
            ],
          }
        : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.prospect.findMany({
        where,
        select: prospectListSelect,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { lastActivityAt: 'desc' },
      }),
      this.prisma.prospect.count({ where }),
    ]);

    return { data, total, page, limit, scope: { type: scope.type } };
  }

  /** Prospects groupés par étape — la vue Kanban d'Helios. */
  async pipeline(user: User) {
    const scope = this.scope(user);
    const prospects = await this.prisma.prospect.findMany({
      where: { deletedAt: null, ...scope.where },
      select: prospectListSelect,
      orderBy: { lastActivityAt: 'desc' },
    });

    const etapes = ETAPES_ORDONNEES.map((statut) => {
      const rows = prospects.filter((p) => p.statut === statut);
      const valeurPonderee = rows.reduce(
        (somme, p) => somme + (Number(p.potentielCaAnnuel ?? 0) * p.probabilite) / 100,
        0,
      );
      return { statut, total: rows.length, valeurPonderee: Math.round(valeurPonderee), prospects: rows };
    });

    return { etapes, scope: { type: scope.type } };
  }

  /** Fiche prospect — 404 hors du périmètre du rôle (pas de fuite d'existence). */
  async findOne(user: User, id: string) {
    const prospect = await this.prisma.prospect.findFirst({
      where: { id, deletedAt: null, ...this.scope(user).where },
      include: {
        secteur: { select: { id: true, code: true, nom: true } },
        assignedTo: { select: { id: true, displayName: true } },
        createdBy: { select: { id: true, displayName: true } },
        client: { select: { id: true, codeAs400: true, enseigne: true } },
        contacts: { where: { deletedAt: null }, orderBy: { createdAt: 'desc' } },
        notes: {
          where: { deletedAt: null },
          orderBy: { createdAt: 'desc' },
          include: { auteur: { select: { id: true, displayName: true } } },
        },
      },
    });
    if (!prospect) throw new NotFoundException(`Prospect ${id} introuvable`);
    return prospect;
  }

  /** Timeline de la fiche : visites de prospection + opportunités, du plus récent au plus ancien. */
  async historique(user: User, id: string) {
    await this.findOne(user, id); // vérifie existence + périmètre

    const [visites, opportunites, appels, emails, etapes, notes] = await Promise.all([
      this.prisma.visite.findMany({
        where: { prospectId: id, deletedAt: null },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          createdAt: true,
          motif: true,
          pmcCommentaire: true,
          promoteur: { select: { id: true, displayName: true } },
        },
      }),
      this.prisma.opportunite.findMany({
        where: { prospectId: id, deletedAt: null },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          createdAt: true,
          type: true,
          statut: true,
          libelle: true,
          valeurEstimee: true,
          dateDebut: true,
          dateFin: true,
        },
      }),
      this.prisma.prospectAppel.findMany({
        where: { prospectId: id, deletedAt: null },
        orderBy: { dateAppel: 'desc' },
        select: {
          id: true,
          dateAppel: true,
          dureeSec: true,
          resultat: true,
          commentaire: true,
          auteur: { select: { id: true, displayName: true } },
        },
      }),
      this.prisma.prospectEmail.findMany({
        where: { prospectId: id, deletedAt: null },
        orderBy: { dateEmail: 'desc' },
        select: {
          id: true,
          dateEmail: true,
          destinataire: true,
          sujet: true,
          commentaire: true,
          auteur: { select: { id: true, displayName: true } },
        },
      }),
      this.prisma.prospectEtape.findMany({
        where: { prospectId: id },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          createdAt: true,
          de: true,
          vers: true,
          commentaire: true,
          auteur: { select: { id: true, displayName: true } },
        },
      }),
      this.prisma.clientNote.findMany({
        where: { prospectId: id, deletedAt: null },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          createdAt: true,
          remarque: true,
          auteur: { select: { id: true, displayName: true } },
        },
      }),
    ]);

    const timeline = [
      ...visites.map((v) => ({ type: 'VISITE' as const, date: v.createdAt, visite: v })),
      ...opportunites.map((o) => ({ type: 'OPPORTUNITE' as const, date: o.createdAt, opportunite: o })),
      ...appels.map((a) => ({ type: 'APPEL' as const, date: a.dateAppel, appel: a })),
      ...emails.map((m) => ({ type: 'EMAIL' as const, date: m.dateEmail, email: m })),
      ...etapes.map((e) => ({ type: 'ETAPE' as const, date: e.createdAt, etape: e })),
      ...notes.map((n) => ({ type: 'NOTE' as const, date: n.createdAt, note: n })),
    ].sort((a, b) => b.date.getTime() - a.date.getTime());

    return { data: timeline, total: timeline.length };
  }

  /** Pièces jointes de la fiche (sans le binaire). */
  async listPiecesJointes(user: User, prospectId: string) {
    await this.findOne(user, prospectId);
    return this.prisma.prospectPieceJointe.findMany({
      where: { prospectId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        nom: true,
        mime: true,
        taille: true,
        createdAt: true,
        auteur: { select: { displayName: true } },
      },
    });
  }

  /** Dépose une pièce jointe (10 Mo max) sur la fiche. */
  async addPieceJointe(
    user: User,
    prospectId: string,
    fichier: { originalname: string; mimetype: string; size: number; buffer: Buffer },
  ) {
    await this.findOne(user, prospectId);
    if (fichier.size > 10 * 1024 * 1024) {
      throw new BadRequestException('Pièce jointe trop volumineuse (10 Mo maximum).');
    }
    const pj = await this.prisma.prospectPieceJointe.create({
      data: {
        prospectId,
        auteurId: user.id,
        nom: fichier.originalname,
        mime: fichier.mimetype || 'application/octet-stream',
        taille: fichier.size,
        donnees: Uint8Array.from(fichier.buffer),
      },
      select: { id: true, nom: true, taille: true, createdAt: true },
    });
    await this.prisma.prospect.update({ where: { id: prospectId }, data: { lastActivityAt: pj.createdAt } });
    return pj;
  }

  /** Binaire d'une pièce jointe (pour le téléchargement). */
  async getPieceJointe(user: User, prospectId: string, pjId: string) {
    await this.findOne(user, prospectId);
    const pj = await this.prisma.prospectPieceJointe.findFirst({
      where: { id: pjId, prospectId, deletedAt: null },
    });
    if (!pj) throw new NotFoundException(`Pièce jointe ${pjId} introuvable`);
    return pj;
  }

  /** Supprime (logiquement) une pièce jointe. */
  async removePieceJointe(user: User, prospectId: string, pjId: string) {
    await this.getPieceJointe(user, prospectId, pjId);
    await this.prisma.prospectPieceJointe.update({ where: { id: pjId }, data: { deletedAt: new Date() } });
    return { id: pjId, supprime: true };
  }

  /** Ajoute une note à la fiche prospect (timeline). */
  async addNote(user: User, prospectId: string, remarque: string) {
    await this.findOne(user, prospectId);
    const note = await this.prisma.clientNote.create({
      data: { prospectId, remarque: remarque.trim(), auteurId: user.id },
      select: { id: true, remarque: true, createdAt: true },
    });
    await this.prisma.prospect.update({ where: { id: prospectId }, data: { lastActivityAt: note.createdAt } });
    return note;
  }

  /** Journalise un appel passé au prospect (mobile) — idempotent par idApk. */
  async createAppel(user: User, prospectId: string, dto: CreateAppelDto) {
    await this.findOne(user, prospectId); // vérifie existence + périmètre du rôle

    if (dto.idApk) {
      const existant = await this.prisma.prospectAppel.findUnique({ where: { idApk: dto.idApk } });
      if (existant) return { id: existant.id, idApk: dto.idApk, dejaSynchronise: true };
    }

    const appel = await this.prisma.prospectAppel.create({
      data: {
        prospectId,
        auteurId: user.id,
        dateAppel: dto.dateAppel ? new Date(dto.dateAppel) : new Date(),
        dureeSec: dto.dureeSec ?? null,
        resultat: dto.resultat ?? 'REPONDU',
        commentaire: dto.commentaire?.trim() || null,
        idApk: dto.idApk ?? null,
      },
      select: { id: true, dateAppel: true, resultat: true },
    });
    // Un appel est une activité : la fiche remonte dans les listes triées.
    await this.prisma.prospect.update({
      where: { id: prospectId },
      data: { lastActivityAt: appel.dateAppel },
    });
    return { ...appel, dejaSynchronise: false };
  }

  /** Journalise un email envoyé au prospect — idempotent par idApk. */
  async createEmail(user: User, prospectId: string, dto: CreateEmailDto) {
    await this.findOne(user, prospectId); // vérifie existence + périmètre du rôle

    if (dto.idApk) {
      const existant = await this.prisma.prospectEmail.findUnique({ where: { idApk: dto.idApk } });
      if (existant) return { id: existant.id, idApk: dto.idApk, dejaSynchronise: true };
    }

    const email = await this.prisma.prospectEmail.create({
      data: {
        prospectId,
        auteurId: user.id,
        dateEmail: dto.dateEmail ? new Date(dto.dateEmail) : new Date(),
        destinataire: dto.destinataire?.trim() || null,
        sujet: dto.sujet?.trim() || null,
        commentaire: dto.commentaire?.trim() || null,
        idApk: dto.idApk ?? null,
      },
      select: { id: true, dateEmail: true },
    });
    await this.prisma.prospect.update({
      where: { id: prospectId },
      data: { lastActivityAt: email.dateEmail },
    });
    return { ...email, dejaSynchronise: false };
  }

  async create(user: User, dto: CreateProspectDto, idApk?: string) {
    const statut = dto.statut ?? 'NOUVEAU';
    return this.prisma.prospect.create({
      data: {
        raisonSociale: dto.raisonSociale.trim(),
        enseigne: dto.enseigne.trim(),
        adresse1: dto.adresse1?.trim() || null,
        codePostal: dto.codePostal?.trim() || null,
        ville: dto.ville?.trim() || null,
        telephone: dto.telephone?.trim() || null,
        email: dto.email?.trim() || null,
        secteurId: dto.secteurId ?? null,
        assignedToId: dto.assignedToId ?? user.id,
        createdById: user.id,
        statut,
        probabilite: dto.probabilite ?? PROBABILITE_PAR_ETAPE[statut],
        potentielCaAnnuel: dto.potentielCaAnnuel ?? null,
        source: dto.source ?? null,
        niveauClass: dto.niveauClass ?? null,
        idApk: idApk ?? null,
      },
      select: prospectListSelect,
    });
  }

  /** Création depuis le mobile — idempotente par idApk (l'outbox peut rejouer). */
  async createApk(user: User, dto: CreateProspectApkDto) {
    const existant = await this.prisma.prospect.findUnique({ where: { idApk: dto.idApk } });
    if (existant) return { id: existant.id, idApk: dto.idApk, dejaSynchronise: true };
    const cree = await this.create(user, dto, dto.idApk);
    return { id: cree.id, idApk: dto.idApk, dejaSynchronise: false };
  }

  async update(user: User, id: string, dto: UpdateProspectDto) {
    const prospect = await this.findOne(user, id);

    // Changement d'étape : la probabilité par défaut de la nouvelle étape
    // s'applique, sauf probabilité explicitement fournie.
    const changeEtape = dto.statut && dto.statut !== prospect.statut;
    if (dto.statut === 'PERDU' && !dto.motifPerte && !prospect.motifPerte) {
      throw new BadRequestException('motifPerte est requis pour passer un prospect en PERDU');
    }

    // Trace du pipeline : chaque changement d'étape nourrit la timeline.
    if (changeEtape) {
      await this.prisma.prospectEtape.create({
        data: { prospectId: id, auteurId: user.id, de: prospect.statut, vers: dto.statut!, commentaire: dto.motifPerte ?? null },
      });
    }
    return this.prisma.prospect.update({
      where: { id },
      data: {
        ...(dto.raisonSociale !== undefined ? { raisonSociale: dto.raisonSociale.trim() } : {}),
        ...(dto.enseigne !== undefined ? { enseigne: dto.enseigne.trim() } : {}),
        ...(dto.adresse1 !== undefined ? { adresse1: dto.adresse1?.trim() || null } : {}),
        ...(dto.codePostal !== undefined ? { codePostal: dto.codePostal?.trim() || null } : {}),
        ...(dto.ville !== undefined ? { ville: dto.ville?.trim() || null } : {}),
        ...(dto.telephone !== undefined ? { telephone: dto.telephone?.trim() || null } : {}),
        ...(dto.email !== undefined ? { email: dto.email?.trim() || null } : {}),
        ...(dto.secteurId !== undefined ? { secteurId: dto.secteurId } : {}),
        ...(dto.assignedToId !== undefined ? { assignedToId: dto.assignedToId } : {}),
        ...(dto.statut !== undefined ? { statut: dto.statut } : {}),
        ...(dto.probabilite !== undefined
          ? { probabilite: dto.probabilite }
          : changeEtape
            ? { probabilite: PROBABILITE_PAR_ETAPE[dto.statut!] }
            : {}),
        ...(dto.potentielCaAnnuel !== undefined ? { potentielCaAnnuel: dto.potentielCaAnnuel } : {}),
        ...(dto.source !== undefined ? { source: dto.source } : {}),
        ...(dto.motifPerte !== undefined ? { motifPerte: dto.motifPerte } : {}),
        lastActivityAt: new Date(),
      },
      select: prospectListSelect,
    });
  }

  async remove(user: User, id: string) {
    await this.findOne(user, id);
    await this.prisma.prospect.update({ where: { id }, data: { deletedAt: new Date() } });
    return { id, supprime: true };
  }

  /**
   * Conversion Prospect → Client (idempotente) : crée le Client à partir des
   * champs du prospect, y rattache contacts / notes / visites / opportunités,
   * passe le statut à GAGNE et pose clientId.
   * Le codeAs400 provisoire (PRSP-xxxxxxxx) sera remplacé par le vrai code
   * ERP au premier import AS400 le concernant (arbitrage admin).
   */
  async convert(user: User, id: string) {
    const prospect = await this.findOne(user, id);

    if (prospect.clientId) {
      const client = await this.prisma.client.findUnique({ where: { id: prospect.clientId } });
      return { clientId: prospect.clientId, client, dejaConverti: true };
    }

    const client = await this.prisma.$transaction(async (tx) => {
      const cree = await tx.client.create({
        data: {
          codeAs400: `PRSP-${prospect.id.slice(0, 8).toUpperCase()}`,
          enseigne: prospect.enseigne,
          raisonSociale: prospect.raisonSociale,
          adresse1: prospect.adresse1,
          codePostal: prospect.codePostal,
          ville: prospect.ville,
          tel1: prospect.telephone,
          email: prospect.email,
          secteurId: prospect.secteurId,
          niveauClass: prospect.niveauClass,
          creeParId: user.id,
        },
      });
      // Rattache les satellites au nouveau client. La contrainte « client OU prospect »
      // impose de basculer le lien ; l'historique reste traçable via prospect.clientId.
      await tx.clientContact.updateMany({ where: { prospectId: id }, data: { clientId: cree.id, prospectId: null } });
      await tx.clientNote.updateMany({ where: { prospectId: id }, data: { clientId: cree.id, prospectId: null } });
      await tx.visite.updateMany({ where: { prospectId: id }, data: { clientId: cree.id, prospectId: null } });
      await tx.opportunite.updateMany({ where: { prospectId: id }, data: { clientId: cree.id, prospectId: null } });
      await tx.prospect.update({
        where: { id },
        data: { statut: 'GAGNE', probabilite: 100, clientId: cree.id, lastActivityAt: new Date() },
      });
      return cree;
    });

    return { clientId: client.id, client, dejaConverti: false };
  }
}
