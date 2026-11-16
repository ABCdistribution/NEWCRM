// Chargement serveur des données de la carte d'accueil (serverFetch uniquement).
// Les droits restent décidés par l'API ; une erreur est renvoyée en message français, jamais avalée.
import { qs, serverFetch, type MagasinGeoPoint } from './api';

/** Activité d'un collaborateur ou d'une région sur le mois : visites, commandes, CA en euros, objectif mensuel et taux. */
export type Activite = {
  visites: number;
  commandes: number;
  ca: number;
  /** Objectif mensuel de CA (somme des objectifs annuels des magasins ÷ 12) ; null si aucun objectif n'est défini. */
  objectif: number | null;
  tauxPct: number | null;
};

/** Collaborateur d'une région, avec son intitulé de poste dans l'AD (ex. « Directrice nationale des ventes »). */
export type MembreRegion = { id: string; displayName: string; poste: string | null } & Activite;

export type CarteRegion = {
  id: string;
  code: string;
  nom: string;
  /** Effectif de la région : directeurs régionaux + chefs de secteur + promoteurs (même décompte que l'annuaire). */
  nbCollaborateurs: number;
  nbDirecteurs: number;
  nbChefsSecteur: number;
  nbPromoteurs: number;
  nbClients: number;
  /** Bilan du mois de la région : somme de l'activité de ses directeurs, chefs de secteur et promoteurs. */
  stats: Activite;
  directeurs: MembreRegion[];
  /** Promoteurs de la région dont le chef de secteur est d'une autre région, ou qui n'ont pas de chef (« chef » = son nom). */
  promoteursHorsChef: (MembreRegion & { nbClients: number; chef: string | null })[];
  chefsSecteur: (MembreRegion & {
    secteur: { id: string; code: string; nom: string } | null;
    nbClients: number;
    promoteurs: (MembreRegion & { nbClients: number })[];
  })[];
};

/** CA réalisé depuis le début de l'année et objectif prévu à cette date (cumul de toute la force de vente). */
export type CaADate = { ca: number; objectif: number };

export type CarteEquipes = {
  /** Mois de l'activité affichée (le mois en cours par défaut). */
  periode: { annee: number; mois: number };
  /** CA réalisé / objectif à date. PAS encore fourni par l'API : absent ou null, l'écran affiche un état « bientôt disponible ». */
  caADate?: CaADate | null;
  regions: CarteRegion[];
};

export type CarteClient = {
  id: string;
  nom: string;
  ville: string | null;
  codePostal: string | null;
  latitude: number;
  longitude: number;
  classe: string | null;
  promoteur: { id: string; displayName: string } | null;
};

export type CarteProspect = {
  id: string;
  nom: string;
  ville: string | null;
  codePostal: string | null;
  latitude: number;
  longitude: number;
  statut: string | null;
  chefSecteur: { id: string; displayName: string } | null;
};

export type CarteSecteurData = {
  clients: CarteClient[];
  prospects: CarteProspect[];
  tronque: boolean;
  limite: number;
};

/** Client listé en repli (sans carte) : le strict nécessaire pour l'affichage. */
export type ClientRepli = Pick<MagasinGeoPoint, 'id' | 'enseigne' | 'raisonSociale' | 'ville' | 'niveauClass'>;

/** Nombre maximum de clients listés en repli. */
const REPLI_MAX = 100;

export type Resultat<T> = { data: T; erreur?: undefined } | { data?: undefined; erreur: string };

async function charger<T>(chemin: string, libelle: string): Promise<Resultat<T>> {
  const majuscule = `${libelle[0].toUpperCase()}${libelle.slice(1)}`;
  try {
    const res = await serverFetch(chemin);
    if (!res.ok) {
      return {
        erreur:
          res.status === 403
            ? `Vous n'avez pas accès à ${libelle}.`
            : `${majuscule} est indisponible (erreur ${res.status}).`,
      };
    }
    return { data: (await res.json()) as T };
  } catch {
    return { erreur: `${majuscule} est indisponible : l'API ne répond pas.` };
  }
}

/** `annee` / `mois` : mois de l'activité affichée (le mois en cours par défaut) ; l'API reborne la saisie. */
export function getCarteEquipes(p: { annee?: number; mois?: number } = {}): Promise<Resultat<CarteEquipes>> {
  return charger<CarteEquipes>(`/dashboard/carte-equipes${qs(p)}`, 'la carte des équipes');
}

export function getCarteSecteur(
  p: { regionId?: string; secteurId?: string } = {},
): Promise<Resultat<CarteSecteurData>> {
  return charger<CarteSecteurData>(`/dashboard/carte-secteur${qs(p)}`, 'la carte du secteur');
}

/**
 * Clients du périmètre à lister quand aucun point n'est géolocalisé (carte du chef de secteur).
 * Écart avec crm-helios, qui appelait `GET /clients?limit=100` : cette liste n'est pas filtrée par périmètre
 * pour un chef de secteur / directeur régional (elle renvoie les clients de TOUT le réseau). On passe donc par
 * `GET /clients/geo`, que l'API restreint au périmètre de l'appelant (chef de secteur = ses promoteurs).
 */
export async function getClientsRepli(): Promise<Resultat<ClientRepli[]>> {
  const r = await charger<MagasinGeoPoint[]>('/clients/geo', 'la liste des clients');
  if (r.erreur !== undefined) return { erreur: r.erreur };
  return { data: r.data.slice(0, REPLI_MAX) };
}
