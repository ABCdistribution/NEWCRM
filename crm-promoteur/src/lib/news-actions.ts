'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';

export type NewsFormState = { error: string | null; ok?: boolean };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** La page des news existe dans les deux applications (chemins différents) : on rafraîchit les deux. */
function rafraichir() {
  revalidatePath('/pilotage/news');
  revalidatePath('/news');
}

/** Message d'erreur lisible à partir d'une réponse d'API en échec. */
async function messageErreur(res: Response): Promise<string> {
  if (res.status === 401) return 'Session expirée. Reconnecte-toi.';
  if (res.status === 403) return "Tu n'as pas le droit d'administrer les news.";
  if (res.status === 404) return 'Cette news est introuvable (déjà supprimée ?).';
  const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
  const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
  return msg ?? `Erreur serveur (${res.status}).`;
}

/** Crée (sans `id`) ou modifie (avec `id`) une news. `imageUrl` vide = pas d'image / retrait de l'image. */
export async function saveNews(_prev: NewsFormState, formData: FormData): Promise<NewsFormState> {
  const id = String(formData.get('id') ?? '').trim();
  const titre = String(formData.get('titre') ?? '').trim();
  const contenu = String(formData.get('contenu') ?? '').trim();
  const imageUrl = String(formData.get('imageUrl') ?? '').trim();
  const publiee = formData.get('publiee') === 'on';

  if (!titre || !contenu) return { error: 'Le titre et le contenu sont obligatoires.' };
  if (titre.length > 200) return { error: 'Le titre ne doit pas dépasser 200 caractères.' };
  if (contenu.length > 20000) return { error: 'Le contenu ne doit pas dépasser 20 000 caractères.' };
  if (imageUrl && (imageUrl.length > 500 || !/^(https?:\/\/|\/(?!\/))/i.test(imageUrl))) {
    return { error: "L'image doit être une adresse http(s) ou un chemin commençant par « / » (500 caractères max)." };
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
