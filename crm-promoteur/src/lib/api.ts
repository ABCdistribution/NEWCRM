import { apiBase, getToken } from './session';

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
  secteur: { id: string; code: string; nom: string } | null;
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
  _count: { visites: number; commandes: number };
};

export type StatutLivraison = 'EN_PREPARATION' | 'EXPEDIEE' | 'LIVREE_PARTIELLE' | 'LIVREE';

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
}) {
  return list<CommandeRow>(
    `/commandes${qs({
      search: params.search,
      page: params.page,
      annulees: params.annulees ? 'true' : undefined,
      livraison: params.livraison,
      limit: 20,
    })}`,
  ) as Promise<CommandesResult>;
}

/** Détail d'une commande (lignes incluses), ou null si introuvable. */
export async function getCommande(id: string): Promise<CommandeDetail | null> {
  try {
    const res = await serverFetch(`/commandes/${id}`);
    if (!res.ok) return null;
    return (await res.json()) as CommandeDetail;
  } catch {
    return null;
  }
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
  try {
    const res = await serverFetch(`/clients/${id}/historique`);
    if (!res.ok) return null;
    return (await res.json()) as ClientHistorique;
  } catch {
    return null;
  }
}

/** Fiche magasin complète, ou null si introuvable. */
export async function getClient(id: string): Promise<ClientDetail | null> {
  try {
    const res = await serverFetch(`/clients/${id}`);
    if (!res.ok) return null;
    return (await res.json()) as ClientDetail;
  } catch {
    return null;
  }
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

/** Articles mis en avant (PEM). */
export async function listPem(): Promise<PemRow[] | null> {
  try {
    const res = await serverFetch('/promos/pem');
    if (!res.ok) return null;
    return ((await res.json()) as PemRow[]).filter((m) => m.actif);
  } catch {
    return null;
  }
}

/** Appel serveur→serveur vers l'API NestJS, avec le JWT de session en Bearer. */
export async function serverFetch(path: string, init: RequestInit = {}): Promise<Response> {
  const token = await getToken();
  return fetch(`${apiBase()}${path}`, {
    ...init,
    headers: {
      ...(init.headers ?? {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    cache: 'no-store',
  });
}

/** Utilisateur courant, ou null si la session est absente / expirée. */
export async function getMe(): Promise<Me | null> {
  try {
    const res = await serverFetch('/auth/me');
    if (!res.ok) return null;
    return (await res.json()) as Me;
  } catch {
    return null;
  }
}

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

export function listUsers(params: { search?: string; role?: string; page?: number }) {
  return list<UserRow>(`/users${qs({ ...params, limit: 20 })}`);
}

export type ClientsResult = Paginated<ClientRow> & {
  scope: { type: 'mine' | 'global'; idRepr: string | null };
};

export function listClients(params: { search?: string; page?: number }) {
  return list<ClientRow>(`/clients${qs({ ...params, avecAdresse: 1, limit: 20 })}`) as Promise<ClientsResult>;
}

export type ClientsEnrichedResult = Paginated<ClientEnrichedRow> & {
  scope: { type: 'mine' | 'global'; idRepr: string | null };
};

/** Portefeuille enrichi (CA, Δ, dernière visite, alertes, état) pour la table magasins. */
export function listClientsEnriched(params: { search?: string; page?: number; tous?: string }) {
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
export async function listVisites(params: { search?: string; page?: number }): Promise<VisitesResult> {
  return (await list<VisiteRow>(`/visites${qs({ ...params })}`)) as VisitesResult;
}

export function listArticles(params: { search?: string; page?: number; rappel?: boolean }) {
  return list<ArticleRow>(
    `/articles${qs({
      search: params.search,
      page: params.page,
      rappel: params.rappel ? 'true' : undefined,
      limit: 20,
    })}`,
  );
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

export type PlanningItem = {
  id: string;
  datePassage: string;
  fait: boolean;
  raison: string | null;
  plannificationId: string | null; // non nul = visite issue d'une récurrence
  client: { id: string; codeAs400: string; enseigne: string; ville: string | null; niveauClass: string | null };
};

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

// --- Planification des tournées (encadrement) ------------------------------

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

/** Portefeuille de magasins d'un code représentant (pour le sélecteur de planification). */
export async function listClientsOfRepr(repr: string): Promise<ClientRow[]> {
  try {
    const res = await serverFetch(`/clients${qs({ repr, limit: 100 })}`);
    if (!res.ok) return [];
    const data = (await res.json()) as Paginated<ClientRow>;
    return data.data;
  } catch {
    return [];
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
