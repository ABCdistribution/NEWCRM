import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { NiveauClass, Prisma, Role, StatutPropositionPem, TypeVisite } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { idReprVariants } from '../common/id-repr.util';
import {
  DELAI_EXPIRATION_ACCEPTEE_JOURS,
  FREQUENCE_PEM_DEFAUT,
  HEURE_JOB_PEM,
  HORIZON_PROGRAMMATION_JOURS,
  STATUTS_PEM_OUVERTS,
} from './pem.constants';
import { ajouterJours, dateDeProposition, enTexteJour, heureParis, jourParis } from './pem.dates';

/** Magasin chargé pour la programmation. */
const selectClientPem = {
  id: true,
  enseigne: true,
  niveauClass: true,
  secteurId: true,
  idCommercial1: true,
  idCommercial2: true,
  // Commerciaux rattachés au magasin : promoteurs actifs seulement, ordre alphabétique (déterministe).
  commerciaux: {
    where: { role: Role.COMMERCIAL, isActive: true },
    orderBy: [{ displayName: 'asc' }, { id: 'asc' }],
    take: 1,
    select: { id: true },
  },
} satisfies Prisma.ClientSelect;
type ClientPem = Prisma.ClientGetPayload<{ select: typeof selectClientPem }>;

export interface PropositionCreee {
  id: string;
  clientId: string;
  promoteurId: string;
  dateProposee: string; // yyyy-mm-dd
}

const TAILLE_LOT = 500;

/**
 * Programmation automatique des visites PEM : propose une visite aux promoteurs responsables des magasins soumis au
 * suivi PEM, selon la fréquence de leur classe. Idempotent : rejouable sans doublon (une seule proposition ouverte par
 * magasin, garantie par un index unique partiel en base).
 *
 * Le job quotidien suit le mécanisme déjà utilisé par `RapportsService` (minuteur interne, pas de dépendance
 * supplémentaire) : un contrôle toutes les 15 minutes, exécution à partir de 3 h (Paris), une fois par jour.
 */
@Injectable()
export class PemProgrammationService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PemProgrammationService.name);
  private minuteur?: NodeJS.Timeout;
  private dernierJourExecute: string | null = null;
  private enCours = false;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    setTimeout(() => void this.executerSiNecessaire(), 90_000).unref();
    this.minuteur = setInterval(() => void this.executerSiNecessaire(), 15 * 60_000);
    this.minuteur.unref();
  }

  onModuleDestroy() {
    if (this.minuteur) clearInterval(this.minuteur);
  }

  /** Lance la programmation une fois par jour, la nuit (rattrape un démarrage tardif). */
  private async executerSiNecessaire(now: Date = new Date()) {
    const jour = enTexteJour(jourParis(now));
    if (heureParis(now) < HEURE_JOB_PEM || this.dernierJourExecute === jour) return;
    try {
      const creees = await this.programmerTous(now);
      this.dernierJourExecute = jour;
      this.logger.log(`Programmation PEM du ${jour} : ${creees.length} proposition(s) créée(s).`);
    } catch (e) {
      // dernierJourExecute n'est pas posé : le prochain contrôle réessaie.
      this.logger.error(`Programmation PEM en échec : ${e instanceof Error ? e.message : String(e)}`);
    }
  }

  /** Programme tous les magasins actifs soumis au suivi PEM qui n'ont pas de proposition ouverte. */
  async programmerTous(now: Date = new Date()): Promise<PropositionCreee[]> {
    if (this.enCours) return []; // un passage à la fois (job nocturne et déclenchement manuel)
    this.enCours = true;
    try {
      await this.expirerAccepteesDepassees(now);
      const creees: PropositionCreee[] = [];
      let curseur: string | undefined;
      for (;;) {
        const lot = await this.prisma.client.findMany({
          where: {
            suiviPem: true,
            actif: true,
            deletedAt: null,
            propositionsPem: { none: { statut: { in: STATUTS_PEM_OUVERTS } } },
            ...(curseur ? { id: { gt: curseur } } : {}),
          },
          select: selectClientPem,
          orderBy: { id: 'asc' },
          take: TAILLE_LOT,
        });
        if (lot.length === 0) break;
        creees.push(...(await this.programmerLot(lot, now)));
        curseur = lot[lot.length - 1].id;
        if (lot.length < TAILLE_LOT) break;
      }
      return creees;
    } finally {
      this.enCours = false;
    }
  }

  /**
   * Libère les magasins dont la visite PEM acceptée n'a jamais été réalisée : une proposition ACCEPTEE dont la date est
   * dépassée de plus de DELAI_EXPIRATION_ACCEPTEE_JOURS jours passe en ANNULEE (la ligne de planning reste, non faite,
   * comme trace de la visite manquée). La proposition suivante peut alors être créée. Renvoie le nombre expirées.
   */
  async expirerAccepteesDepassees(now: Date = new Date(), clientId?: string): Promise<number> {
    const limite = ajouterJours(jourParis(now), -DELAI_EXPIRATION_ACCEPTEE_JOURS);
    const { count } = await this.prisma.propositionPem.updateMany({
      where: { statut: StatutPropositionPem.ACCEPTEE, visiteId: null, dateProposee: { lt: limite }, ...(clientId ? { clientId } : {}) },
      data: { statut: StatutPropositionPem.ANNULEE },
    });
    if (count > 0) this.logger.log(`${count} proposition(s) PEM acceptée(s) non réalisée(s) depuis plus de ${DELAI_EXPIRATION_ACCEPTEE_JOURS} jours : annulée(s).`);
    return count;
  }

  /**
   * Programme un magasin (activation du suivi PEM) : renvoie la proposition créée, ou null si le magasin n'est pas
   * concerné (inactif, pas de suivi), a déjà une proposition ouverte, n'est pas encore à échéance ou n'a aucun promoteur.
   */
  async programmerClient(clientId: string, now: Date = new Date()): Promise<PropositionCreee | null> {
    await this.expirerAccepteesDepassees(now, clientId);
    const client = await this.prisma.client.findFirst({
      where: {
        id: clientId,
        suiviPem: true,
        actif: true,
        deletedAt: null,
        propositionsPem: { none: { statut: { in: STATUTS_PEM_OUVERTS } } },
      },
      select: selectClientPem,
    });
    if (!client) return null;
    return (await this.programmerLot([client], now))[0] ?? null;
  }

  private async programmerLot(clients: ClientPem[], now: Date): Promise<PropositionCreee[]> {
    const aujourdhui = jourParis(now);
    const ids = clients.map((c) => c.id);

    const [frequences, visites, realisees] = await Promise.all([
      this.prisma.frequencePemClasse.findMany({ select: { niveauClass: true, semaines: true } }),
      this.prisma.visite.groupBy({
        by: ['clientId'],
        where: { clientId: { in: ids }, typeVisite: TypeVisite.PEM, deletedAt: null },
        _max: { createdAt: true },
      }),
      this.prisma.propositionPem.groupBy({
        by: ['clientId'],
        where: { clientId: { in: ids }, statut: StatutPropositionPem.REALISEE },
        _max: { updatedAt: true },
      }),
    ]);
    const semainesParClasse = new Map<NiveauClass, number>(frequences.map((f) => [f.niveauClass, f.semaines]));
    const derniere = new Map<string, Date>();
    for (const v of visites) if (v.clientId && v._max.createdAt) derniere.set(v.clientId, v._max.createdAt);
    for (const p of realisees) {
      const d = p._max.updatedAt;
      const actuelle = derniere.get(p.clientId);
      if (d && (!actuelle || d > actuelle)) derniere.set(p.clientId, d);
    }

    const cacheCodes = new Map<string, string | null>();
    const cacheSecteurs = new Map<string, string | null>();
    const creees: PropositionCreee[] = [];

    for (const client of clients) {
      const semaines = (client.niveauClass ? semainesParClasse.get(client.niveauClass) : undefined) ?? FREQUENCE_PEM_DEFAUT;
      const date = dateDeProposition(derniere.get(client.id) ?? null, semaines, aujourdhui, HORIZON_PROGRAMMATION_JOURS);
      if (!date) continue;

      const promoteurId = await this.promoteurResponsable(client, cacheCodes, cacheSecteurs);
      if (!promoteurId) {
        this.logger.warn(`Visite PEM non proposée pour « ${client.enseigne} » (${client.id}) : aucun promoteur responsable.`);
        continue;
      }
      try {
        const p = await this.prisma.propositionPem.create({
          data: { clientId: client.id, promoteurId, dateProposee: date },
          select: { id: true },
        });
        creees.push({ id: p.id, clientId: client.id, promoteurId, dateProposee: enTexteJour(date) });
      } catch (e) {
        // Une proposition ouverte est apparue entre-temps (index unique partiel) : rien à créer.
        if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') continue;
        throw e;
      }
    }
    return creees;
  }

  /**
   * Promoteur responsable d'un magasin, de façon déterministe :
   *  1. les commerciaux rattachés au magasin (Client.commerciaux), actifs, rôle COMMERCIAL, par ordre alphabétique ;
   *  2. à défaut, le promoteur désigné par les codes représentants de la fiche (idCommercial1 puis idCommercial2 : c'est
   *     ainsi que l'import AS400 renseigne le magasin tant que la relation ci-dessus n'est pas remplie) ;
   *  3. à défaut, un promoteur COMMERCIAL actif du secteur du magasin, par ordre alphabétique.
   * Aucun promoteur : null (le magasin n'est pas programmé, la raison est tracée dans les logs).
   */
  private async promoteurResponsable(
    client: ClientPem,
    cacheCodes: Map<string, string | null>,
    cacheSecteurs: Map<string, string | null>,
  ): Promise<string | null> {
    if (client.commerciaux[0]) return client.commerciaux[0].id;

    for (const brut of [client.idCommercial1, client.idCommercial2]) {
      const code = brut?.trim();
      if (!code) continue;
      if (!cacheCodes.has(code)) {
        const u = await this.prisma.user.findFirst({
          where: { idRepr: { in: idReprVariants(code) }, role: Role.COMMERCIAL, isActive: true },
          orderBy: [{ displayName: 'asc' }, { id: 'asc' }],
          select: { id: true },
        });
        cacheCodes.set(code, u?.id ?? null);
      }
      const id = cacheCodes.get(code);
      if (id) return id;
    }

    if (!client.secteurId) return null;
    if (!cacheSecteurs.has(client.secteurId)) {
      const u = await this.prisma.user.findFirst({
        where: { secteurId: client.secteurId, role: Role.COMMERCIAL, isActive: true },
        orderBy: [{ displayName: 'asc' }, { id: 'asc' }],
        select: { id: true },
      });
      cacheSecteurs.set(client.secteurId, u?.id ?? null);
    }
    return cacheSecteurs.get(client.secteurId) ?? null;
  }
}
