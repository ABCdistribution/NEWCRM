// Chargement serveur des données de la carte d'accueil (serverFetch uniquement).
// Les droits restent décidés par l'API ; une erreur est renvoyée en message français, jamais avalée.
import { qs, serverFetch } from './api';

export type CarteRegion = {
  id: string;
  code: string;
  nom: string;
  nbCollaborateurs: number;
  nbChefsSecteur: number;
  nbPromoteurs: number;
  nbClients: number;
  chefsSecteur: {
    id: string;
    displayName: string;
    secteur: { id: string; code: string; nom: string } | null;
    nbClients: number;
    promoteurs: { id: string; displayName: string; nbClients: number }[];
  }[];
};

export type CarteEquipes = {
  regions: CarteRegion[];
  departements: { code: string; regionId: string; nbClients: number }[];
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

export function getCarteEquipes(): Promise<Resultat<CarteEquipes>> {
  return charger<CarteEquipes>('/dashboard/carte-equipes', 'la carte des équipes');
}

export function getCarteSecteur(
  p: { regionId?: string; secteurId?: string } = {},
): Promise<Resultat<CarteSecteurData>> {
  return charger<CarteSecteurData>(`/dashboard/carte-secteur${qs(p)}`, 'la carte du secteur');
}
