// Liste des clients (page /clients) : lecture des filtres de l'adresse et chargement côté serveur (serverFetch).
// Les droits et le périmètre restent décidés par l'API ; ici on ne filtre rien, on transmet les filtres demandés.
import { qs, serverFetch, type Role } from './api';

export type ClientListe = {
  id: string;
  codeAs400: string;
  enseigne: string;
  raisonSociale: string;
  ville: string | null;
  codePostal: string | null;
  niveauClass: string | null;
  actif: boolean;
  createdAt: string;
};

export type StatutClients = 'actifs' | 'inactifs' | 'tous';

export type FiltresClients = {
  search: string;
  page: number;
  /** « A » à « G », « aucun », ou absent (tous les niveaux). */
  niveau?: string;
  statut: StatutClients;
  /** « Mes clients » : uniquement les clients de mon périmètre (promoteur, chef de secteur, directeur régional). */
  mes: boolean;
};

export type CompteursClients = { total: number; actifs: number; inactifs: number };

/** Lignes par page. */
export const LIMITE_CLIENTS = 50;

/** Rôles qui ont un périmètre de clients (les autres voient tout le référentiel : pas de filtre « Mes clients »). */
const ROLES_AVEC_PERIMETRE: readonly Role[] = ['COMMERCIAL', 'CHEF_SECTEUR', 'DIRECTEUR_REGIONAL'];

export const aUnPerimetre = (role: Role): boolean => ROLES_AVEC_PERIMETRE.includes(role);

const NIVEAU = /^([A-G]|aucun)$/;

/**
 * Filtres lus dans l'adresse (`?search=&niveau=&statut=&tous=&page=`). Toute valeur inattendue est ignorée :
 * statut « actifs » par défaut, page 1, « Mes clients » actif par défaut pour les rôles qui ont un périmètre
 * (il se désactive avec `tous=1`). Le texte cherché est borné à 80 caractères.
 */
export function lireFiltresClients(
  sp: { search?: string; page?: string; niveau?: string; statut?: string; tous?: string },
  role: Role,
): FiltresClients {
  const brut = (v: unknown) => (typeof v === 'string' ? v : '');
  const niveau = brut(sp.niveau).trim();
  const page = /^\d{1,5}$/.test(brut(sp.page)) ? Math.max(1, Number(sp.page)) : 1;
  return {
    search: brut(sp.search).trim().slice(0, 80),
    page,
    niveau: NIVEAU.test(niveau) ? niveau : undefined,
    statut: sp.statut === 'inactifs' || sp.statut === 'tous' ? sp.statut : 'actifs',
    mes: aUnPerimetre(role) && sp.tous !== '1',
  };
}

const actifDe = (statut: StatutClients) => (statut === 'actifs' ? 'true' : statut === 'inactifs' ? 'false' : undefined);

async function lire<T>(chemin: string): Promise<T> {
  const res = await serverFetch(chemin);
  if (!res.ok) throw new Error(`Erreur API ${res.status} sur ${chemin}`);
  return (await res.json()) as T;
}

type Page = { data: ClientListe[]; total: number; page: number; limit: number };

/**
 * Liste filtrée + compteurs (tous / actifs / inactifs dans le même périmètre « mes clients », indépendants de la
 * recherche et du niveau). Renvoie null si l'API ne répond pas ou refuse.
 */
export async function chargerClients(f: FiltresClients): Promise<{ liste: Page; compteurs: CompteursClients } | null> {
  const perimetre = f.mes ? { mes: 1 } : {};
  try {
    const [liste, total, actifs, inactifs] = await Promise.all([
      lire<Page>(
        `/clients${qs({
          search: f.search,
          page: f.page,
          limit: LIMITE_CLIENTS,
          niveau: f.niveau,
          actif: actifDe(f.statut),
          avecAdresse: 1,
          ...perimetre,
        })}`,
      ),
      lire<Page>(`/clients${qs({ limit: 1, avecAdresse: 1, ...perimetre })}`),
      lire<Page>(`/clients${qs({ limit: 1, avecAdresse: 1, actif: 'true', ...perimetre })}`),
      lire<Page>(`/clients${qs({ limit: 1, avecAdresse: 1, actif: 'false', ...perimetre })}`),
    ]);
    return { liste, compteurs: { total: total.total, actifs: actifs.total, inactifs: inactifs.total } };
  } catch {
    return null;
  }
}
