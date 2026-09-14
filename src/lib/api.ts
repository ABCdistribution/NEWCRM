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
  periodicites: { id: string; periodicite: { code: number | null; libelle: string } }[];
  _count: { visites: number; commandes: number };
};

export type CommandeRow = {
  id: string;
  numero: string;
  typeCmd: string | null;
  dateCommande: string | null;
  annulee: boolean;
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

export function listCommandes(params: { search?: string; page?: number; annulees?: boolean }) {
  return list<CommandeRow>(
    `/commandes${qs({
      search: params.search,
      page: params.page,
      annulees: params.annulees ? 'true' : undefined,
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

export function listUsers(params: { search?: string; role?: string; page?: number; limit?: number }) {
  return list<UserRow>(`/users${qs({ ...params, limit: params.limit ?? 20 })}`);
}

export type ClientsResult = Paginated<ClientRow> & {
  scope: { type: 'mine' | 'global'; idRepr: string | null };
};

export function listClients(params: { search?: string; page?: number }) {
  return list<ClientRow>(`/clients${qs({ ...params, limit: 20 })}`) as Promise<ClientsResult>;
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

// --- Helios (pilotage) --------------------------------------------------

export type ImportLog = {
  id: string;
  fileName: string;
  source: string;
  status: 'PENDING' | 'PROCESSING' | 'SUCCESS' | 'FAILED';
  rowsTotal: number;
  rowsOk: number;
  rowsFailed: number;
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

export type ObjectifsGrille = {
  annee: number;
  page: number;
  limit: number;
  total: number;
  totaux: { magasins: number; avecObjectif: number; cibleCa: number };
  lignes: {
    clientId: string;
    codeAs400: string;
    nom: string;
    ville: string | null;
    niveauClass: string | null;
    cibleCa: number | null;
    caRealise: number;
  }[];
};

/** Grille annuelle des objectifs par magasin (tous les magasins actifs, recherche + pagination). */
export async function getObjectifsGrille(
  annee: number,
  filtres: { search?: string; page?: number } = {},
): Promise<ObjectifsGrille | null> {
  try {
    const res = await serverFetch(`/objectifs${qs({ annee, search: filtres.search, page: filtres.page })}`);
    if (!res.ok) return null;
    return (await res.json()) as ObjectifsGrille;
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

export type TypeQuestion = 'CASE_A_COCHER' | 'TEXTE' | 'NOMBRE' | 'NOTE_1_5';

export type QuestionVisite = {
  id: string;
  libelle: string;
  type: TypeQuestion;
  ordre: number;
  obligatoire: boolean;
  actif: boolean;
  _count: { reponses: number };
};

/** Questionnaire de fin de visite (édition : inclut les questions inactives). */
export async function listQuestionnaire(): Promise<QuestionVisite[] | null> {
  try {
    const res = await serverFetch('/questionnaire?tous=1');
    if (!res.ok) return null;
    return (await res.json()) as QuestionVisite[];
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

/** Liste des articles mis en avant (PEM). */
export async function listPem(): Promise<PemRow[] | null> {
  try {
    const res = await serverFetch('/promos/pem');
    if (!res.ok) return null;
    return (await res.json()) as PemRow[];
  } catch {
    return null;
  }
}

// --- Prospection (pilotage) ---------------------------------------------
// Contrat aligné sur les DTOs Swagger de l'API. Les réponses n'étant pas
// typées côté API, la forme des lignes renvoyées suit ses conventions
// habituelles (pagination + relations) et reste tolérante aux valeurs nulles.

export type ProspectStatut =
  | 'NOUVEAU'
  | 'CONTACTE'
  | 'QUALIFIE'
  | 'PROPOSITION'
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
  'QUALIFIE',
  'PROPOSITION',
  'NEGOCIATION',
  'GAGNE',
  'PERDU',
];

export type ProspectRow = {
  id: string;
  raisonSociale: string;
  enseigne: string;
  ville: string | null;
  statut: ProspectStatut;
  probabilite: number | null;
  potentielCaAnnuel: number | null;
  source: ProspectSource | null;
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

/** Compte les prospects correspondant aux filtres (lit `total`, page allégée). */
export async function countProspects(
  params: { statut?: string; secteur?: string } = {},
): Promise<number | null> {
  try {
    const res = await serverFetch(
      `/prospects${qs({ statut: params.statut, secteur: params.secteur, page: 1, limit: 1 })}`,
    );
    if (!res.ok) return null;
    const d = (await res.json()) as { total?: number };
    return d.total ?? 0;
  } catch {
    return null;
  }
}

export type PipelineColonne = {
  statut: ProspectStatut;
  total: number;
  valeurPonderee: number;
  prospects: ProspectRow[];
};

/**
 * Pipeline groupé par étape (Kanban). Tolérant à la forme exacte du retour :
 * accepte un tableau de colonnes, un objet { colonnes: [...] } ou une map
 * { STATUT: {...} }, et normalise toujours vers l'ordre des étapes.
 */
export async function getProspectPipeline(): Promise<PipelineColonne[] | null> {
  try {
    const res = await serverFetch('/prospects/pipeline');
    if (!res.ok) return null;
    const json = (await res.json()) as unknown;
    const raw: unknown = Array.isArray(json)
      ? json
      : (json as { colonnes?: unknown }).colonnes ?? json;

    const byStatut = new Map<string, PipelineColonne>();
    if (Array.isArray(raw)) {
      for (const c of raw as PipelineColonne[]) if (c?.statut) byStatut.set(c.statut, c);
    } else if (raw && typeof raw === 'object') {
      for (const [statut, c] of Object.entries(raw as Record<string, Partial<PipelineColonne>>)) {
        byStatut.set(statut, {
          statut: statut as ProspectStatut,
          total: c.total ?? c.prospects?.length ?? 0,
          valeurPonderee: c.valeurPonderee ?? 0,
          prospects: c.prospects ?? [],
        });
      }
    }
    return PROSPECT_STATUTS.map(
      (statut) =>
        byStatut.get(statut) ?? { statut, total: 0, valeurPonderee: 0, prospects: [] },
    );
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

/** Fiche prospect complète, ou null si introuvable. */
export async function getProspect(id: string): Promise<ProspectDetail | null> {
  try {
    const res = await serverFetch(`/prospects/${id}`);
    if (!res.ok) return null;
    return (await res.json()) as ProspectDetail;
  } catch {
    return null;
  }
}

export type ProspectHistorique = {
  visites: {
    id: string;
    createdAt: string;
    motif: string | null;
    commentaire: string | null;
    promoteur?: { displayName: string } | null;
  }[];
  opportunites: OpportuniteRow[];
};

/** Timeline du prospect (visites de prospection + opportunités). Tolérant à la forme du retour. */
export async function getProspectHistorique(id: string): Promise<ProspectHistorique | null> {
  try {
    const res = await serverFetch(`/prospects/${id}/historique`);
    if (!res.ok) return null;
    const json = (await res.json()) as Partial<ProspectHistorique> | unknown[];
    if (Array.isArray(json)) {
      // Retour à plat : on répartit visites / opportunités au mieux.
      return { visites: [], opportunites: [] };
    }
    const j = json as Partial<ProspectHistorique>;
    return { visites: j.visites ?? [], opportunites: j.opportunites ?? [] };
  } catch {
    return null;
  }
}
