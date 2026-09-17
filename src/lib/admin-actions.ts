'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch, type ArticleRow, type Paginated } from './api';

/** Change le rôle d'un utilisateur (PATCH /users/:id). */
export async function setUserRole(formData: FormData): Promise<void> {
  const userId = String(formData.get('userId') ?? '');
  const role = String(formData.get('role') ?? '');
  if (!userId || !role) return;
  await serverFetch(`/users/${userId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ role }),
  }).catch(() => undefined);
  revalidatePath('/pilotage/users');
}

/** Active / désactive un utilisateur. */
export async function setUserActive(formData: FormData): Promise<void> {
  const userId = String(formData.get('userId') ?? '');
  const isActive = String(formData.get('isActive') ?? '') === 'true';
  if (!userId) return;
  await serverFetch(`/users/${userId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ isActive }),
  }).catch(() => undefined);
  revalidatePath('/pilotage/users');
}

/** Rattache un utilisateur à un secteur ('' = détacher). */
export async function setUserSecteur(formData: FormData): Promise<void> {
  const userId = String(formData.get('userId') ?? '');
  const secteurId = String(formData.get('secteurId') ?? '');
  if (!userId) return;
  await serverFetch(`/users/${userId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ secteurId: secteurId || null }),
  }).catch(() => undefined);
  revalidatePath('/pilotage/users');
}


export type ImportState = { error: string | null; ok: boolean };

/** Déclenche un import Minos (clients ou articles selon le champ `type`). */
export async function triggerImportClients(
  _prev: ImportState,
  formData: FormData,
): Promise<ImportState> {
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
    return { error: "Impossible de joindre l'API.", ok: false };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).`, ok: false };
  }

  revalidatePath('/pilotage/imports');
  return { error: null, ok: true };
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
  let res: Response;
  try {
    res = await serverFetch('/sync/ad', { method: 'POST' });
  } catch {
    return { error: "Impossible de joindre l'API.", ok: false };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string } | null;
    return { error: body?.message ?? `Erreur serveur (${res.status}).`, ok: false };
  }
  const stats = (await res.json()) as NonNullable<AdSyncState['stats']>;
  revalidatePath('/pilotage/users');
  return { error: null, ok: true, stats };
}

export type QuestionState = { error: string | null; ok: boolean };

/** Ajoute une question au questionnaire de fin de visite. */
export async function addQuestion(_prev: QuestionState, formData: FormData): Promise<QuestionState> {
  const libelle = String(formData.get('libelle') ?? '').trim();
  const type = String(formData.get('type') ?? 'CASE_A_COCHER');
  const obligatoire = formData.get('obligatoire') === 'on';
  if (!libelle) return { error: 'Le libellé est obligatoire.', ok: false };

  let res: Response;
  try {
    res = await serverFetch('/questionnaire/questions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ libelle, type, obligatoire }),
    });
  } catch {
    return { error: "Impossible de joindre l'API.", ok: false };
  }
  if (!res.ok) return { error: `Erreur serveur (${res.status}).`, ok: false };
  revalidatePath('/pilotage/questionnaire');
  return { error: null, ok: true };
}

/** Modifie une question (libellé / type / obligatoire / actif). */
export async function updateQuestion(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  const payload: Record<string, unknown> = {};
  if (formData.has('libelle')) payload.libelle = String(formData.get('libelle') ?? '').trim();
  if (formData.has('type')) payload.type = String(formData.get('type'));
  if (formData.has('obligatoire')) payload.obligatoire = formData.get('obligatoire') === 'true';
  if (formData.has('actif')) payload.actif = formData.get('actif') === 'true';

  await serverFetch(`/questionnaire/questions/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  }).catch(() => undefined);
  revalidatePath('/pilotage/questionnaire');
}

/** Déplace une question d'un cran (haut/bas). */
export async function deplacerQuestion(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  const direction = String(formData.get('direction') ?? '');
  if (!id || (direction !== 'haut' && direction !== 'bas')) return;
  await serverFetch(`/questionnaire/questions/${id}/deplacer`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ direction }),
  }).catch(() => undefined);
  revalidatePath('/pilotage/questionnaire');
}

/** Supprime (logiquement) une question. */
export async function deleteQuestion(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  await serverFetch(`/questionnaire/questions/${id}`, { method: 'DELETE' }).catch(() => undefined);
  revalidatePath('/pilotage/questionnaire');
}

// --- Promos / PEM -------------------------------------------------------

export type PromoState = { error: string | null; ok: boolean };

/** Recherche d'articles pour le sélecteur (appelée depuis le composant client). */
export async function searchArticles(term: string): Promise<ArticleRow[]> {
  const t = term.trim();
  if (t.length < 2) return [];
  try {
    const res = await serverFetch(`/articles?search=${encodeURIComponent(t)}&limit=15`);
    if (!res.ok) return [];
    const data = (await res.json()) as Paginated<ArticleRow>;
    return data.data;
  } catch {
    return [];
  }
}

/** Crée une promo sur un article. */
export async function addPromo(_prev: PromoState, formData: FormData): Promise<PromoState> {
  const articleId = String(formData.get('articleId') ?? '');
  const libelle = String(formData.get('libelle') ?? '').trim();
  const dateDebut = String(formData.get('dateDebut') ?? '').trim();
  const dateFin = String(formData.get('dateFin') ?? '').trim();
  if (!articleId) return { error: 'Choisis un article.', ok: false };

  let res: Response;
  try {
    res = await serverFetch('/promos', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        articleId,
        libelle: libelle || undefined,
        dateDebut: dateDebut ? new Date(dateDebut).toISOString() : undefined,
        dateFin: dateFin ? new Date(dateFin).toISOString() : undefined,
      }),
    });
  } catch {
    return { error: "Impossible de joindre l'API.", ok: false };
  }
  if (!res.ok) return { error: `Erreur serveur (${res.status}).`, ok: false };
  revalidatePath('/pilotage/promos');
  return { error: null, ok: true };
}

/** Active / désactive une promo. */
export async function togglePromo(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  const actif = String(formData.get('actif') ?? '') === 'true';
  if (!id) return;
  await serverFetch(`/promos/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ actif }),
  }).catch(() => undefined);
  revalidatePath('/pilotage/promos');
}

/** Supprime une promo. */
export async function deletePromo(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  await serverFetch(`/promos/${id}`, { method: 'DELETE' }).catch(() => undefined);
  revalidatePath('/pilotage/promos');
}

/** Met un article en avant (PEM). */
export async function addPem(_prev: PromoState, formData: FormData): Promise<PromoState> {
  const articleId = String(formData.get('articleId') ?? '');
  if (!articleId) return { error: 'Choisis un article.', ok: false };
  let res: Response;
  try {
    res = await serverFetch('/promos/pem', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ articleId }),
    });
  } catch {
    return { error: "Impossible de joindre l'API.", ok: false };
  }
  if (!res.ok) return { error: `Erreur serveur (${res.status}).`, ok: false };
  revalidatePath('/pilotage/promos');
  return { error: null, ok: true };
}

/** Retire une mise en avant. */
export async function deletePem(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  await serverFetch(`/promos/pem/${id}`, { method: 'DELETE' }).catch(() => undefined);
  revalidatePath('/pilotage/promos');
}
