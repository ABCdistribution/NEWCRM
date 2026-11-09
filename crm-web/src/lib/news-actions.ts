'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';
import { messageErreurApi } from './erreurs-api';
import { NEWS_ADMIN_ROLES } from './news';
import { exigerRole, messageRefus } from './roles';

export type NewsFormState = { error: string | null; ok?: boolean };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Rafraîchit la page des news (chemin unique dans crm-web). */
function rafraichir() {
  revalidatePath('/news');
}

/**
 * Rôle autorisé (ADMIN, MARKETING) ? Renvoie un message d'erreur sinon : une action ne doit pas lever vers
 * l'utilisateur. Défense en profondeur : l'API reste juge (@Roles sur /news).
 */
async function controleRole(): Promise<string | null> {
  try {
    await exigerRole(NEWS_ADMIN_ROLES);
    return null;
  } catch (e) {
    return messageRefus(e, "Accès refusé : action réservée à l'administration et au marketing.");
  }
}

/** Message d'erreur lisible à partir d'une réponse d'API en échec. */
async function messageErreur(res: Response): Promise<string> {
  if (res.status === 403) return "Vous n'avez pas le droit d'administrer les news.";
  if (res.status === 404) return 'Cette news est introuvable (déjà supprimée ?).';
  return messageErreurApi(res, 'news');
}

/** Crée (sans `id`) ou modifie (avec `id`) une news. `imageUrl` vide = pas d'image / retrait de l'image. */
export async function saveNews(_prev: NewsFormState, formData: FormData): Promise<NewsFormState> {
  const refus = await controleRole();
  if (refus) return { error: refus };

  const id = String(formData.get('id') ?? '').trim();
  const titre = String(formData.get('titre') ?? '').trim();
  const contenu = String(formData.get('contenu') ?? '').trim();
  const imageUrl = String(formData.get('imageUrl') ?? '').trim();
  const publiee = formData.get('publiee') === 'on';

  if (!titre || !contenu) return { error: 'Le titre et le contenu sont obligatoires.' };
  if (titre.length > 200) return { error: 'Le titre ne doit pas dépasser 200 caractères.' };
  if (contenu.length > 20000) return { error: 'Le contenu ne doit pas dépasser 20 000 caractères.' };
  // https uniquement (une image en http est interceptable, et un <img src> externe envoie l'IP du lecteur à un tiers :
  // on ne l'accepte qu'en https) ou un chemin du site. « // » et « /\ » sont refusés : le navigateur les lit comme
  // une adresse d'un autre site.
  if (imageUrl && (imageUrl.length > 500 || !/^(https:\/\/|\/(?![\/\\]))/i.test(imageUrl))) {
    return { error: "L'image doit être une adresse https ou un chemin commençant par « / » (500 caractères max)." };
  }
  if (id && !UUID.test(id)) return { error: 'Identifiant de news invalide.' };

  const payload = id
    ? { titre, contenu, imageUrl: imageUrl || null, publiee }
    : { titre, contenu, ...(imageUrl ? { imageUrl } : {}), publiee };

  let res: Response;
  try {
    res = await serverFetch(id ? `/news/${encodeURIComponent(id)}` : '/news', {
      method: id ? 'PATCH' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) return { error: await messageErreur(res) };
  rafraichir();
  return { error: null, ok: true };
}

/** Publie ou dépublie une news (PATCH /news/:id). */
export async function setNewsPubliee(id: string, publiee: boolean): Promise<{ error: string | null }> {
  const refus = await controleRole();
  if (refus) return { error: refus };
  if (!UUID.test(id)) return { error: 'Identifiant de news invalide.' };
  let res: Response;
  try {
    res = await serverFetch(`/news/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ publiee }),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) return { error: await messageErreur(res) };
  rafraichir();
  return { error: null };
}

/** Supprime une news (DELETE /news/:id). */
export async function deleteNews(id: string): Promise<{ error: string | null }> {
  const refus = await controleRole();
  if (refus) return { error: refus };
  if (!UUID.test(id)) return { error: 'Identifiant de news invalide.' };
  let res: Response;
  try {
    res = await serverFetch(`/news/${encodeURIComponent(id)}`, { method: 'DELETE' });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) return { error: await messageErreur(res) };
  rafraichir();
  return { error: null };
}
