import {
  ConflictException,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { StatutCommandeApk } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { MailService } from '../mail/mail.service';
import { CreateCommandeApkDto } from './dto/create-commande-apk.dto';
import { UpdateCommandeApkDto } from './dto/update-commande-apk.dto';
import { construireMailCommande } from './commande-mail';
import {
  filtreModifieDepuis,
  lireModifieDepuis,
  selectHorodatageSansSuppression,
  TRI_MODIFIE_DEPUIS,
} from '../common/modifie-depuis';

/** Délai minimal entre deux envois de mail pour une même commande (anti-abus). */
const DELAI_ENTRE_MAILS_MS = 60_000;

/** Jour courant (yyyy-mm-dd) à Paris : référence du « ne pas livrer avant ». */
function aujourdhuiParis(): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Paris' }).format(new Date());
}

/** yyyy-mm-dd valide (ex. 2026-02-30 refusé) -> Date UTC minuit pour une colonne DATE. */
function lireJour(valeur: string): Date {
  const d = new Date(`${valeur}T00:00:00.000Z`);
  if (Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== valeur) {
    throw new BadRequestException('nePasLivrerAvant : date invalide');
  }
  return d;
}

const jourTexte = (d: Date | null) => (d ? d.toISOString().slice(0, 10) : null);

/**
 * Règles du « ne pas livrer avant » : motif obligatoire dès que la date est posée, motif sans date refusé,
 * date non antérieure à aujourd'hui (contrôlée seulement quand la date est fournie). `null` efface les deux.
 */
function resoudreNePasLivrer(
  entree: { nePasLivrerAvant?: string | null; motifNePasLivrerAvant?: string | null },
  actuel: { nePasLivrerAvant: Date | null; motifNePasLivrerAvant: string | null } | null,
): { nePasLivrerAvant?: Date | null; motifNePasLivrerAvant?: string | null } {
  if (entree.nePasLivrerAvant === undefined && entree.motifNePasLivrerAvant === undefined) return {};
  let date: Date | null;
  let motif: string | null;
  if (entree.nePasLivrerAvant === undefined) date = actuel?.nePasLivrerAvant ?? null;
  else if (entree.nePasLivrerAvant === null) date = null;
  else {
    date = lireJour(entree.nePasLivrerAvant);
    if (entree.nePasLivrerAvant < aujourdhuiParis()) {
      throw new BadRequestException("nePasLivrerAvant : la date ne peut pas être antérieure à aujourd'hui");
    }
  }
  if (entree.motifNePasLivrerAvant === undefined) motif = entree.nePasLivrerAvant === null ? null : (actuel?.motifNePasLivrerAvant ?? null);
  else motif = entree.motifNePasLivrerAvant?.trim() || null;
  if (date && !motif) throw new BadRequestException('Un motif est obligatoire quand « ne pas livrer avant » est renseigné');
  if (!date && motif) throw new BadRequestException('Le motif de « ne pas livrer avant » exige une date');
  return { nePasLivrerAvant: date, motifNePasLivrerAvant: motif };
}

/**
 * Commande saisie sur l'app mobile, en attente d'intégration ERP.
 * Une commande EN_ATTENTE est un brouillon du promoteur (modifiable, envoyable par mail au client pour validation) :
 * elle n'est jamais exportable vers l'ERP avant d'être VALIDEE (voir la vue SQL v_commandes_apk_a_exporter).
 * Idempotente par `idCommandeApk` : l'outbox mobile peut rejouer sans doublon
 * (même mécanique que les visites, voir VisitesService).
 */
@Injectable()
export class CommandesApkService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly mail: MailService,
  ) {}

  /** Les articles de toutes les lignes doivent exister (même contrôle à la création et à la modification). */
  private async verifierArticles(lignes: { articleId: string }[]) {
    const articleIds = [...new Set(lignes.map((l) => l.articleId))];
    const connus = await this.prisma.article.findMany({
      where: { id: { in: articleIds }, deletedAt: null },
      select: { id: true },
    });
    if (connus.length !== articleIds.length) {
      const trouves = new Set(connus.map((a) => a.id));
      const manquant = articleIds.find((id) => !trouves.has(id));
      throw new NotFoundException(`Article ${manquant} introuvable`);
    }
  }

  /** Commande du promoteur connecté, sinon 404 / 403. Les rôles non commerciaux sont déjà écartés par le contrôleur. */
  private async chargerProprietaire(promoteur: { id: string }, id: string) {
    const commande = await this.prisma.commandeApk.findUnique({
      where: { id },
      select: {
        id: true,
        promoteurId: true,
        statut: true,
        emailEnvoyeLe: true,
        emailValidation: true,
        nePasLivrerAvant: true,
        motifNePasLivrerAvant: true,
      },
    });
    if (!commande) throw new NotFoundException(`Commande mobile ${id} introuvable`);
    if (commande.promoteurId !== promoteur.id) {
      throw new ForbiddenException('Cette commande appartient à un autre promoteur');
    }
    return commande;
  }

  private conflitValidee(): ConflictException {
    return new ConflictException(
      'Cette commande est déjà validée : elle ne peut plus être modifiée, envoyée ni supprimée',
    );
  }

  async create(promoteur: { id: string }, dto: CreateCommandeApkDto) {
    const existante = await this.prisma.commandeApk.findUnique({
      where: { idCommandeApk: dto.idCommandeApk },
    });
    if (existante) {
      if (existante.promoteurId !== promoteur.id) {
        throw new ForbiddenException('Cet identifiant de commande appartient à un autre promoteur');
      }
      return {
        id: existante.id,
        idCommandeApk: dto.idCommandeApk,
        statut: existante.statut,
        nePasLivrerAvant: jourTexte(existante.nePasLivrerAvant),
        motifNePasLivrerAvant: existante.motifNePasLivrerAvant,
        dejaSynchronisee: true,
      };
    }

    const client = await this.prisma.client.findFirst({
      where: { id: dto.clientId, deletedAt: null },
    });
    if (!client) throw new NotFoundException(`Magasin ${dto.clientId} introuvable`);

    const livraison = resoudreNePasLivrer(dto, null);
    await this.verifierArticles(dto.lignes);

    const statut = dto.statut ?? StatutCommandeApk.VALIDEE;
    const commande = await this.prisma.commandeApk.create({
      data: {
        idCommandeApk: dto.idCommandeApk,
        promoteurId: promoteur.id,
        clientId: dto.clientId,
        dateCommande: new Date(dto.dateCommande),
        commentaire: dto.commentaire?.trim() || null,
        statut,
        emailValidation: dto.emailValidation?.trim() || null,
        valideeLe: statut === StatutCommandeApk.VALIDEE ? new Date() : null,
        nePasLivrerAvant: livraison.nePasLivrerAvant ?? null,
        motifNePasLivrerAvant: livraison.motifNePasLivrerAvant ?? null,
        lignes: {
          create: dto.lignes.map((l, i) => ({
            ordre: i + 1,
            articleId: l.articleId,
            quantite: l.quantite,
            prixIndicatif: l.prixIndicatif ?? null,
          })),
        },
      },
    });

    return {
      id: commande.id,
      idCommandeApk: dto.idCommandeApk,
      statut: commande.statut,
      nePasLivrerAvant: jourTexte(commande.nePasLivrerAvant),
      motifNePasLivrerAvant: commande.motifNePasLivrerAvant,
      dejaSynchronisee: false,
    };
  }

  /** Détail d'une commande mobile avec ses lignes (scopé : un commercial ne voit que les siennes). */
  async findOne(user: { id: string; role: string }, id: string) {
    const commande = await this.prisma.commandeApk.findFirst({
      where: { id, ...(user.role === 'COMMERCIAL' ? { promoteurId: user.id } : {}) },
      select: {
        id: true,
        idCommandeApk: true,
        dateCommande: true,
        commentaire: true,
        statut: true,
        emailValidation: true,
        emailEnvoyeLe: true,
        valideeLe: true,
        nePasLivrerAvant: true,
        motifNePasLivrerAvant: true,
        client: { select: { id: true, codeAs400: true, enseigne: true, ville: true, email: true } },
        promoteur: { select: { id: true, displayName: true } },
        lignes: {
          orderBy: { ordre: 'asc' },
          select: {
            ordre: true,
            quantite: true,
            prixIndicatif: true,
            article: { select: { id: true, codeAs400: true, libelle: true, gencode: true, pcb: true } },
          },
        },
      },
    });
    if (!commande) throw new NotFoundException(`Commande mobile ${id} introuvable`);

    // « Intégrée » n'a de sens que pour une commande validée.
    const erp =
      commande.statut === StatutCommandeApk.VALIDEE
        ? await this.prisma.commande.findFirst({
            where: { idCommandeApk: commande.idCommandeApk },
            select: { id: true, numero: true },
          })
        : null;

    return {
      ...commande,
      nePasLivrerAvant: jourTexte(commande.nePasLivrerAvant),
      integree: erp !== null,
      numeroErp: erp?.numero ?? null,
      totalIndicatif: commande.lignes.reduce(
        (s, l) => s + l.quantite * Number(l.prixIndicatif ?? 0),
        0,
      ),
    };
  }

  /** Commandes mobiles du promoteur connecté (la direction voit tout). */
  async findAll(
    user: { id: string; role: string },
    query: {
      page?: number;
      limit?: number;
      clientId?: string;
      statut?: StatutCommandeApk;
      modifieDepuis?: string;
    },
  ) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    // Synchro incrémentale : commandes mobiles modifiées depuis l'instant donné (pas de suppression logique ici).
    const depuis = lireModifieDepuis(query.modifieDepuis);
    const where = {
      ...filtreModifieDepuis(depuis),
      ...(user.role === 'COMMERCIAL' ? { promoteurId: user.id } : {}),
      ...(query.clientId ? { clientId: query.clientId } : {}),
      ...(query.statut ? { statut: query.statut } : {}),
    };

    const [rows, total] = await Promise.all([
      this.prisma.commandeApk.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: depuis ? TRI_MODIFIE_DEPUIS : { dateCommande: 'desc' },
        select: {
          id: true,
          idCommandeApk: true,
          dateCommande: true,
          commentaire: true,
          statut: true,
          emailValidation: true,
          emailEnvoyeLe: true,
          valideeLe: true,
          nePasLivrerAvant: true,
          motifNePasLivrerAvant: true,
          ...selectHorodatageSansSuppression(depuis),
          client: { select: { id: true, codeAs400: true, enseigne: true, ville: true } },
          promoteur: { select: { id: true, displayName: true } },
          lignes: { select: { quantite: true, prixIndicatif: true } },
        },
      }),
      this.prisma.commandeApk.count({ where }),
    ]);

    // Une commande mobile est « intégrée » quand l'import Minos a ramené une
    // commande ERP portant son IDCRM — aucun statut à maintenir, on croise.
    // Seules les commandes VALIDEES peuvent l'être.
    const validees = rows.filter((r) => r.statut === StatutCommandeApk.VALIDEE);
    const integrees = validees.length
      ? new Set(
          (
            await this.prisma.commande.findMany({
              where: { idCommandeApk: { in: validees.map((r) => r.idCommandeApk) } },
              select: { idCommandeApk: true },
            })
          ).map((c) => c.idCommandeApk),
        )
      : new Set<string | null>();

    return {
      data: rows.map(({ lignes, ...r }) => ({
        ...r,
        nePasLivrerAvant: jourTexte(r.nePasLivrerAvant),
        integree: r.statut === StatutCommandeApk.VALIDEE && integrees.has(r.idCommandeApk),
        nbLignes: lignes.length,
        totalIndicatif: lignes.reduce((s, l) => s + l.quantite * Number(l.prixIndicatif ?? 0), 0),
      })),
      total,
      page,
      limit,
    };
  }

  /** Modifie une commande EN_ATTENTE (lignes remplacées si fournies). 409 si elle est déjà validée. */
  async update(promoteur: { id: string; role: string }, id: string, dto: UpdateCommandeApkDto) {
    const commande = await this.chargerProprietaire(promoteur, id);
    if (commande.statut !== StatutCommandeApk.EN_ATTENTE) throw this.conflitValidee();
    const livraison = resoudreNePasLivrer(dto, commande);
    if (dto.lignes) await this.verifierArticles(dto.lignes);

    await this.prisma.$transaction(async (tx) => {
      // Garde atomique : si la commande a été validée entre-temps, rien n'est modifié.
      const maj = await tx.commandeApk.updateMany({
        where: { id, promoteurId: promoteur.id, statut: StatutCommandeApk.EN_ATTENTE },
        data: {
          updatedAt: new Date(),
          ...(dto.dateCommande !== undefined ? { dateCommande: new Date(dto.dateCommande) } : {}),
          ...(dto.commentaire !== undefined ? { commentaire: dto.commentaire?.trim() || null } : {}),
          ...(dto.emailValidation !== undefined ? { emailValidation: dto.emailValidation?.trim() || null } : {}),
          ...livraison,
        },
      });
      if (maj.count === 0) throw this.conflitValidee();
      if (dto.lignes) {
        await tx.commandeApkLigne.deleteMany({ where: { commandeApkId: id } });
        await tx.commandeApkLigne.createMany({
          data: dto.lignes.map((l, i) => ({
            commandeApkId: id,
            ordre: i + 1,
            articleId: l.articleId,
            quantite: l.quantite,
            prixIndicatif: l.prixIndicatif ?? null,
          })),
        });
      }
    });

    return this.findOne(promoteur, id);
  }

  /** Valide une commande EN_ATTENTE. Idempotent : déjà validée, on renvoie l'état sans erreur. */
  async valider(promoteur: { id: string; role: string }, id: string) {
    await this.chargerProprietaire(promoteur, id);
    await this.prisma.commandeApk.updateMany({
      where: { id, promoteurId: promoteur.id, statut: StatutCommandeApk.EN_ATTENTE },
      data: { statut: StatutCommandeApk.VALIDEE, valideeLe: new Date(), updatedAt: new Date() },
    });
    return this.findOne(promoteur, id);
  }

  /** Supprime une commande EN_ATTENTE (jamais transmise à l'ERP). Interdit si validée. */
  async remove(promoteur: { id: string }, id: string) {
    const commande = await this.chargerProprietaire(promoteur, id);
    if (commande.statut !== StatutCommandeApk.EN_ATTENTE) throw this.conflitValidee();
    await this.prisma.$transaction(async (tx) => {
      await tx.commandeApkLigne.deleteMany({ where: { commandeApkId: id } });
      const r = await tx.commandeApk.deleteMany({
        where: { id, promoteurId: promoteur.id, statut: StatutCommandeApk.EN_ATTENTE },
      });
      if (r.count === 0) throw this.conflitValidee(); // annule aussi la suppression des lignes
    });
    return { id, supprimee: true };
  }

  /**
   * Envoie la commande EN_ATTENTE par mail au client. La commande reste EN_ATTENTE (le promoteur peut encore la
   * modifier). 503 sans SMTP, 429 si un mail est déjà parti il y a moins d'une minute.
   */
  async envoyerMail(promoteur: { id: string; role: string }, id: string, email: string) {
    const commande = await this.chargerProprietaire(promoteur, id);
    if (commande.statut !== StatutCommandeApk.EN_ATTENTE) throw this.conflitValidee();
    this.mail.exigerConfiguration();

    // Réservation atomique de l'envoi : deux clics simultanés ne partent pas deux fois.
    const maintenant = new Date();
    const reserve = await this.prisma.commandeApk.updateMany({
      where: {
        id,
        promoteurId: promoteur.id,
        statut: StatutCommandeApk.EN_ATTENTE,
        OR: [
          { emailEnvoyeLe: null },
          { emailEnvoyeLe: { lt: new Date(maintenant.getTime() - DELAI_ENTRE_MAILS_MS) } },
        ],
      },
      data: { emailValidation: email.trim(), emailEnvoyeLe: maintenant, updatedAt: maintenant },
    });
    if (reserve.count === 0) {
      throw new HttpException(
        "Un mail vient déjà d'être envoyé pour cette commande : patientez une minute avant de recommencer",
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    try {
      const detail = await this.prisma.commandeApk.findUniqueOrThrow({
        where: { id },
        select: {
          idCommandeApk: true,
          dateCommande: true,
          commentaire: true,
          nePasLivrerAvant: true,
          motifNePasLivrerAvant: true,
          promoteur: { select: { displayName: true, email: true } },
          client: { select: { enseigne: true, ville: true, codeAs400: true } },
          lignes: {
            orderBy: { ordre: 'asc' },
            select: {
              quantite: true,
              prixIndicatif: true,
              article: { select: { codeAs400: true, libelle: true } },
            },
          },
        },
      });
      await this.mail.envoyer({
        to: email.trim(),
        replyTo: detail.promoteur.email ?? undefined,
        ...construireMailCommande(detail),
      });
    } catch (e) {
      // Échec : on rend la main (état précédent) pour que le promoteur puisse réessayer tout de suite.
      await this.prisma.commandeApk.updateMany({
        where: { id },
        data: { emailValidation: commande.emailValidation, emailEnvoyeLe: commande.emailEnvoyeLe },
      });
      throw e;
    }

    return this.findOne(promoteur, id);
  }
}
