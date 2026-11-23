import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { NiveauClass, Prisma, Role, StatutPropositionPem } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { idReprVariants } from '../common/id-repr.util';
import { codesRepresentantsDuPerimetre } from '../common/perimetre-codes.util';
import { filtreModifieDepuis, lireModifieDepuis, TRI_MODIFIE_DEPUIS } from '../common/modifie-depuis';
import { auteursDeVisitesVisibles } from '../visites/visites.service';
import { PemProgrammationService } from './pem-programmation.service';
import {
  DELAI_REPORT_DEFAUT_JOURS,
  FENETRE_DATE_PEM_JOURS,
  FREQUENCE_PEM_DEFAUT,
  MAX_REPORTS_PEM,
  MESSAGE_OBLIGATOIRE,
  STATUTS_PEM_OUVERTS,
} from './pem.constants';
import { ajouterJours, enTexteJour, jourOuvreSuivantOuEgal, jourParis, lireJour } from './pem.dates';

/** Appelant authentifié (sous-ensemble de User). */
export type AppelantPem = { id: string; role: string; regionId?: string | null; idRepr?: string | null };

const NIVEAUX: NiveauClass[] = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
const TAILLE_PAGE = 200;

const selectProposition = {
  id: true,
  dateProposee: true,
  statut: true,
  nbReports: true,
  obligatoire: true,
  motifDernierReport: true,
  planningId: true,
  visiteId: true,
  createdAt: true,
  updatedAt: true,
  client: { select: { id: true, enseigne: true, ville: true } },
  promoteur: { select: { id: true, displayName: true } },
} satisfies Prisma.PropositionPemSelect;
type PropositionLue = Prisma.PropositionPemGetPayload<{ select: typeof selectProposition }>;

/** Forme exposée d'une proposition (dates « jour » en yyyy-mm-dd). */
function versDto(p: PropositionLue) {
  return {
    id: p.id,
    client: p.client,
    promoteur: p.promoteur,
    dateProposee: enTexteJour(p.dateProposee),
    statut: p.statut,
    nbReports: p.nbReports,
    obligatoire: p.obligatoire,
    reportsRestants: p.obligatoire ? 0 : Math.max(0, MAX_REPORTS_PEM - p.nbReports),
    motifDernierReport: p.motifDernierReport,
    planningId: p.planningId,
    visiteId: p.visiteId,
    createdAt: p.createdAt,
    updatedAt: p.updatedAt,
  };
}

/**
 * Un report est un rejeu si la proposition a déjà été reportée (au moins une fois) vers la date cible demandée et n'a
 * pas bougé depuis : encore PROPOSEE (non acceptée entre-temps), ou devenue obligatoire par ce même report. Une
 * proposition acceptée puis reportée à nouveau vers la même date n'est pas un rejeu (statut ACCEPTEE non obligatoire).
 */
function estRejeuReport(p: { statut: StatutPropositionPem; nbReports: number; obligatoire: boolean; dateProposee: Date }, cible: Date): boolean {
  return p.nbReports > 0 && p.dateProposee.getTime() === cible.getTime() && (p.obligatoire || p.statut === StatutPropositionPem.PROPOSEE);
}

@Injectable()
export class PemService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly programmation: PemProgrammationService,
  ) {}

  // --- Fréquences par classe ------------------------------------------------------------------------------------

  /** Fréquence (semaines) des 7 classes A à G ; une classe sans ligne retombe sur la valeur par défaut. */
  async frequences() {
    const lignes = await this.prisma.frequencePemClasse.findMany({ select: { niveauClass: true, semaines: true } });
    const parClasse = new Map(lignes.map((l) => [l.niveauClass, l.semaines]));
    return {
      classes: NIVEAUX.map((niveauClass) => ({ niveauClass, semaines: parClasse.get(niveauClass) ?? FREQUENCE_PEM_DEFAUT })),
      sansClasse: FREQUENCE_PEM_DEFAUT,
    };
  }

  async majFrequences(classes: { niveauClass: NiveauClass; semaines: number }[]) {
    const vues = new Set<string>();
    for (const c of classes) {
      if (vues.has(c.niveauClass)) throw new BadRequestException(`La classe ${c.niveauClass} est indiquée plusieurs fois`);
      vues.add(c.niveauClass);
    }
    await this.prisma.$transaction(
      classes.map((c) =>
        this.prisma.frequencePemClasse.upsert({
          where: { niveauClass: c.niveauClass },
          create: { niveauClass: c.niveauClass, semaines: c.semaines },
          update: { semaines: c.semaines },
        }),
      ),
    );
    return this.frequences();
  }

  // --- Articles PEM à vérifier en visite ------------------------------------------------------------------------

  articles() {
    return this.prisma.pemArticle.findMany({
      where: { actif: true, article: { deletedAt: null } },
      orderBy: [{ article: { libelle: 'asc' } }, { id: 'asc' }],
      select: {
        id: true,
        article: { select: { id: true, codeAs400: true, libelle: true, gencode: true, marque: { select: { nom: true } } } },
      },
    });
  }

  // --- Suivi PEM d'un magasin -----------------------------------------------------------------------------------

  /**
   * Un magasin est dans la région du directeur régional si son secteur y est rattaché ou si son promoteur (codes
   * représentants de la fiche) fait partie des promoteurs de la région — même règle que « Mes clients ».
   */
  private async clientDansRegion(me: AppelantPem, client: { secteur: { regionId: string | null } | null; idCommercial1: string | null; idCommercial2: string | null }) {
    if (!me.regionId) return false;
    if (client.secteur?.regionId === me.regionId) return true;
    const codes = await codesRepresentantsDuPerimetre(this.prisma, {
      id: me.id,
      role: me.role,
      idRepr: me.idRepr ?? null,
      regionId: me.regionId,
    });
    if (!codes?.length) return false;
    const aCodes = new Set(codes);
    return [client.idCommercial1, client.idCommercial2].some((c) => c?.trim() && idReprVariants(c.trim()).some((v) => aCodes.has(v)));
  }

  /**
   * Active ou désactive le suivi PEM d'un magasin. ADMIN / DIRECTION : tous les magasins ; DIRECTEUR_REGIONAL : ceux de
   * sa région (403 sinon). Activer programme tout de suite la visite PEM ; désactiver annule la proposition ouverte.
   */
  async changerSuivi(me: AppelantPem, clientId: string, suiviPem: boolean) {
    const client = await this.prisma.client.findFirst({
      where: { id: clientId, deletedAt: null },
      select: { id: true, suiviPem: true, idCommercial1: true, idCommercial2: true, secteur: { select: { regionId: true } } },
    });
    if (!client) throw new NotFoundException(`Client ${clientId} introuvable`);
    if (me.role === Role.DIRECTEUR_REGIONAL && !(await this.clientDansRegion(me, client))) {
      throw new ForbiddenException("Ce magasin n'est pas dans votre région");
    }

    if (!suiviPem) {
      await this.prisma.$transaction(async (tx) => {
        await tx.client.update({ where: { id: clientId }, data: { suiviPem: false } });
        const ouvertes = await tx.propositionPem.findMany({
          where: { clientId, statut: { in: STATUTS_PEM_OUVERTS } },
          select: { id: true, planningId: true },
        });
        if (ouvertes.length === 0) return;
        const plannings = ouvertes.flatMap((o) => (o.planningId ? [o.planningId] : []));
        // La ligne de planning créée à l'acceptation disparaît avec la proposition, sauf si la visite a été faite.
        if (plannings.length) {
          await tx.planning.updateMany({ where: { id: { in: plannings }, fait: false, deletedAt: null }, data: { deletedAt: new Date() } });
        }
        await tx.propositionPem.updateMany({
          where: { id: { in: ouvertes.map((o) => o.id) }, statut: { in: STATUTS_PEM_OUVERTS } },
          data: { statut: StatutPropositionPem.ANNULEE },
        });
      });
      return { id: clientId, suiviPem: false, proposition: null };
    }

    if (!client.suiviPem) await this.prisma.client.update({ where: { id: clientId }, data: { suiviPem: true } });
    // Programmation immédiate (idempotente : déjà activé = rien de plus si une proposition est ouverte).
    const creee = await this.programmation.programmerClient(clientId);
    const proposition = creee
      ? versDto(await this.prisma.propositionPem.findUniqueOrThrow({ where: { id: creee.id }, select: selectProposition }))
      : null;
    return { id: clientId, suiviPem: true, proposition };
  }

  // --- Propositions ---------------------------------------------------------------------------------------------

  /**
   * Propositions visibles par `me` : un promoteur voit les siennes ; un chef de secteur / directeur régional celles de
   * son équipe (et les siennes) ; ADMIN / DIRECTION toutes. Sans `statut` ni `modifieDepuis` : propositions ouvertes
   * seulement ; avec `modifieDepuis` (synchro) : toutes celles modifiées depuis, annulées et réalisées comprises.
   */
  async propositions(me: AppelantPem, opts: { statut?: StatutPropositionPem; modifieDepuis?: string; page?: number; clientId?: string }) {
    const depuis = lireModifieDepuis(opts.modifieDepuis);
    const auteurs = auteursDeVisitesVisibles(me);
    const where: Prisma.PropositionPemWhereInput = {
      ...(auteurs ? { promoteur: auteurs } : {}),
      // Filtre optionnel par magasin, en plus du périmètre ci-dessus (jamais à la place).
      ...(opts.clientId ? { clientId: opts.clientId } : {}),
      ...(opts.statut ? { statut: opts.statut } : depuis ? {} : { statut: { in: STATUTS_PEM_OUVERTS } }),
      ...filtreModifieDepuis(depuis),
    };
    const page = opts.page && opts.page > 0 ? opts.page : 1;
    const [rows, total] = await Promise.all([
      this.prisma.propositionPem.findMany({
        where,
        orderBy: depuis ? TRI_MODIFIE_DEPUIS : [{ dateProposee: 'asc' }, { id: 'asc' }],
        skip: (page - 1) * TAILLE_PAGE,
        take: TAILLE_PAGE,
        select: selectProposition,
      }),
      this.prisma.propositionPem.count({ where }),
    ]);
    return { data: rows.map(versDto), total, page, limit: TAILLE_PAGE };
  }

  /** Proposition attribuée à `me` ; 404 si inconnue, 403 si elle est attribuée à un autre promoteur. */
  private async propositionDuPromoteur(me: AppelantPem, id: string) {
    const p = await this.prisma.propositionPem.findUnique({
      where: { id },
      select: { id: true, clientId: true, promoteurId: true, statut: true, dateProposee: true, nbReports: true, obligatoire: true, planningId: true },
    });
    if (!p) throw new NotFoundException(`Proposition PEM ${id} introuvable`);
    if (p.promoteurId !== me.id) throw new ForbiddenException("Cette visite PEM n'est pas attribuée à votre compte");
    return p;
  }

  private async lire(id: string) {
    return versDto(await this.prisma.propositionPem.findUniqueOrThrow({ where: { id }, select: selectProposition }));
  }

  /** Date choisie par le promoteur : un vrai jour entre `min` et `max` inclus. */
  private dateChoisie(texte: string, min: Date, max: Date, libelle: string): Date {
    const jour = lireJour(texte);
    if (!jour) throw new BadRequestException('La date doit être au format AAAA-MM-JJ');
    if (jour < min || jour > max) throw new BadRequestException(`La date ${libelle}`);
    return jour;
  }

  /** Ligne de planning du promoteur sur le jour (réutilise celle du même magasin le même jour, sinon la crée). */
  private async planningDuJour(tx: Prisma.TransactionClient, promoteurId: string, clientId: string, jour: Date) {
    const existant = await tx.planning.findFirst({
      where: { promoteurId, clientId, deletedAt: null, datePassage: { gte: jour, lt: ajouterJours(jour, 1) } },
      select: { id: true },
    });
    if (existant) return existant.id;
    const cree = await tx.planning.create({ data: { promoteurId, clientId, datePassage: jour }, select: { id: true } });
    return cree.id;
  }

  /**
   * Le promoteur accepte la visite PEM : une ligne est ajoutée à son planning (à la date proposée, ou à `date` entre
   * aujourd'hui et +14 jours). Idempotent : une proposition déjà acceptée est renvoyée telle quelle.
   */
  async accepter(me: AppelantPem, id: string, date?: string) {
    const p = await this.propositionDuPromoteur(me, id);
    if (p.statut === StatutPropositionPem.ACCEPTEE) return this.lire(id);
    if (p.statut !== StatutPropositionPem.PROPOSEE) throw new ConflictException("Cette visite PEM n'est plus ouverte");

    const aujourdhui = jourParis(new Date());
    // Limite de fenêtre ramenée au jour ouvré (jamais un week-end ni un férié) ; la date retenue l'est aussi.
    const limite = jourOuvreSuivantOuEgal(ajouterJours(aujourdhui, FENETRE_DATE_PEM_JOURS));
    const jour = jourOuvreSuivantOuEgal(
      date
        ? this.dateChoisie(date, aujourdhui, limite, `doit être comprise entre aujourd'hui et dans ${FENETRE_DATE_PEM_JOURS} jours`)
        : p.dateProposee < aujourdhui
          ? aujourdhui // proposition tardive : jamais de planning dans le passé
          : p.dateProposee,
    );

    await this.prisma.$transaction(async (tx) => {
      // Garde de concurrence : un seul des appels simultanés crée la ligne de planning.
      const verrou = await tx.propositionPem.updateMany({
        where: { id, statut: StatutPropositionPem.PROPOSEE },
        data: { statut: StatutPropositionPem.ACCEPTEE },
      });
      if (verrou.count === 0) return;
      const planningId = await this.planningDuJour(tx, me.id, p.clientId, jour);
      await tx.propositionPem.update({ where: { id }, data: { planningId, dateProposee: jour } });
    });
    return this.lire(id);
  }

  /**
   * Refus ou report (même compteur). Nouvelle date : `date` (de demain à +14 jours) ou, par défaut, dans 7 jours (jour
   * ouvré). Au 3e report la visite devient obligatoire et est acceptée d'office ; ensuite, plus de report (409).
   */
  async reporter(me: AppelantPem, id: string, motif?: string, date?: string) {
    const p = await this.propositionDuPromoteur(me, id);
    if (!p.obligatoire && !STATUTS_PEM_OUVERTS.includes(p.statut)) throw new ConflictException("Cette visite PEM n'est plus ouverte");

    const aujourdhui = jourParis(new Date());
    // Date cible toujours ramenée au jour ouvré suivant (week-end et jours fériés sautés), limite de fenêtre comprise.
    const nouvelle = jourOuvreSuivantOuEgal(
      date
        ? this.dateChoisie(date, ajouterJours(aujourdhui, 1), jourOuvreSuivantOuEgal(ajouterJours(aujourdhui, FENETRE_DATE_PEM_JOURS)), `doit être comprise entre demain et dans ${FENETRE_DATE_PEM_JOURS} jours`)
        : ajouterJours(aujourdhui, DELAI_REPORT_DEFAUT_JOURS),
    );
    // Rejeu (mobile hors ligne qui retente) : déjà reportée vers cette date = état actuel, sans second report.
    if (estRejeuReport(p, nouvelle)) return this.lire(id);
    if (p.obligatoire) throw new ConflictException(MESSAGE_OBLIGATOIRE);
    const nbReports = p.nbReports + 1;
    const obligatoire = nbReports >= MAX_REPORTS_PEM;

    const ok = await this.prisma.$transaction(async (tx) => {
      // Garde de concurrence : le compteur lu doit être celui de la base (deux reports simultanés ne comptent pas double).
      const maj = await tx.propositionPem.updateMany({
        where: { id, statut: { in: STATUTS_PEM_OUVERTS }, obligatoire: false, nbReports: p.nbReports },
        data: {
          nbReports,
          obligatoire,
          motifDernierReport: motif?.trim() || null,
          dateProposee: nouvelle,
          statut: StatutPropositionPem.PROPOSEE,
          planningId: null,
        },
      });
      if (maj.count === 0) return false;
      // La ligne de planning de l'ancienne date (visite acceptée puis reportée) disparaît, sauf si déjà faite.
      if (p.planningId) {
        await tx.planning.updateMany({ where: { id: p.planningId, fait: false, deletedAt: null }, data: { deletedAt: new Date() } });
      }
      if (obligatoire) {
        const planningId = await this.planningDuJour(tx, me.id, p.clientId, nouvelle);
        await tx.propositionPem.update({ where: { id }, data: { statut: StatutPropositionPem.ACCEPTEE, planningId } });
      }
      return true;
    });

    if (!ok) {
      const courante = await this.prisma.propositionPem.findUnique({ where: { id }, select: { obligatoire: true, statut: true, nbReports: true, dateProposee: true } });
      // Deux rejeux simultanés : le second voit le report du premier et renvoie l'état sans le compter une seconde fois.
      if (courante && estRejeuReport(courante, nouvelle)) return this.lire(id);
      throw new ConflictException(courante?.obligatoire ? MESSAGE_OBLIGATOIRE : 'Cette visite PEM vient d\'être modifiée : actualisez puis réessayez');
    }
    return this.lire(id);
  }

  /** Déclenchement manuel de la programmation (ADMIN, DIRECTION) : nombre de propositions créées. */
  async programmer() {
    const creees = await this.programmation.programmerTous();
    return { creees: creees.length };
  }
}
