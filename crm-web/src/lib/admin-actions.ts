'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch, listFichiersDepot } from './api';
import { exigerRole } from './roles';
import { TYPES_MINOS, typeMinos } from './minos';

/** Console d'administration : réservée au rôle ADMIN (chaque action rappelle la garde). */
const ADMIN = ['ADMIN'] as const;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ROLES_VALIDES = ['COMMERCIAL', 'CHEF_SECTEUR', 'ADMIN', 'DIRECTEUR_REGIONAL', 'DIRECTION', 'ADV', 'MARKETING'];

const REFUSE = 'Accès refusé : action réservée aux administrateurs.';
const INJOIGNABLE = "Impossible de joindre l'API.";

/** Contrôle de rôle d'une action : renvoie un message d'erreur si l'accès est refusé. */
async function refus(): Promise<string | null> {
  try {
    await exigerRole(ADMIN);
    return null;
  } catch {
    return REFUSE;
  }
}

async function messageErreur(res: Response): Promise<string> {
  const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
  const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
  return msg ?? `Erreur serveur (${res.status}).`;
}

/** PATCH /users/:id ; renvoie un message d'erreur (français) ou null si succès. */
async function patchUser(userId: string, payload: Record<string, unknown>): Promise<string | null> {
  const interdit = await refus();
  if (interdit) return interdit;
  if (!UUID.test(userId)) return 'Utilisateur invalide.';
  let res: Response;
  try {
    res = await serverFetch(`/users/${encodeURIComponent(userId)}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  } catch {
    return INJOIGNABLE;
  }
  if (!res.ok) return messageErreur(res);
  revalidatePath('/admin');
  return null;
}

/** Change le rôle d'un utilisateur. Renvoie un message d'erreur ou null. */
export async function setUserRole(formData: FormData): Promise<string | null> {
  const role = String(formData.get('role') ?? '');
  if (!ROLES_VALIDES.includes(role)) return 'Rôle invalide.';
  return patchUser(String(formData.get('userId') ?? ''), { role });
}

/** Active / désactive un utilisateur. Renvoie un message d'erreur ou null. */
export async function setUserActive(formData: FormData): Promise<string | null> {
  const isActive = String(formData.get('isActive') ?? '') === 'true';
  return patchUser(String(formData.get('userId') ?? ''), { isActive });
}

/** Rattache un utilisateur à un secteur ('' = détacher). Renvoie un message d'erreur ou null. */
export async function setUserSecteur(formData: FormData): Promise<string | null> {
  const secteurId = String(formData.get('secteurId') ?? '');
  if (secteurId && !UUID.test(secteurId)) return 'Secteur invalide.';
  return patchUser(String(formData.get('userId') ?? ''), { secteurId: secteurId || null });
}

export type ImportState = { error: string | null; ok: boolean };

/** Déclenche un import Minos (clients, articles ou centrales selon le champ `type`). */
export async function triggerImportClients(_prev: ImportState, formData: FormData): Promise<ImportState> {
  const interdit = await refus();
  if (interdit) return { error: interdit, ok: false };
  const filePath = String(formData.get('filePath') ?? '').trim();
  const brut = String(formData.get('type') ?? 'clients');
  const type = brut === 'articles' || brut === 'centrales' ? brut : 'clients';
  if (!filePath) return { error: 'Chemin du fichier requis.', ok: false };

  let res: Response;
  try {
    res = await serverFetch(`/import/minos/${type}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ filePath }),
    });
  } catch {
    return { error: INJOIGNABLE, ok: false };
  }
  if (!res.ok) return { error: await messageErreur(res), ok: false };

  revalidatePath('/admin');
  return { error: null, ok: true };
}

export type SynchroMinosState = {
  lance: boolean;
  error: string | null;
  fichiers: { nom: string; type: string | null; ok: boolean; message: string | null }[];
};

/**
 * Synchro Minos manuelle : met en file chaque fichier d'interface reconnu (CLI_, ART_, ARB_) de la zone d'échange,
 * dans l'ordre clients → articles → arborescence. L'intégration est asynchrone : le détail (lignes, rejets, durée)
 * apparaît dans le rapport au fil du traitement. Seuls les fichiers réellement présents dans la zone sont acceptés.
 */
export async function lancerSynchroMinos(_prev: SynchroMinosState, formData: FormData): Promise<SynchroMinosState> {
  const interdit = await refus();
  if (interdit) return { lance: false, error: interdit, fichiers: [] };

  const demandes = new Set(formData.getAll('chemin').map(String));
  const depot = await listFichiersDepot();
  if (!depot) return { lance: false, error: "Zone d'échange inaccessible : l'API est-elle démarrée ?", fichiers: [] };

  const aTraiter = depot.fichiers
    .filter((f) => demandes.has(f.chemin) && typeMinos(f.nom) !== null)
    .sort((a, b) => TYPES_MINOS[typeMinos(a.nom)!].ordre - TYPES_MINOS[typeMinos(b.nom)!].ordre || a.nom.localeCompare(b.nom));
  if (aTraiter.length === 0) return { lance: false, error: 'Aucun fichier reconnu à intégrer.', fichiers: [] };

  const fichiers: SynchroMinosState['fichiers'] = [];
  for (const f of aTraiter) {
    const type = typeMinos(f.nom)!;
    try {
      const res = await serverFetch(`/import/minos/${TYPES_MINOS[type].route}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filePath: f.chemin }),
      });
      if (res.ok) fichiers.push({ nom: f.nom, type, ok: true, message: null });
      else fichiers.push({ nom: f.nom, type, ok: false, message: await messageErreur(res) });
    } catch {
      fichiers.push({ nom: f.nom, type, ok: false, message: INJOIGNABLE });
    }
  }
  revalidatePath('/admin');
  return { lance: true, error: null, fichiers };
}

export type AdSyncState = {
  error: string | null;
  ok: boolean;
  stats?: {
    lus: number;
    crees: number;
    maj: number;
    photos?: number;
    directeursLies: number;
    sansRegion: string[];
    sansManager: string[];
    conflitsIdRepr: string[];
  };
};

/** Synchronise la force de vente française depuis l'AD (comptes, régions, hiérarchie). */
export async function syncAd(_prev: AdSyncState, _formData: FormData): Promise<AdSyncState> {
  const interdit = await refus();
  if (interdit) return { error: interdit, ok: false };
  let res: Response;
  try {
    res = await serverFetch('/sync/ad', { method: 'POST' });
  } catch {
    return { error: INJOIGNABLE, ok: false };
  }
  if (!res.ok) return { error: await messageErreur(res), ok: false };
  const stats = (await res.json()) as NonNullable<AdSyncState['stats']>;
  revalidatePath('/admin');
  return { error: null, ok: true, stats };
}
