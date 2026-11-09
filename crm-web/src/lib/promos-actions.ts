'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch, type ArticleRow, type Paginated } from './api';
import { exigerRole } from './roles';
import { PROMOS_EDITION } from './promos';

export type PromoState = { error: string | null; ok: boolean };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ERREUR_RESEAU = "Impossible de joindre l'API.";

/** Contrôle de rôle d'une action : renvoie un état d'erreur plutôt que de lever. */
async function refuse(): Promise<PromoState | null> {
  try {
    await exigerRole(PROMOS_EDITION);
    return null;
  } catch {
    return { error: 'Accès refusé : action réservée à la direction et au marketing.', ok: false };
  }
}

function messageHttp(status: number): string {
  if (status === 401 || status === 403) return 'Accès refusé.';
  if (status === 404) return 'Élément introuvable (déjà supprimé ?).';
  return `Erreur serveur (${status}).`;
}

/** Recherche d'articles pour le sélecteur (appelée depuis le composant client). */
export async function searchArticles(term: string): Promise<ArticleRow[]> {
  if (await refuse()) return [];
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
  const refus = await refuse();
  if (refus) return refus;
  const articleId = String(formData.get('articleId') ?? '');
  const libelle = String(formData.get('libelle') ?? '').trim();
  const dateDebut = String(formData.get('dateDebut') ?? '').trim();
  const dateFin = String(formData.get('dateFin') ?? '').trim();
  if (!UUID.test(articleId)) return { error: 'Choisis un article.', ok: false };
  if (dateDebut && Number.isNaN(Date.parse(dateDebut))) return { error: 'Date de début invalide.', ok: false };
  if (dateFin && Number.isNaN(Date.parse(dateFin))) return { error: 'Date de fin invalide.', ok: false };

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
    return { error: ERREUR_RESEAU, ok: false };
  }
  if (!res.ok) return { error: messageHttp(res.status), ok: false };
  revalidatePath('/promos');
  return { error: null, ok: true };
}

/** Active / désactive une promo. */
export async function togglePromo(_prev: PromoState, formData: FormData): Promise<PromoState> {
  const refus = await refuse();
  if (refus) return refus;
  const id = String(formData.get('id') ?? '');
  const actif = String(formData.get('actif') ?? '') === 'true';
  if (!UUID.test(id)) return { error: 'Identifiant invalide.', ok: false };
  let res: Response;
  try {
    res = await serverFetch(`/promos/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ actif }),
    });
  } catch {
    return { error: ERREUR_RESEAU, ok: false };
  }
  if (!res.ok) return { error: messageHttp(res.status), ok: false };
  revalidatePath('/promos');
  return { error: null, ok: true };
}

/** Supprime une promo. */
export async function deletePromo(_prev: PromoState, formData: FormData): Promise<PromoState> {
  const refus = await refuse();
  if (refus) return refus;
  const id = String(formData.get('id') ?? '');
  if (!UUID.test(id)) return { error: 'Identifiant invalide.', ok: false };
  let res: Response;
  try {
    res = await serverFetch(`/promos/${encodeURIComponent(id)}`, { method: 'DELETE' });
  } catch {
    return { error: ERREUR_RESEAU, ok: false };
  }
  if (!res.ok) return { error: messageHttp(res.status), ok: false };
  revalidatePath('/promos');
  return { error: null, ok: true };
}

/** Met un article en avant (PEM). */
export async function addPem(_prev: PromoState, formData: FormData): Promise<PromoState> {
  const refus = await refuse();
  if (refus) return refus;
  const articleId = String(formData.get('articleId') ?? '');
  if (!UUID.test(articleId)) return { error: 'Choisis un article.', ok: false };
  let res: Response;
  try {
    res = await serverFetch('/promos/pem', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ articleId }),
    });
  } catch {
    return { error: ERREUR_RESEAU, ok: false };
  }
  if (!res.ok) return { error: messageHttp(res.status), ok: false };
  revalidatePath('/promos');
  return { error: null, ok: true };
}

/** Retire une mise en avant. */
export async function deletePem(_prev: PromoState, formData: FormData): Promise<PromoState> {
  const refus = await refuse();
  if (refus) return refus;
  const id = String(formData.get('id') ?? '');
  if (!UUID.test(id)) return { error: 'Identifiant invalide.', ok: false };
  let res: Response;
  try {
    res = await serverFetch(`/promos/pem/${encodeURIComponent(id)}`, { method: 'DELETE' });
  } catch {
    return { error: ERREUR_RESEAU, ok: false };
  }
  if (!res.ok) return { error: messageHttp(res.status), ok: false };
  revalidatePath('/promos');
  return { error: null, ok: true };
}
