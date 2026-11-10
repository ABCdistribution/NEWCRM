import { cache } from 'react';
import { notFound, redirect } from 'next/navigation';
import { apiBase, getToken } from './session';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * L'API ne répond pas (réseau coupé, délai dépassé) ou répond en erreur serveur (5xx).
 * À distinguer d'une session absente (401) ou d'une ressource introuvable (404) : l'utilisateur n'est pas
 * déconnecté et la page n'est pas « introuvable », le service est simplement momentanément indisponible.
 * Le message sert aux journaux du serveur et aux tests, PAS à l'affichage : en production, Next remplace le message
 * d'une erreur levée côté serveur par un simple identifiant (`digest`). Les écrans d'erreur (`error.tsx`)
 * affichent donc un texte générique, avec cette référence.
 */
export class ApiIndisponibleError extends Error {
  constructor(options?: { cause?: unknown }) {
    super('Service momentanément indisponible, réessayez dans un instant.', options);
    this.name = 'ApiIndisponibleError';
  }
}

/**
 * Valide un identifiant avant de l'insérer dans un chemin d'API (anti path traversal) :
 * UUID attendu, sinon `notFound()` (404). À appeler HORS d'un try/catch (notFound lève).
 */
export function idSur(id: string): string {
  if (!UUID.test(id)) notFound();
  return id;
}

export type Role =
  | 'COMMERCIAL'
  | 'CHEF_SECTEUR'
  | 'ADMIN'
  | 'DIRECTEUR_REGIONAL'
  | 'DIRECTION'
  | 'ADV'
  | 'MARKETING';

export type Me = {
  id: string;
  username: string;
  displayName: string;
  email: string | null;
  role: Role;
  idRepr: string | null;
  poste: string | null;
};

/** Formes équivalentes d'un code représentant (AD « 68 » ↔ Minos « 068 »). */
export function idReprVariants(code: string): string[] {
  const v = new Set<string>([code]);
  if (/^\d+$/.test(code)) {
    v.add(code.padStart(3, '0'));
    v.add(String(Number(code)));
  }
  return [...v];
}

export type Paginated<T> = { data: T[]; total: number; page: number; limit: number };

export type UserRow = {
  id: string;
  username: string;
  displayName: string;
  email: string | null;
  role: Role;
  isActive: boolean;
  poste: string | null;
  idRepr: string | null;
  createdAt: string;
  secteurId: string | null;
  secteur: { id: string; code: string; nom: string } | null;
  region: { id: string; code: string; nom: string } | null;
  directeur: { id: string; displayName: string } | null;
};

export type ClientRow = {
  id: string;
  codeAs400: string;
  enseigne: string;
  raisonSociale: string;
  ville: string | null;
  actif: boolean;
  niveauClass: string | null;
};

export type ClientDetail = {
  id: string;
  codeAs400: string;
  enseigne: string;
  raisonSociale: string;
  adresse1: string | null;
  adresse2: string | null;
  adresse3: string | null;
  codePostal: string | null;
  ville: string | null;
  pays: string | null;
  langue: string | null;
  devise: string | null;
  siret: string | null;
  formeEntreprise: string | null;
  eanClient: string | null;
  tel1: string | null;
  tel2: string | null;
  contact1: string | null;
  contact2: string | null;
  contact3: string | null;
  email: string | null;
  actif: boolean;
  niveauClass: string | null;
  statutCommande: string | null;
  statutLivre: string | null;
  statutFacture: string | null;
  createdAt: string;
  updatedAt: string;
  secteur: { id: string; code: string; nom: string } | null;
  centrale: { id: string; code: string; nom: string } | null;
  commerciaux: { id: string; displayName: string; idRepr: string | null; role: Role }[];
  contacts: {
    id: string;
    prenom: string | null;
    nom: string;
    poste: string | null;
    typePoste: string | null;
    fixe: string | null;
    portable: string | null;
    mail: string | null;
  }[];
  notes: {
    id: string;
    remarque: string;
    createdAt: string;
    auteur: { displayName: string } | null;
  }[];
  periodicites: { id: string; periodicite: { id: string; code: number | null; libelle: string } }[];
  /** Absent pour le marketing (qui n'a accès ni aux commandes ni aux visites). */
  _count?: { visites: number; commandes: number };
};

export type CommandeRow = {
  id: string;
  numero: string;
  typeCmd: string | null;
  dateCommande: string | null;
  annulee: boolean;
  statutLivraison: StatutLivraison;
  dateLivraison: string | null;
  raisonSocialeCmd: string | null;
  idRepr: string | null;
  /** true = saisie mobile (Appli), false = EDI. Optionnel : absent tant que l'API n'est pas à jour. */
  viaMobile?: boolean;
  client: { id: string; codeAs400: string; enseigne: string } | null;
  nbLignes: number;
  total: number;
};

export type CommandeDetail = {
  id: string;
  numero: string;
  typeCmd: string | null;
  dateCommande: string | null;
  annulee: boolean;
  statutLivraison: StatutLivraison;
  dateExpedition: string | null;
  dateLivraison: string | null;
  transporteur: string | null;
  noSuivi: string | null;
  commentaireLivraison: string | null;
  raisonSocialeCmd: string | null;
  idRepr: string | null;
  idCommandeApk: string | null;
  client: { id: string; codeAs400: string; enseigne: string; ville: string | null } | null;
  lignes: {
    id: string;
    noLigne: string;
    libelleArticle: string | null;
    quantite: string;
    montant: string;
    article: { id: string; codeAs400: string; libelle: string } | null;
  }[];
  total: number;
};

export type CommandesResult = Paginated<CommandeRow> & {
  scope: { type: 'mine' | 'global'; idRepr: string | null };
};

export function listCommandes(params: {
  search?: string;
  page?: number;
  annulees?: boolean;
  livraison?: StatutLivraison;
  origine?: 'edi' | 'appli';
  /** « Mes commandes » : mon périmètre (promoteur, chef de secteur, directeur régional). */
  mes?: boolean;
  /** « Toutes » : lève la restriction du promoteur à ses propres commandes. */
  tous?: boolean;
}) {
  return list<CommandeRow>(
    `/commandes${qs({
      search: params.search,
      page: params.page,
      annulees: params.annulees ? 'true' : undefined,
      livraison: params.livraison,
      origine: params.origine,
      mes: params.mes ? '1' : undefined,
      tous: params.tous ? '1' : undefined,
      limit: 20,
    })}`,
  ) as Promise<CommandesResult>;
}

/**
 * Détail d'une commande (lignes incluses), ou null si introuvable (404) ou hors accès (403).
 * Session expirée (401) : redirection vers /login ; API en panne (5xx, réseau, délai) : lève
 * `ApiIndisponibleError` au lieu d'afficher une fausse page « introuvable ».
 */
export async function getCommande(id: string): Promise<CommandeDetail | null> {
  return lireDetail<CommandeDetail>(`/commandes/${idSur(id)}`);
}

export type Performances =
  | { noRepr: true }
  | {
      noRepr: false;
      periode: { annee: number; mois: number };
      idRepr: string;
      kpis: {
        ca: number;
        caN1: number;
        deltaPct: number | null;
        commandes: number;
        panierMoyen: number;
        visites: number;
      };
      objectif: { cible: number | null; tauxPct: number | null };
      couverture: {
        portefeuille: number;
        commandants: number;
        sansCommande: number;
        exemplesSansCommande: { id: string; nom: string; ville: string | null }[];
      };
      ca12mois: { anneeN: number; courbeN: number[]; courbeN1: number[] };
      topMagasins: { id: string; enseigne: string; ca: number; nb: number }[];
      rang: { position: number | null; total: number };
    };

/** Performances personnelles pour un mois donné, ou null en cas d'erreur. */
export async function getPerformances(annee?: number, mois?: number): Promise<Performances | null> {
  try {
    const res = await serverFetch(`/performances/me${qs({ annee, mois })}`);
    if (!res.ok) return null;
    return (await res.json()) as Performances;
  } catch {
    return null;
  }
}

export type ClientHistorique = {
  commandes: {
    id: string;
    numero: string;
    typeCmd: string | null;
    dateCommande: string | null;
    annulee: boolean;
    idRepr: string | null;
    viaMobile: boolean;
    nbLignes: number;
    total: number;
  }[];
  visites: {
    id: string;
    createdAt: string;
    dnAbc: number | null;
    dnConcurrence: number | null;
    pem: boolean;
    promoteur: { displayName: string };
    _count: { photos: number };
  }[];
  ca: { anneeN: number; courbeN: number[]; courbeN1: number[] };
};

/** Historique du magasin (commandes, visites, CA N/N-1), ou null en cas d'erreur. */
export async function getClientHistorique(id: string): Promise<ClientHistorique | null> {
  const sid = idSur(id);
  try {
    const res = await serverFetch(`/clients/${sid}/historique`);
    if (!res.ok) return null;
    return (await res.json()) as ClientHistorique;
  } catch {
    return null;
  }
}

/**
 * Fiche magasin complète, ou null si introuvable (404) ou hors accès (403).
 * Même contrat d'erreur que `getCommande` : 401 → /login, API en panne → `ApiIndisponibleError`.
 */
export async function getClient(id: string): Promise<ClientDetail | null> {
  return lireDetail<ClientDetail>(`/clients/${idSur(id)}`);
}

export type ArticleRow = {
  id: string;
  codeAs400: string;
  libelle: string;
  gencode: string | null;
  typeArticle: string | null;
  statut: string | null;
  pcb: number | null;
  stock: number;
  actif: boolean;
  marque: { nom: string } | null;
  gamme: { nom: string } | null;
  famille: { nom: string } | null;
};

/** Délai d'attente par défaut d'un appel à l'API (ms) : au-delà, elle est considérée indisponible. */
const DELAI_API_MS = 20_000;

/**
 * Appels dont le traitement est synchrone côté API et peut dépasser le délai par défaut
 * (synchro AD : lecture de l'annuaire et des photos). Sans cela, l'action serait annoncée en échec
 * alors que l'API la mène à terme. Clé = chemin exact (sans query string).
 */
const DELAIS_LONGS_MS: Record<string, number> = { '/sync/ad': 180_000 };

/** Échec de transport (et non réponse HTTP) : délai dépassé, annulation, connexion refusée ou coupée. */
function estPanneReseau(e: unknown): boolean {
  const nom = (e as { name?: unknown } | null)?.name;
  if (nom === 'TimeoutError' || nom === 'AbortError') return true;
  // undici lève « TypeError: fetch failed » (cause : ECONNREFUSED, ENOTFOUND, ECONNRESET…).
  return e instanceof TypeError && e.message === 'fetch failed';
}

/**
 * Appel serveur→serveur vers l'API NestJS, avec le JWT de session en Bearer.
 *
 * Délai d'attente : 20 s par défaut (`timeoutMs` pour le modifier, ou un `signal` fourni par l'appelant).
 * Une panne de transport (délai dépassé, connexion refusée) lève `ApiIndisponibleError` ; une réponse HTTP,
 * même en erreur, est toujours renvoyée telle quelle : c'est à l'appelant de vérifier `res.ok`.
 *
 * ATTENTION : Next ne mémoïse pas les `fetch` qui portent un `signal` (dedupe-fetch). Les appels répétés d'un
 * même rendu ne sont donc plus dédupliqués automatiquement ; `getMe` l'est par `cache()` de React.
 */
export async function serverFetch(
  path: string,
  init: RequestInit & { timeoutMs?: number } = {},
): Promise<Response> {
  const { timeoutMs, signal, ...reste } = init;
  const token = await getToken();
  const delai = timeoutMs ?? DELAIS_LONGS_MS[path.split('?')[0]] ?? DELAI_API_MS;
  try {
    return await fetch(`${apiBase()}${path}`, {
      ...reste,
      headers: {
        ...(init.headers ?? {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      signal: signal ?? AbortSignal.timeout(delai),
      cache: 'no-store',
    });
  } catch (e) {
    if (estPanneReseau(e)) throw new ApiIndisponibleError({ cause: e });
    throw e;
  }
}

/**
 * Lit le détail d'une ressource (page `[id]`) : l'objet, ou null si l'API répond « introuvable » (404) ou
 * « interdit » (403) — la page affiche alors un 404, sans révéler l'existence de la ressource.
 * 401 : session expirée → redirection vers /login. 5xx, 408, 429, réseau, délai : `ApiIndisponibleError`
 * (et non un faux 404). À appeler HORS d'un try/catch : `redirect` lève.
 */
async function lireDetail<T>(path: string): Promise<T | null> {
  const res = await serverFetch(path);
  if (res.ok) {
    try {
      return (await res.json()) as T;
    } catch (e) {
      throw new ApiIndisponibleError({ cause: e });
    }
  }
  if (res.status === 401) redirect('/login');
  if (res.status >= 500 || res.status === 408 || res.status === 429) throw new ApiIndisponibleError();
  return null;
}

/**
 * Ne garde de l'utilisateur renvoyé par `/auth/me` que les champs du type `Me`. L'API renvoie la ligne
 * Prisma complète (photo en octets, `isActive`, `secteurId`, `regionId`, `directeurId`, dates…) : sans cette
 * projection, tout ce contenu serait sérialisé dans le HTML et la charge RSC des composants clients.
 * Renvoie null si la réponse n'a ni identifiant ni rôle (session inexploitable).
 */
export function projeterMe(brut: unknown): Me | null {
  if (!brut || typeof brut !== 'object') return null;
  const u = brut as Record<string, unknown>;
  if (typeof u.id !== 'string' || typeof u.role !== 'string') return null;
  const texte = (v: unknown): string | null => (typeof v === 'string' ? v : null);
  return {
    id: u.id,
    username: texte(u.username) ?? '',
    displayName: texte(u.displayName) ?? '',
    email: texte(u.email),
    // Rôle gardé tel quel, même inconnu : requireRole le refuse (accès refusé) plutôt que de déconnecter.
    role: u.role as Role,
    idRepr: texte(u.idRepr),
    poste: texte(u.poste),
  };
}

/**
 * Utilisateur courant, ou null si la session est absente / expirée (pas de cookie, 401, 403).
 * API en panne (5xx, réseau, délai dépassé) : lève `ApiIndisponibleError`, pour ne pas faire passer une
 * indisponibilité pour une déconnexion (le cookie reste valable). Mémoïsé par requête (React `cache`) :
 * layout, gardes de rôle et page partagent un seul appel à `/auth/me`.
 *
 * @deprecated N'est plus appelée par l'application : `lireSession()` (roles.ts) est la seule voie de lecture de la
 * session (même projection par `projeterMe`, avec la distinction absente / indisponible sans exception).
 */
export const getMe = cache(async (): Promise<Me | null> => {
  // Pas de cookie : inutile de solliciter l'API (et pas d'erreur « indisponible » avant la connexion).
  if (!(await getToken())) return null;
  const res = await serverFetch('/auth/me');
  if (res.status === 401 || res.status === 403) return null;
  if (!res.ok) throw new ApiIndisponibleError();
  let json: unknown;
  try {
    json = await res.json();
  } catch (e) {
    throw new ApiIndisponibleError({ cause: e });
  }
  return projeterMe(json);
});

/** Construit une query string en ignorant les valeurs vides. */
export function qs(params: Record<string, string | number | undefined>): string {
  const sp = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== '') sp.set(k, String(v));
  }
  const s = sp.toString();
  return s ? `?${s}` : '';
}

async function list<T>(path: string): Promise<Paginated<T>> {
  const res = await serverFetch(path);
  if (!res.ok) throw new Error(`Erreur API ${res.status} sur ${path}`);
  return (await res.json()) as Paginated<T>;
}

export function listUsers(params: {
  search?: string;
  role?: string;
  secteurId?: string;
  statut?: string;
  page?: number;
  limit?: number;
}) {
  return list<UserRow>(`/users${qs({ ...params, limit: params.limit ?? 20 })}`);
}

export type ClientsResult = Paginated<ClientRow> & {
  scope: { type: 'mine' | 'global'; idRepr: string | null };
};

/**
 * Clients paginés. `avecAdresse` = uniquement les vrais points de vente (code postal renseigné,
 * exclut les pseudo-clients PLV) et tri par enseigne : usage ABC Sales (terrain).
 */
export function listClients(params: { search?: string; page?: number; avecAdresse?: boolean }) {
  const { avecAdresse, ...reste } = params;
  return list<ClientRow>(
    `/clients${qs({ ...reste, avecAdresse: avecAdresse ? 1 : undefined, limit: 20 })}`,
  ) as Promise<ClientsResult>;
}

export function listArticles(params: {
  search?: string;
  page?: number;
  rappel?: boolean;
  /** Produits en promotion en cours ou mis en avant (PEM). */
  promo?: boolean;
  marqueId?: string;
}) {
  return list<ArticleRow>(
    `/articles${qs({
      search: params.search,
      page: params.page,
      rappel: params.rappel ? 'true' : undefined,
      promo: params.promo ? 'true' : undefined,
      marqueId: params.marqueId,
      limit: 20,
    })}`,
  );
}

/** Marque du catalogue avec son nombre d'articles (sélecteur de la page Produits). */
export type MarqueRow = { id: string; nom: string; nbArticles: number };

/** Marques ayant au moins un article, par ordre alphabétique, ou null en cas d'erreur. */
export async function listMarques(): Promise<MarqueRow[] | null> {
  try {
    const res = await serverFetch('/articles/marques');
    if (!res.ok) return null;
    const data: unknown = await res.json();
    return Array.isArray(data) ? (data as MarqueRow[]) : null;
  } catch {
    return null;
  }
}

/** Compte les articles correspondant aux filtres (lit `total`, page allégée à 1 ligne). */
export async function countArticles(
  params: { actif?: boolean; rappel?: boolean; search?: string } = {},
): Promise<number | null> {
  try {
    const res = await serverFetch(
      `/articles${qs({
        search: params.search,
        actif: params.actif === undefined ? undefined : String(params.actif),
        rappel: params.rappel ? 'true' : undefined,
        page: 1,
        limit: 1,
      })}`,
    );
    if (!res.ok) return null;
    const data = (await res.json()) as { total?: number };
    return data.total ?? 0;
  } catch {
    return null;
  }
}

export type Dashboard = {
  scope: { type: 'global' | 'commercial'; idRepr: string | null; label: string };
  kpis: { ca: string; commandes: number; annulees: number; clients: number; panierMoyen: string };
  objectif: { cible: string | null; realise: string; tauxPct: number | null };
  commandesParPromoteur: {
    idRepr: string | null;
    promoteur: string;
    magasins: string[];
    totalMagasins: number;
  }[];
  commandesASuivre: {
    id: string;
    numero: string;
    magasin: string;
    statut: string;
    dateCommande: string | null;
    enRetard: boolean;
  }[];
  visites: { moisRealisees: number; objectif: number | null; tauxPct: number | null };
  tournee: { id: string; nom: string; ville: string | null; adresse: string | null; fait: boolean }[];
  alertes: { produitsRappel: { count: number; items: { code: string; libelle: string }[] } };
  topClients: { nom: string; ca: string; commandes: number }[];
};

export async function getDashboard(): Promise<Dashboard | null> {
  try {
    const res = await serverFetch('/dashboard/me');
    if (!res.ok) return null;
    return (await res.json()) as Dashboard;
  } catch {
    return null;
  }
}

// --- ABC Pilot (pilotage) --------------------------------------------------

export type ImportLog = {
  id: string;
  fileName: string;
  source: string;
  status: 'PENDING' | 'PROCESSING' | 'SUCCESS' | 'FAILED';
  rowsTotal: number;
  rowsOk: number;
  rowsFailed: number;
  fileSizeBytes?: number | null;
  errorMessage: string | null;
  startedAt: string | null;
  finishedAt: string | null;
  createdAt: string;
};

/** Journal des imports Minos (les plus récents en premier). */
export async function listImportLogs(): Promise<ImportLog[] | null> {
  try {
    const res = await serverFetch('/import/minos/logs');
    if (!res.ok) return null;
    return (await res.json()) as ImportLog[];
  } catch {
    return null;
  }
}

// --- Administration (ADMIN) ------------------------------------------------

export type AdminApercu = {
  sante: { api: 'up'; db: 'up' | 'down' };
  utilisateurs: { actifs: number; inactifs: number; parRole: Record<string, number> };
  organisation: {
    secteurs: number;
    secteursSansChef: number;
    commerciauxSansSecteur: number;
    commerciauxSansDirecteur: number;
    commerciauxSansCode: number;
  };
  imports: {
    dernier: {
      id: string;
      fileName: string;
      source: string;
      status: 'PENDING' | 'PROCESSING' | 'SUCCESS' | 'FAILED';
      rowsTotal: number;
      rowsFailed: number;
      date: string;
    } | null;
    enEchec7j: number;
  };
  /** Télémétrie des appareils mobiles : null tant que l'application ne la remonte pas. */
  mobile: null;
};

type PersonneRef = { id: string; displayName: string };
type ListeIncoherence = { total: number; items: PersonneRef[] };

export type AdminOrganisation = {
  regions: {
    id: string;
    code: string;
    nom: string;
    directeurs: { id: string; displayName: string; isActive: boolean }[];
    secteurs: {
      id: string;
      code: string;
      nom: string;
      manager: { id: string; displayName: string; isActive: boolean } | null;
      promoteurs: { id: string; displayName: string; isActive: boolean; idRepr: string | null }[];
    }[];
  }[];
  secteursSansRegion: { id: string; code: string; nom: string }[];
  incoherences: {
    promoteursSansSecteur: ListeIncoherence;
    promoteursSansDirecteur: ListeIncoherence;
    promoteursDirecteurInactif: ListeIncoherence;
    secteursSansChef: ListeIncoherence;
    chefsInactifs: ListeIncoherence;
    regionsSansDirecteur: ListeIncoherence;
    secteursSansRegion: ListeIncoherence;
  };
};

export async function getAdminApercu(): Promise<AdminApercu | null> {
  try {
    const res = await serverFetch('/admin/apercu');
    if (!res.ok) return null;
    return (await res.json()) as AdminApercu;
  } catch {
    return null;
  }
}

export async function getAdminOrganisation(): Promise<AdminOrganisation | null> {
  try {
    const res = await serverFetch('/admin/organisation');
    if (!res.ok) return null;
    return (await res.json()) as AdminOrganisation;
  } catch {
    return null;
  }
}

export type PlanningItem = {
  id: string;
  datePassage: string;
  fait: boolean;
  raison: string | null;
  plannificationId: string | null; // non nul = visite issue d'une récurrence
  client: { id: string; codeAs400: string; enseigne: string; ville: string | null; niveauClass: string | null };
};

export type RegleRecurrence = {
  id: string;
  jours: string; // CSV ISO "1,4" (1=lundi … 6=samedi)
  recurrence: number; // en semaines
  dateDebut: string;
  dateFin: string | null;
  client: { id: string; enseigne: string; ville: string | null; niveauClass: string | null };
};

/** Règles de récurrence actives d'un promoteur. */
export async function listRegles(promoteurId: string): Promise<RegleRecurrence[] | null> {
  try {
    const res = await serverFetch(`/plannifications${qs({ promoteurId })}`);
    if (!res.ok) return null;
    return (await res.json()) as RegleRecurrence[];
  } catch {
    return null;
  }
}

/** Visites planifiées d'un promoteur sur [debut, fin) (dates ISO yyyy-mm-dd). */
export async function listPlannings(
  promoteurId: string,
  debut: string,
  fin: string,
): Promise<PlanningItem[] | null> {
  try {
    const res = await serverFetch(`/plannings${qs({ promoteurId, debut, fin })}`);
    if (!res.ok) return null;
    return (await res.json()) as PlanningItem[];
  } catch {
    return null;
  }
}

export type SecteurRow = {
  id: string;
  code: string;
  nom: string;
  manager: { id: string; displayName: string; role: string } | null;
  _count: { membres: number; clients: number };
};

/** Liste des secteurs (chef, membres, clients). */
export async function listSecteurs(): Promise<SecteurRow[] | null> {
  try {
    const res = await serverFetch('/secteurs');
    if (!res.ok) return null;
    return (await res.json()) as SecteurRow[];
  } catch {
    return null;
  }
}

export type DashboardDirection = {
  periode: { annee: number; mois: number };
  scope: { type: 'global' | 'secteur'; label: string };
  kpis: {
    ca: number;
    caN1: number;
    deltaPct: number | null;
    commandes: number;
    panierMoyen: number;
    magasinsCommandants: number;
    magasinsTotal: number;
  };
  ca12mois: { anneeN: number; courbeN: number[]; courbeN1: number[] };
  classement: {
    userId: string | null;
    nom: string;
    idRepr: string;
    isActive: boolean;
    secteur: { id: string; code: string; nom: string } | null;
    ca: number;
    commandes: number;
    caN1: number;
    deltaPct: number | null;
    objectif: number | null;
    tauxPct: number | null;
  }[];
  caParSecteur: {
    id: string | null;
    code: string;
    nom: string;
    chef: string | null;
    promoteurs: number;
    ca: number;
    caN1: number;
    objectif: number;
    deltaPct: number | null;
    tauxPct: number | null;
  }[];
  objectifs: { definis: number; atteints: number; manques: number; sansObjectif: number };
  /** CA du mois par famille d'articles : top 5 + « Autres », part en %. */
  caParFamille: { total: number; familles: { nom: string; ca: number; pct: number }[] };
  prospection: {
    /** Semaines du mois (S1..S4), valeurs cumulées ; `ca` null = semaine pas encore commencée. */
    semaines: { label: string; ca: number | null; objectif: number | null }[];
    ouverts: number;
    pipelinePondere: number;
    gagnes: number;
    potentielGagne: number;
    caRealiseMois: number;
    tauxPct: number | null;
  };
  scatterMagasins: {
    id: string;
    nom: string;
    ville: string | null;
    niveauClass: string | null;
    objectifMensuel: number;
    caMois: number;
  }[];
  sansCommande: {
    total: number;
    exemples: { id: string; nom: string; ville: string | null; niveauClass: string | null }[];
  };
};

/** Dashboard de pilotage direction pour un mois donné, ou null en cas d'erreur. */
export async function getDashboardDirection(
  annee?: number,
  mois?: number,
): Promise<DashboardDirection | null> {
  try {
    const res = await serverFetch(`/dashboard/direction${qs({ annee, mois })}`);
    if (!res.ok) return null;
    return (await res.json()) as DashboardDirection;
  } catch {
    return null;
  }
}

/** Indicateurs de la page Commandes : la journée en cours ou le mois en cours (périmètre de l'appelant, côté API). */
export type StatsCommandes = {
  periode: 'jour' | 'mois';
  ca: number;
  caN1: number;
  deltaPct: number | null;
  commandes: number;
  panierMoyen: number;
  clientsCommandants: number;
  clientsTotal: number;
};

/** Indicateurs du jour (défaut) ou du mois pour la page Commandes, ou null en cas d'erreur. */
export async function getStatsCommandes(periode: 'jour' | 'mois'): Promise<StatsCommandes | null> {
  try {
    const res = await serverFetch(`/dashboard/commandes${qs({ periode })}`);
    if (!res.ok) return null;
    return (await res.json()) as StatsCommandes;
  } catch {
    return null;
  }
}

export type PromoArticle = {
  id: string;
  codeAs400: string;
  libelle: string;
  gencode: string | null;
  marque: { nom: string } | null;
};

export type PromoRow = {
  id: string;
  libelle: string | null;
  dateDebut: string | null;
  dateFin: string | null;
  actif: boolean;
  createdAt: string;
  article: PromoArticle;
};

export type PemRow = {
  id: string;
  actif: boolean;
  createdAt: string;
  article: PromoArticle;
};

/** Liste des promos (toutes), les actives d'abord. */
export async function listPromos(): Promise<PromoRow[] | null> {
  try {
    const res = await serverFetch('/promos');
    if (!res.ok) return null;
    return (await res.json()) as PromoRow[];
  } catch {
    return null;
  }
}

/**
 * Moyens de promotion (PEM). Par défaut tous (édition ABC Pilot) ;
 * `actifsSeulement` = uniquement les actifs (consultation ABC Sales).
 */
export async function listPem(options: { actifsSeulement?: boolean } = {}): Promise<PemRow[] | null> {
  try {
    const res = await serverFetch('/promos/pem');
    if (!res.ok) return null;
    const lignes = (await res.json()) as PemRow[];
    return options.actifsSeulement ? lignes.filter((m) => m.actif) : lignes;
  } catch {
    return null;
  }
}

// --- Prospection (pilotage) ---------------------------------------------
// Contrat aligné sur les DTOs Swagger de l'API. Les réponses n'étant pas
// typées côté API, la forme des lignes renvoyées suit ses conventions
// habituelles (pagination + relations) et reste tolérante aux valeurs nulles.

export type ProspectStatut =
  | 'NOUVEAU' // création de la fiche
  | 'CONTACTE' // prise de contact
  | 'PROPOSITION'
  | 'VISITE'
  | 'NEGOCIATION'
  | 'GAGNE'
  | 'PERDU';
export type ProspectSource = 'SALON' | 'RECOMMANDATION' | 'TERRAIN' | 'WEB';
export type MotifPerte = 'PRIX' | 'CONCURRENCE' | 'PAS_DE_BESOIN' | 'SANS_REPONSE' | 'AUTRE';
export type OpportuniteType = 'REFERENCEMENT' | 'OP' | 'MISE_EN_AVANT';
export type OpportuniteStatut = 'OUVERTE' | 'GAGNEE' | 'PERDUE' | 'ANNULEE';

export const PROSPECT_STATUTS: ProspectStatut[] = [
  'NOUVEAU',
  'CONTACTE',
  'PROPOSITION',
  'VISITE',
  'NEGOCIATION',
  'GAGNE',
  'PERDU',
];

export type ProspectRow = {
  id: string;
  raisonSociale: string;
  enseigne: string;
  ville: string | null;
  codePostal: string | null;
  statut: ProspectStatut;
  probabilite: number | null;
  potentielCaAnnuel: number | null;
  source: ProspectSource | null;
  niveauClass: string | null; // classe estimée du magasin (A à G)
  latitude: number | null;
  longitude: number | null;
  secteur: { id: string; code: string; nom: string } | null;
  assignedTo: { id: string; displayName: string } | null;
  clientId: string | null;
  createdAt: string;
  lastActivityAt: string | null;
};

export type ProspectsResult = Paginated<ProspectRow> & {
  scope?: { type: string; label?: string };
};

/** Liste paginée des prospects (scopée par rôle côté API). */
export function listProspects(params: {
  search?: string;
  page?: number;
  statut?: string;
  secteur?: string;
  assignedTo?: string;
}) {
  return list<ProspectRow>(
    `/prospects${qs({ ...params, limit: 20 })}`,
  ) as Promise<ProspectsResult>;
}

/** Visite d'un promoteur chez un client (ligne de la liste `/visites`). */
export type VisiteActivite = {
  id: string;
  createdAt: string;
  promoteur: { id: string; displayName: string } | null;
  client: { id: string; enseigne: string; ville: string | null } | null;
};

export type PipelineColonne = {
  statut: ProspectStatut;
  total: number;
  valeurPonderee: number;
  prospects: ProspectRow[];
};

const estStatutProspect = (v: unknown): v is ProspectStatut =>
  typeof v === 'string' && (PROSPECT_STATUTS as string[]).includes(v);

/** Colonne normalisée : les champs absents ou mal typés prennent leur valeur neutre. */
function colonnePipeline(statut: ProspectStatut, c: Partial<PipelineColonne> | null | undefined): PipelineColonne {
  const prospects = Array.isArray(c?.prospects) ? c.prospects : [];
  return {
    statut,
    total: typeof c?.total === 'number' ? c.total : prospects.length,
    valeurPonderee: typeof c?.valeurPonderee === 'number' ? c.valeurPonderee : 0,
    prospects,
  };
}

/**
 * Normalise la réponse de GET /prospects/pipeline vers les 7 colonnes du Kanban, dans l'ordre des étapes.
 *
 * Forme réelle de l'API : `{ etapes: [{ statut, total, valeurPonderee, prospects }], scope: { type } }`.
 * Tolère aussi un tableau de colonnes, `{ colonnes: [...] }` et une map `{ STATUT: {...} }`. Seules les
 * clés qui sont des étapes connues comptent : `scope` (ou toute autre clé) n'est jamais prise pour une colonne.
 * Une étape absente donne une colonne vide.
 */
export function normaliserPipeline(json: unknown): PipelineColonne[] {
  let brut: unknown = json;
  if (json && typeof json === 'object' && !Array.isArray(json)) {
    const { etapes, colonnes } = json as { etapes?: unknown; colonnes?: unknown };
    brut = etapes ?? colonnes ?? json;
  }

  const parStatut = new Map<ProspectStatut, PipelineColonne>();
  if (Array.isArray(brut)) {
    for (const c of brut as (Partial<PipelineColonne> | null)[]) {
      if (estStatutProspect(c?.statut)) parStatut.set(c.statut, colonnePipeline(c.statut, c));
    }
  } else if (brut && typeof brut === 'object') {
    const map = brut as Record<string, Partial<PipelineColonne> | null | undefined>;
    for (const statut of PROSPECT_STATUTS) {
      if (map[statut]) parStatut.set(statut, colonnePipeline(statut, map[statut]));
    }
  }
  return PROSPECT_STATUTS.map((statut) => parStatut.get(statut) ?? colonnePipeline(statut, null));
}

/** Pipeline groupé par étape (Kanban), ou null en cas d'erreur. Voir `normaliserPipeline` pour la forme. */
export async function getProspectPipeline(): Promise<PipelineColonne[] | null> {
  try {
    const res = await serverFetch('/prospects/pipeline');
    if (!res.ok) return null;
    return normaliserPipeline(await res.json());
  } catch {
    return null;
  }
}

export type OpportuniteRow = {
  id: string;
  type: OpportuniteType;
  statut: OpportuniteStatut;
  libelle: string | null;
  valeurEstimee: number | null;
  dateDebut: string | null;
  dateFin: string | null;
  articles?: { id: string; codeAs400: string; libelle: string }[];
  prospectId?: string | null;
  clientId?: string | null;
};

// La forme exacte du détail n'étant pas typée côté API, tout est optionnel/nullable
// hormis l'identité de base — les écrans dégradent proprement si un champ manque.
export type ProspectDetail = {
  id: string;
  raisonSociale: string;
  enseigne: string;
  adresse1: string | null;
  codePostal: string | null;
  ville: string | null;
  telephone: string | null;
  email: string | null;
  statut: ProspectStatut;
  probabilite: number | null;
  potentielCaAnnuel: number | null;
  source: ProspectSource | null;
  motifPerte: MotifPerte | null;
  niveauClass: string | null;
  secteur: { id: string; code: string; nom: string } | null;
  assignedTo: { id: string; displayName: string } | null;
  clientId: string | null;
  createdAt: string;
  updatedAt: string | null;
  lastActivityAt: string | null;
  contacts?: { id: string; prenom: string | null; nom: string; fixe: string | null; portable: string | null; mail: string | null }[];
  notes?: { id: string; remarque: string; createdAt: string; auteur: { displayName: string } | null }[];
  opportunites?: OpportuniteRow[];
};

/**
 * Fiche prospect complète, ou null si introuvable (404 : l'API renvoie aussi 404 hors périmètre) ou hors accès (403).
 * Même contrat d'erreur que `getCommande` : 401 → /login, API en panne → `ApiIndisponibleError`.
 */
export async function getProspect(id: string): Promise<ProspectDetail | null> {
  return lireDetail<ProspectDetail>(`/prospects/${idSur(id)}`);
}

// --- Zone de dépôt AS400 ----------------------------------------------------

export type FichierDepot = { nom: string; chemin: string; taille: number; modifieLe: string };

/** Fichiers présents dans la zone de dépôt AS400 (montage sur le serveur API). */
export async function listFichiersDepot(): Promise<{ racine: string; fichiers: FichierDepot[] } | null> {
  try {
    const res = await serverFetch('/import/minos/fichiers');
    if (!res.ok) return null;
    return (await res.json()) as { racine: string; fichiers: FichierDepot[] };
  } catch {
    return null;
  }
}

// --- Gestion des magasins secteur ------------------------------------------

/** Magasin enrichi (suivi secteur) — champs calculés par l'API (`enrich=1`). */
export type MagasinSuiviRow = ClientRow & {
  codePostal: string | null;
  tel1: string | null;
  email: string | null;
  cs: { id: string; displayName: string; idRepr: string | null } | null;
  caMois: number;
  deltaPct: number | null;
  derniereVisiteJours: number | null;
  periodicite: string | null;
  enRetard: boolean;
  enBaisse: boolean;
  alertes: number;
  etat: 'ok' | 'attention' | 'alerte';
};

export type MagasinGeoPoint = {
  id: string;
  enseigne: string;
  raisonSociale: string;
  ville: string | null;
  codePostal: string | null;
  niveauClass: string | null;
  latitude: number | null;
  longitude: number | null;
};

/** Tous les points de vente géolocalisables (liste légère, pour la carte). */
export async function listMagasinsGeo(): Promise<MagasinGeoPoint[] | null> {
  try {
    const res = await serverFetch('/clients/geo');
    if (!res.ok) return null;
    return (await res.json()) as MagasinGeoPoint[];
  } catch {
    return null;
  }
}

/** Magasins enrichis, paginés (50/page) — pour le tableau de la gestion des magasins secteur. */
export async function listMagasinsSuivi(params: {
  search?: string;
  page?: number;
}): Promise<Paginated<MagasinSuiviRow> | null> {
  try {
    const res = await serverFetch(
      `/clients${qs({ enrich: 1, avecAdresse: 1, limit: 50, search: params.search, page: params.page ?? 1 })}`,
    );
    if (!res.ok) return null;
    return (await res.json()) as Paginated<MagasinSuiviRow>;
  } catch {
    return null;
  }
}

export type PlanningMagasin = {
  id: string;
  datePassage: string;
  promoteur: { id: string; displayName: string } | null;
};

/** Visites planifiées à venir d'un magasin. */
export async function listPlanningsMagasin(clientId: string): Promise<PlanningMagasin[]> {
  const sid = idSur(clientId);
  try {
    const res = await serverFetch(`/plannings/client/${sid}`);
    if (!res.ok) return [];
    return (await res.json()) as PlanningMagasin[];
  } catch {
    return [];
  }
}

// --- Mon planning (tournée personnelle de l'encadrement) ---------------------

export type TourneeEtapeRow = {
  id: string;
  adm: boolean;
  /** Client ou lieu saisi en texte libre (rapport d'activité), à la place d'un magasin ou d'un prospect de la liste. */
  libelle: string | null;
  adresse: string | null;
  datePassage: string;
  fait: boolean;
  note: string | null;
  visiteSimple: boolean;
  accompagnement: boolean;
  rdv: boolean;
  soireeEtape: boolean;
  soireeLieu: string | null;
  soireeAdresse: string | null;
  client: { id: string; codeAs400: string; enseigne: string; ville: string | null; niveauClass: string | null } | null;
  prospect: { id: string; enseigne: string; ville: string | null; statut: ProspectStatut; niveauClass: string | null } | null;
};

/** Planning d'activité d'un membre de mon équipe (lecture seule). */
export async function listPlanningMembre(
  userId: string,
  debut: string,
  fin: string,
): Promise<{ user: { id: string; displayName: string; poste: string | null }; etapes: TourneeEtapeRow[] } | null> {
  const sid = idSur(userId);
  try {
    const res = await serverFetch(`/tournees/user/${sid}${qs({ debut, fin })}`);
    if (!res.ok) return null;
    return (await res.json()) as { user: { id: string; displayName: string; poste: string | null }; etapes: TourneeEtapeRow[] };
  } catch {
    return null;
  }
}

/** Mes étapes de tournée sur [debut, fin) — prospects et magasins mêlés. */
export async function listMaTournee(debut: string, fin: string): Promise<TourneeEtapeRow[] | null> {
  try {
    const res = await serverFetch(`/tournees/me${qs({ debut, fin })}`);
    if (!res.ok) return null;
    return (await res.json()) as TourneeEtapeRow[];
  } catch {
    return null;
  }
}

/** Phase d'une semaine : prévision jusqu'au lundi soir, puis rapport (tournée réalisée) dès le mardi. */
export type PhaseSemaine = 'PREVISION' | 'RAPPORT';

export type StatutRapport = 'PREVISION_A_SAISIR' | 'PREVISION_ENREGISTREE' | 'EN_COURS' | 'VALIDE' | 'VALIDE_AUTO';

/**
 * État de MA semaine. Trois notions distinctes : tournée prévue (photographie, figée dès le mardi), tournée réalisée
 * (les étapes, modifiables pendant la phase rapport), rapport validé (la réalisée verrouillée à la clôture).
 */
export type SemaineEtat = {
  semaine: string;
  phase: PhaseSemaine;
  prevuAt: string | null;
  valideAt: string | null;
  valideAuto: boolean;
  nbEtapesPrevues: number | null;
  previsionNonRenseignee: boolean;
  previsionModifiable: boolean;
  peutValider: boolean;
  verrouillee: boolean;
  statut: StatutRapport;
};

/** État prévision / rapport / validation de MA semaine (lundi ISO). */
export async function getSemaineEtat(semaine: string): Promise<SemaineEtat | null> {
  try {
    const res = await serverFetch(`/tournees/semaine${qs({ semaine })}`);
    if (!res.ok) return null;
    return (await res.json()) as SemaineEtat;
  } catch {
    return null;
  }
}

/** Une ligne d'un rapport (prévue ou réalisée), vue de façon uniforme. */
export type LigneRapport = {
  id?: string;
  jour: string;
  heure: string | null;
  adm: boolean;
  titre: string;
  ville: string | null;
  adresse: string | null;
  libelle: string | null;
  visiteSimple: boolean;
  accompagnement: boolean;
  rdv: boolean;
  soireeEtape: boolean;
  soireeLieu: string | null;
  soireeAdresse: string | null;
  note: string | null;
  fait: boolean;
};

/** Tournée PRÉVUE de MA semaine (photographie enregistrée) ; null si la prévision n'a pas été renseignée. */
export async function getMaPrevue(semaine: string): Promise<LigneRapport[] | null> {
  try {
    const res = await serverFetch(`/tournees/semaine/prevue${qs({ semaine })}`);
    if (!res.ok) return null;
    return ((await res.json()) as { prevue: LigneRapport[] | null }).prevue;
  } catch {
    return null;
  }
}

export type RapportAuteur = {
  userId: string;
  nom: string;
  role: Role;
  region: string | null;
  secteur: string | null;
  statut: StatutRapport;
  prevuAt: string | null;
  previsionNonRenseignee: boolean;
  valideAt: string | null;
  valideAuto: boolean;
  nbPrevues: number | null;
  nbRealisees: number;
  nbFaites: number;
};

export type RapportsListe = { semaine: string; phase: PhaseSemaine; auteurs: RapportAuteur[] };

/** Rapports de la semaine dans mon périmètre (directeurs régionaux, direction, administrateurs). */
export async function listRapports(semaine: string): Promise<RapportsListe | null> {
  try {
    const res = await serverFetch(`/rapports${qs({ semaine })}`);
    if (!res.ok) return null;
    return (await res.json()) as RapportsListe;
  } catch {
    return null;
  }
}

export type RapportDetail = {
  auteur: { id: string; displayName: string; role: Role };
  etat: SemaineEtat;
  prevue: LigneRapport[] | null;
  realisee: LigneRapport[];
};

export async function getRapportDetail(userId: string, semaine: string): Promise<RapportDetail | null> {
  const sid = idSur(userId);
  try {
    const res = await serverFetch(`/rapports/${sid}${qs({ semaine })}`);
    if (!res.ok) return null;
    return (await res.json()) as RapportDetail;
  } catch {
    return null;
  }
}

export type ResultatAppel = 'REPONDU' | 'SANS_REPONSE' | 'MESSAGERIE' | 'RAPPEL_PREVU';

/** Événement de la timeline d'un prospect : appel (mobile), visite de prospection ou opportunité. */
export type ProspectEvenement =
  | {
      type: 'VISITE';
      date: string;
      visite: {
        id: string;
        createdAt: string;
        motif: string | null;
        pmcCommentaire: string | null;
        promoteur: { id: string; displayName: string } | null;
      };
    }
  | {
      type: 'APPEL';
      date: string;
      appel: {
        id: string;
        dateAppel: string;
        dureeSec: number | null;
        resultat: ResultatAppel;
        commentaire: string | null;
        auteur: { id: string; displayName: string } | null;
      };
    }
  | {
      type: 'EMAIL';
      date: string;
      email: {
        id: string;
        dateEmail: string;
        destinataire: string | null;
        sujet: string | null;
        commentaire: string | null;
        auteur: { id: string; displayName: string } | null;
      };
    }
  | {
      type: 'ETAPE';
      date: string;
      etape: {
        id: string;
        createdAt: string;
        de: ProspectStatut | null;
        vers: ProspectStatut;
        commentaire: string | null;
        auteur: { id: string; displayName: string } | null;
      };
    }
  | {
      type: 'NOTE';
      date: string;
      note: {
        id: string;
        createdAt: string;
        remarque: string;
        auteur: { id: string; displayName: string } | null;
      };
    }
  | { type: 'OPPORTUNITE'; date: string; opportunite: OpportuniteRow };

/** Timeline du prospect (appels + visites de prospection + opportunités), du plus récent au plus ancien. */
export async function getProspectTimeline(id: string): Promise<ProspectEvenement[] | null> {
  const sid = idSur(id);
  try {
    const res = await serverFetch(`/prospects/${sid}/historique`);
    if (!res.ok) return null;
    const json = (await res.json()) as { data?: ProspectEvenement[] };
    return json.data ?? [];
  } catch {
    return null;
  }
}

// ─── Exports propres à ABC Sales (repris de crm-promoteur) ───

/** Magasin enrichi (liste portefeuille) — champs calculés par l'API (enrich=1). */
export type ClientEnrichedRow = ClientRow & {
  codePostal: string | null;
  cs: { id: string; displayName: string; idRepr: string | null } | null;
  caMois: number;
  deltaPct: number | null;
  derniereVisiteJours: number | null;
  periodicite: string | null;
  enRetard: boolean;
  enBaisse: boolean;
  alertes: number;
  etat: 'ok' | 'attention' | 'alerte';
};

export type StatutLivraison = 'EN_PREPARATION' | 'EXPEDIEE' | 'LIVREE_PARTIELLE' | 'LIVREE';

/** CA et nombre de commandes des 6 derniers mois (périmètre côté API). */
export type EvolutionCa = {
  mois: { annee: number; mois: number; label: string; ca: number; commandes: number }[];
};

/** Visites du mois par région (périmètre selon le rôle, côté API). */
export type VisitesRegions = {
  total: number;
  nonLocalisees: number;
  regions: { code: string; nom: string; ville: string; lat: number; lng: number; visites: number }[];
};

export async function getEvolutionCa(annee?: number, mois?: number): Promise<EvolutionCa | null> {
  try {
    const res = await serverFetch(`/dashboard/evolution${qs({ annee, mois })}`);
    if (!res.ok) return null;
    return (await res.json()) as EvolutionCa;
  } catch {
    return null;
  }
}

export async function getVisitesRegions(annee?: number, mois?: number): Promise<VisitesRegions | null> {
  try {
    const res = await serverFetch(`/dashboard/visites-regions${qs({ annee, mois })}`);
    if (!res.ok) return null;
    return (await res.json()) as VisitesRegions;
  } catch {
    return null;
  }
}

/** Promos EN COURS (dates + actif) à pousser en visite. */
export async function listPromosActives(): Promise<PromoRow[] | null> {
  try {
    const res = await serverFetch('/promos?actives=1');
    if (!res.ok) return null;
    return (await res.json()) as PromoRow[];
  } catch {
    return null;
  }
}

export type ClientsEnrichedResult = Paginated<ClientEnrichedRow> & {
  scope: { type: 'mine' | 'global'; idRepr: string | null };
};

/** Portefeuille enrichi (CA, Δ, dernière visite, alertes, état) pour la table magasins. */
export function listClientsEnriched(params: { search?: string; page?: number; tous?: string; actif?: 'true' | 'false' }) {
  return list<ClientEnrichedRow>(
    `/clients${qs({ ...params, enrich: 1, avecAdresse: 1, limit: 50 })}`,
  ) as Promise<ClientsEnrichedResult>;
}

export type VisiteRow = {
  id: string;
  createdAt: string;
  motif: string | null;
  dnAbc: number | null;
  dnConcurrence: number | null;
  dnGondoleHaute: number | null;
  dnGondoleBasse: number | null;
  pem: boolean;
  pmcCommentaire: string | null;
  client: { id: string; codeAs400: string; enseigne: string; ville: string | null; niveauClass: string | null } | null;
  promoteur: { id: string; displayName: string; idRepr: string | null } | null;
  _count: { photos: number };
};

export type VisitesResult = Paginated<VisiteRow> & { scope?: { type: 'mine' | 'global' } };

/** Visites paginées — les siennes pour un commercial, toutes pour les rôles siège. */
export async function listVisites(params: {
  search?: string;
  page?: number;
  /** « Toutes » : lève la restriction du promoteur (ses visites) et du CS / DR (leur équipe). */
  tous?: boolean;
}): Promise<VisitesResult> {
  return (await list<VisiteRow>(`/visites${qs({ search: params.search, page: params.page, tous: params.tous ? '1' : undefined })}`)) as VisitesResult;
}

export type NotificationItem = {
  id: string;
  type: string;
  titre: string;
  message: string;
  lien: string | null;
  luAt: string | null;
  createdAt: string;
  emetteur: { displayName: string } | null;
};

/** Boîte de réception : 20 dernières notifications + compteur non lues. */
export async function getNotifications(): Promise<{ nonLues: number; items: NotificationItem[] } | null> {
  try {
    const res = await serverFetch('/notifications/me');
    if (!res.ok) return null;
    return (await res.json()) as { nonLues: number; items: NotificationItem[] };
  } catch {
    return null;
  }
}

/** Mes visites planifiées sur [debut, fin) (dates ISO yyyy-mm-dd) — lecture seule. */
export async function listMesPlannings(
  promoteurId: string,
  debut: string,
  fin: string,
): Promise<PlanningItem[] | null> {
  try {
    const res = await serverFetch(`/plannings${qs({ promoteurId, debut, fin })}`);
    if (!res.ok) return null;
    return (await res.json()) as PlanningItem[];
  } catch {
    return null;
  }
}

export type PeriodiciteRef = { id: string; code: number | null; libelle: string };

/** Nomenclature des périodicités de visite. */
export async function listPeriodicites(): Promise<PeriodiciteRef[]> {
  try {
    const res = await serverFetch('/periodicites');
    if (!res.ok) return [];
    return (await res.json()) as PeriodiciteRef[];
  } catch {
    return [];
  }
}
