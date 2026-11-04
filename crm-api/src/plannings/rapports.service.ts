import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, Role, User } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import {
  LigneRapport,
  PhaseSemaine,
  ajouterJours,
  clotureAutoDue,
  controleLignes,
  derniereSemaineACloturer,
  heureDe,
  isoJour,
  jourParis,
  ligneVide,
  lundiDe,
  numeroIso,
  phaseDe,
} from './rapport-semaine.util';

/** Étape avec sa cible, telle que lue pour construire une ligne du rapport. */
const etapeLigneSelect = {
  id: true,
  adm: true,
  clientId: true,
  prospectId: true,
  libelle: true,
  adresse: true,
  datePassage: true,
  fait: true,
  note: true,
  visiteSimple: true,
  accompagnement: true,
  rdv: true,
  soireeEtape: true,
  soireeLieu: true,
  soireeAdresse: true,
  client: { select: { enseigne: true, ville: true, adresse1: true, codePostal: true } },
  prospect: { select: { enseigne: true, ville: true, adresse1: true, codePostal: true } },
} satisfies Prisma.TourneeEtapeSelect;

type EtapeLigne = Prisma.TourneeEtapeGetPayload<{ select: typeof etapeLigneSelect }>;

/** Statut d'un rapport, tel que la consultation l'affiche. */
export type StatutRapport =
  | 'PREVISION_A_SAISIR' // jusqu'au lundi soir, rien d'enregistré
  | 'PREVISION_ENREGISTREE' // jusqu'au lundi soir, prévision enregistrée (modifiable)
  | 'EN_COURS' // dès le mardi, tournée réalisée modifiable
  | 'VALIDE'
  | 'VALIDE_AUTO';

export interface EtatSemaine {
  semaine: string;
  phase: PhaseSemaine;
  prevuAt: Date | null;
  valideAt: Date | null;
  valideAuto: boolean;
  nbEtapesPrevues: number | null;
  /** Dès le mardi sans prévision enregistrée : « non renseignée », on passe directement au rapport. */
  previsionNonRenseignee: boolean;
  /** Jusqu'au lundi soir et semaine non validée. */
  previsionModifiable: boolean;
  /** Le bouton « Valider le rapport » apparaît dès le mardi. */
  peutValider: boolean;
  /** Validée : plus rien n'est modifiable. */
  verrouillee: boolean;
  statut: StatutRapport;
}

function ligneDepuisEtape(e: EtapeLigne): LigneRapport {
  const cible = e.prospect ?? e.client;
  const adresseCible = cible
    ? [cible.adresse1?.trim(), [cible.codePostal?.trim(), cible.ville?.trim()].filter(Boolean).join(' ')].filter(Boolean).join(', ')
    : '';
  return {
    id: e.id,
    jour: isoJour(e.datePassage),
    heure: heureDe(e.datePassage),
    adm: e.adm,
    clientId: e.clientId,
    prospectId: e.prospectId,
    libelle: e.libelle,
    titre: e.adm ? 'ADM' : (cible?.enseigne ?? e.libelle ?? '').trim(),
    ville: cible?.ville ?? null,
    adresse: e.adresse?.trim() || adresseCible || null,
    visiteSimple: e.visiteSimple,
    accompagnement: e.accompagnement,
    rdv: e.rdv,
    soireeEtape: e.soireeEtape,
    soireeLieu: e.soireeLieu,
    soireeAdresse: e.soireeAdresse,
    note: e.note,
    fait: e.fait,
  };
}

function statutDe(phase: PhaseSemaine, row: { prevuAt: Date | null; valideAt: Date | null; valideAuto: boolean } | null): StatutRapport {
  if (row?.valideAt) return row.valideAuto ? 'VALIDE_AUTO' : 'VALIDE';
  if (phase === 'PREVISION') return row?.prevuAt ? 'PREVISION_ENREGISTREE' : 'PREVISION_A_SAISIR';
  return 'EN_COURS';
}

/** Photographie relue en base : on ne fait confiance qu'à la forme attendue. */
function lignesDepuisPhoto(json: Prisma.JsonValue | null | undefined): LigneRapport[] {
  return Array.isArray(json) ? (json as unknown as LigneRapport[]) : [];
}

@Injectable()
export class RapportsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RapportsService.name);
  private minuteur?: NodeJS.Timeout;
  private cloturePrete = true;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  // --- Lecture ---------------------------------------------------------------------------------------------------

  private async lignesDeLaSemaine(userId: string, lundi: Date): Promise<EtapeLigne[]> {
    return this.prisma.tourneeEtape.findMany({
      where: { userId, deletedAt: null, datePassage: { gte: lundi, lt: ajouterJours(lundi, 7) } },
      orderBy: { datePassage: 'asc' },
      select: etapeLigneSelect,
    });
  }

  async etat(userId: string, lundi: Date, now: Date = new Date()): Promise<EtatSemaine> {
    const row = await this.prisma.planningSemaine.findUnique({ where: { userId_semaine: { userId, semaine: lundi } } });
    const phase = phaseDe(lundi, now);
    const valideAt = row?.valideAt ?? null;
    return {
      semaine: isoJour(lundi),
      phase,
      prevuAt: row?.prevuAt ?? null,
      valideAt,
      valideAuto: row?.valideAuto ?? false,
      nbEtapesPrevues: row?.nbEtapesPrevues ?? null,
      previsionNonRenseignee: phase === 'RAPPORT' && !row?.prevuAt,
      previsionModifiable: phase === 'PREVISION' && !valideAt,
      peutValider: phase === 'RAPPORT' && !valideAt,
      verrouillee: !!valideAt,
      statut: statutDe(phase, row),
    };
  }

  /** Tournée prévue de MA semaine (la photographie), ou null si la prévision n'a pas été renseignée. */
  async prevuePour(userId: string, lundi: Date): Promise<LigneRapport[] | null> {
    const row = await this.prisma.planningSemaine.findUnique({
      where: { userId_semaine: { userId, semaine: lundi } },
      select: { previsionEtapes: true },
    });
    return row?.previsionEtapes ? lignesDepuisPhoto(row.previsionEtapes) : null;
  }

  /** Une semaine validée est verrouillée : aucune étape ne s'y ajoute, ne s'y modifie ni ne s'en retire. */
  async verifierModifiable(userId: string, date: Date): Promise<void> {
    const row = await this.prisma.planningSemaine.findUnique({
      where: { userId_semaine: { userId, semaine: lundiDe(date) } },
      select: { valideAt: true },
    });
    if (row?.valideAt) throw new ConflictException('Cette semaine est validée : plus rien n\'est modifiable.');
  }

  /**
   * Historique de MES rapports : la semaine en cours puis les `nb - 1` précédentes (les plus récentes d'abord), et les
   * chiffres du mois courant. Visites = étapes hors ADM ; réalisé / prévu = lignes faites sur lignes prévues ;
   * référencés = prospects à moi passés « gagné » (référencé) dans le mois.
   */
  async historique(userId: string, nb = 8, now: Date = new Date()) {
    const courant = lundiDe(jourParis(now));
    const debut = ajouterJours(courant, -7 * (nb - 1));
    const fin = ajouterJours(courant, 7);
    const [etapes, rows] = await Promise.all([
      this.prisma.tourneeEtape.findMany({
        where: { userId, deletedAt: null, datePassage: { gte: debut, lt: fin } },
        select: { datePassage: true, adm: true, fait: true, rdv: true },
      }),
      this.prisma.planningSemaine.findMany({ where: { userId, semaine: { gte: debut, lt: fin } } }),
    ]);

    const semaines = Array.from({ length: nb }, (_, i) => {
      const lundi = ajouterJours(courant, -7 * i);
      const jusqua = ajouterJours(lundi, 7);
      const row = rows.find((r) => isoJour(r.semaine) === isoJour(lundi)) ?? null;
      const mes = etapes.filter((e) => e.datePassage >= lundi && e.datePassage < jusqua);
      const visites = mes.filter((e) => !e.adm && e.fait).length;
      const nbPrevues = row?.nbEtapesPrevues ?? null;
      return {
        semaine: isoJour(lundi),
        numero: numeroIso(lundi),
        statut: statutDe(phaseDe(lundi, now), row),
        valideAt: row?.valideAt ?? null,
        valideAuto: row?.valideAuto ?? false,
        nbPrevues,
        nbLignes: mes.length,
        visites,
        rdv: mes.filter((e) => e.rdv).length,
        // Réalisé / prévu : sans prévision enregistrée, il n'y a rien à comparer.
        pourcentPrevu: nbPrevues ? Math.round((mes.filter((e) => e.fait).length / nbPrevues) * 100) : null,
      };
    }).filter((s) => s.nbLignes > 0 || s.nbPrevues !== null || s.valideAt !== null || s.semaine === isoJour(courant));

    // Chiffres du mois courant (mois de Paris).
    const jour = jourParis(now);
    const debutMois = new Date(`${jour.slice(0, 7)}-01T00:00:00.000Z`);
    const finMois = new Date(Date.UTC(debutMois.getUTCFullYear(), debutMois.getUTCMonth() + 1, 1));
    const [duMois, references] = await Promise.all([
      this.prisma.tourneeEtape.findMany({
        where: { userId, deletedAt: null, datePassage: { gte: debutMois, lt: finMois } },
        select: { adm: true, fait: true },
      }),
      this.prisma.prospect.count({
        where: { assignedToId: userId, deletedAt: null, statut: 'GAGNE', updatedAt: { gte: debutMois, lt: finMois } },
      }),
    ]);
    const lignesMois = duMois.filter((e) => !e.adm);
    return {
      mois: jour.slice(0, 7),
      visitesMois: lignesMois.filter((e) => e.fait).length,
      pourcentPrevuMois: lignesMois.length ? Math.round((lignesMois.filter((e) => e.fait).length / lignesMois.length) * 100) : null,
      references,
      semaines,
    };
  }

  // --- Prévision : photographie des étapes planifiées -------------------------------------------------------------

  async enregistrerPrevision(userId: string, lundi: Date, now: Date = new Date()): Promise<EtatSemaine> {
    const etat = await this.etat(userId, lundi, now);
    if (etat.verrouillee) throw new ConflictException('Cette semaine est déjà validée.');
    if (etat.phase !== 'PREVISION') {
      throw new ConflictException('La prévision est figée depuis le mardi : elle n\'est plus modifiable.');
    }
    const lignes = (await this.lignesDeLaSemaine(userId, lundi)).map(ligneDepuisEtape).filter((l) => !ligneVide(l));
    if (lignes.length === 0) throw new BadRequestException('La prévision ne peut pas être vide.');
    const erreurs = controleLignes(lignes);
    if (erreurs.length) throw new BadRequestException(erreurs.join(' '));

    // La photographie ne porte pas l'identifiant des étapes : c'est la tournée réalisée qui continue de vivre.
    const photo = lignes.map(({ id: _id, ...reste }) => reste) as unknown as Prisma.InputJsonValue;
    await this.prisma.planningSemaine.upsert({
      where: { userId_semaine: { userId, semaine: lundi } },
      create: { userId, semaine: lundi, prevuAt: now, nbEtapesPrevues: lignes.length, previsionEtapes: photo },
      update: { prevuAt: now, nbEtapesPrevues: lignes.length, previsionEtapes: photo },
    });
    return this.etat(userId, lundi, now);
  }

  // --- Validation ---------------------------------------------------------------------------------------------------

  /** Recrée la tournée réalisée à l'identique de la prévision (rapport vide, ou clôture automatique sans saisie). */
  private async reprendrePrevision(userId: string, lundi: Date, prevision: LigneRapport[]): Promise<void> {
    await this.prisma.tourneeEtape.createMany({
      data: prevision.map((l) => ({
        userId,
        adm: l.adm,
        clientId: l.clientId,
        prospectId: l.prospectId,
        libelle: l.libelle,
        adresse: l.adresse,
        datePassage: new Date(l.heure ? `${l.jour}T${l.heure}:00.000Z` : `${l.jour}T00:00:00.000Z`),
        note: l.note,
        visiteSimple: l.visiteSimple,
        accompagnement: l.accompagnement,
        rdv: l.rdv,
        soireeEtape: l.soireeEtape,
        soireeLieu: l.soireeEtape ? l.soireeLieu : null,
        soireeAdresse: l.soireeEtape ? l.soireeAdresse : null,
      })),
    });
  }

  /**
   * Valide le rapport : la tournée réalisée devient définitive et la semaine est verrouillée.
   * Manuelle (`auto` faux) : possible dès le mardi, avec les contrôles. Automatique : tournée réalisée telle quelle,
   * sans contrôle ; sans aucune ligne, la prévision est reprise ; sans prévision non plus, rien n'est clôturé (null).
   */
  async valider(userId: string, lundi: Date, opts: { auto?: boolean; now?: Date } = {}): Promise<EtatSemaine | null> {
    const auto = opts.auto ?? false;
    const now = opts.now ?? new Date();
    const row = await this.prisma.planningSemaine.findUnique({ where: { userId_semaine: { userId, semaine: lundi } } });
    if (row?.valideAt) {
      if (auto) return null;
      throw new ConflictException('Cette semaine est déjà validée.');
    }
    if (!auto && phaseDe(lundi, now) === 'PREVISION') {
      throw new BadRequestException('La prévision est encore modifiable : le rapport se valide à partir du mardi.');
    }

    let etapes = await this.lignesDeLaSemaine(userId, lundi);
    // Une ligne entièrement vide est ignorée.
    const vides = etapes.filter((e) => ligneVide(ligneDepuisEtape(e))).map((e) => e.id);
    if (vides.length) {
      await this.prisma.tourneeEtape.updateMany({ where: { id: { in: vides } }, data: { deletedAt: now } });
      etapes = etapes.filter((e) => !vides.includes(e.id));
    }

    if (etapes.length === 0) {
      const prevision = lignesDepuisPhoto(row?.previsionEtapes);
      if (prevision.length === 0) {
        if (auto) return null;
        throw new BadRequestException('Un rapport vide est refusé : saisissez au moins une ligne.');
      }
      await this.reprendrePrevision(userId, lundi, prevision);
      etapes = await this.lignesDeLaSemaine(userId, lundi);
    }

    if (!auto) {
      const erreurs = controleLignes(etapes.map(ligneDepuisEtape));
      if (erreurs.length) throw new BadRequestException(erreurs.join(' '));
    }

    await this.prisma.planningSemaine.upsert({
      where: { userId_semaine: { userId, semaine: lundi } },
      // La prévision n'est jamais inventée : sans prévision enregistrée elle reste « non renseignée ».
      create: { userId, semaine: lundi, valideAt: now, valideAuto: auto },
      update: { valideAt: now, valideAuto: auto },
    });
    return this.etat(userId, lundi, now);
  }

  // --- Clôture automatique : chaque lundi à 4 h (Paris), sur les semaines terminées non clôturées -------------------

  onModuleInit() {
    // Sans date de départ explicite, rien n'est clôturé : on ne verrouille jamais des semaines antérieures à la mise en service.
    if (!this.config.get<string>('RAPPORT_CLOTURE_DEPUIS')) {
      this.logger.warn('Clôture automatique des rapports désactivée (RAPPORT_CLOTURE_DEPUIS non défini).');
      return;
    }
    // Rattrapage au démarrage, puis contrôle régulier : idempotent (une semaine clôturée n'est jamais retraitée).
    setTimeout(() => void this.cloturerLesSemainesTerminees(), 60_000).unref();
    this.minuteur = setInterval(() => void this.cloturerLesSemainesTerminees(), 15 * 60_000);
    this.minuteur.unref();
  }

  onModuleDestroy() {
    if (this.minuteur) clearInterval(this.minuteur);
  }

  /** Clôture les semaines terminées (depuis `RAPPORT_CLOTURE_DEPUIS`, un lundi au format yyyy-mm-dd) non validées. */
  async cloturerLesSemainesTerminees(now: Date = new Date()): Promise<number> {
    if (!this.cloturePrete) return 0; // un passage à la fois
    const depuisBrut = this.config.get<string>('RAPPORT_CLOTURE_DEPUIS');
    if (!depuisBrut || !/^\d{4}-\d{2}-\d{2}$/.test(depuisBrut)) return 0;
    this.cloturePrete = false;
    try {
      const depuis = lundiDe(depuisBrut);
      const derniere = derniereSemaineACloturer(now);
      if (derniere < depuis) return 0;
      const limite = ajouterJours(derniere, 7); // exclu

      // Auteurs ayant des étapes, ou une prévision enregistrée, sur la période et dont la semaine n'est pas validée.
      const parEtapes = await this.prisma.$queryRaw<{ userId: string; semaine: Date }[]>(Prisma.sql`
        SELECT DISTINCT te."userId", date_trunc('week', te."datePassage")::date AS semaine
        FROM tournee_etapes te
        WHERE te."deletedAt" IS NULL AND te."datePassage" >= ${depuis} AND te."datePassage" < ${limite}`);
      const parPrevision = await this.prisma.planningSemaine.findMany({
        where: { valideAt: null, previsionEtapes: { not: Prisma.DbNull }, semaine: { gte: depuis, lt: limite } },
        select: { userId: true, semaine: true },
      });
      const candidats = new Map<string, { userId: string; semaine: Date }>();
      for (const c of [...parEtapes, ...parPrevision]) {
        const semaine = lundiDe(c.semaine);
        candidats.set(`${c.userId}|${isoJour(semaine)}`, { userId: c.userId, semaine });
      }

      let clotures = 0;
      for (const { userId, semaine } of candidats.values()) {
        if (!clotureAutoDue(semaine, now)) continue;
        try {
          if (await this.valider(userId, semaine, { auto: true, now })) clotures += 1;
        } catch (err) {
          this.logger.error(`Clôture automatique impossible (${userId}, ${isoJour(semaine)}) : ${(err as Error).message}`);
        }
      }
      if (clotures > 0) this.logger.log(`Clôture automatique : ${clotures} rapport(s) clôturé(s).`);
      return clotures;
    } finally {
      this.cloturePrete = true;
    }
  }

  // --- Consultation (directeurs régionaux, direction, administrateurs) -----------------------------------------------

  /** Auteurs de rapports (CS / DR actifs) que `me` peut consulter : tout pour ADMIN / DIRECTION, sa région et son équipe pour un DR. */
  private auteursVisibles(me: User): Prisma.UserWhereInput {
    const auteurs: Prisma.UserWhereInput = { isActive: true, role: { in: [Role.CHEF_SECTEUR, Role.DIRECTEUR_REGIONAL] } };
    if (me.role === Role.ADMIN || me.role === Role.DIRECTION) return auteurs;
    if (me.role === Role.DIRECTEUR_REGIONAL) {
      return {
        ...auteurs,
        OR: [{ id: me.id }, { directeurId: me.id }, ...(me.regionId ? [{ regionId: me.regionId }] : [])],
      };
    }
    throw new ForbiddenException('Consultation réservée à la direction, aux directeurs régionaux et aux administrateurs.');
  }

  async liste(me: User, lundi: Date, now: Date = new Date()) {
    const phase = phaseDe(lundi, now);
    const auteurs = await this.prisma.user.findMany({
      where: this.auteursVisibles(me),
      orderBy: { displayName: 'asc' },
      select: { id: true, displayName: true, role: true, region: { select: { nom: true } }, secteur: { select: { nom: true } } },
    });
    const ids = auteurs.map((a) => a.id);
    const [rows, comptes] = await Promise.all([
      this.prisma.planningSemaine.findMany({ where: { semaine: lundi, userId: { in: ids } } }),
      this.prisma.tourneeEtape.groupBy({
        by: ['userId', 'fait'],
        where: { userId: { in: ids }, deletedAt: null, datePassage: { gte: lundi, lt: ajouterJours(lundi, 7) } },
        _count: { _all: true },
      }),
    ]);
    return {
      semaine: isoJour(lundi),
      phase,
      auteurs: auteurs.map((a) => {
        const row = rows.find((r) => r.userId === a.id) ?? null;
        const mes = comptes.filter((c) => c.userId === a.id);
        const total = mes.reduce((s, c) => s + c._count._all, 0);
        const faites = mes.filter((c) => c.fait).reduce((s, c) => s + c._count._all, 0);
        return {
          userId: a.id,
          nom: a.displayName,
          role: a.role,
          region: a.region?.nom ?? null,
          secteur: a.secteur?.nom ?? null,
          statut: statutDe(phase, row),
          prevuAt: row?.prevuAt ?? null,
          previsionNonRenseignee: phase === 'RAPPORT' && !row?.prevuAt,
          valideAt: row?.valideAt ?? null,
          valideAuto: row?.valideAuto ?? false,
          nbPrevues: row?.nbEtapesPrevues ?? null,
          nbRealisees: total,
          nbFaites: faites,
        };
      }),
    };
  }

  /** Détail d'un rapport : tournée prévue (photographie) et tournée réalisée (ou rapport validé), côte à côte. */
  async detail(me: User, userId: string, lundi: Date, now: Date = new Date()) {
    const auteur = await this.prisma.user.findFirst({
      where: { AND: [{ id: userId }, this.auteursVisibles(me)] },
      select: { id: true, displayName: true, role: true },
    });
    if (!auteur) throw new NotFoundException('Rapport introuvable dans votre périmètre.');
    const [etat, row, etapes] = await Promise.all([
      this.etat(userId, lundi, now),
      this.prisma.planningSemaine.findUnique({ where: { userId_semaine: { userId, semaine: lundi } }, select: { previsionEtapes: true } }),
      this.lignesDeLaSemaine(userId, lundi),
    ]);
    return {
      auteur,
      etat,
      prevue: etat.previsionNonRenseignee || !row?.previsionEtapes ? null : lignesDepuisPhoto(row.previsionEtapes),
      realisee: etapes.map(ligneDepuisEtape),
    };
  }
}
