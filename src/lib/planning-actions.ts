'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';

export type PlanningState = { error: string | null; ok: boolean };

/** Planifie une visite (promoteur × magasin × date). */
export async function addPlanning(
  _prev: PlanningState,
  formData: FormData,
): Promise<PlanningState> {
  const promoteurId = String(formData.get('promoteurId') ?? '');
  const clientId = String(formData.get('clientId') ?? '');
  const datePassage = String(formData.get('datePassage') ?? '');

  if (!promoteurId || !clientId || !datePassage) {
    return { error: 'Magasin requis.', ok: false };
  }

  let res: Response;
  try {
    res = await serverFetch('/plannings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ promoteurId, clientId, datePassage }),
    });
  } catch {
    return { error: "Impossible de joindre l'API.", ok: false };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).`, ok: false };
  }

  revalidatePath('/tournees');
  return { error: null, ok: true };
}

/** Version directe (drag & drop) : planifie une visite, renvoie l'erreur éventuelle. */
export async function dropPlanning(
  promoteurId: string,
  clientId: string,
  datePassage: string,
): Promise<{ error: string | null }> {
  let res: Response;
  try {
    res = await serverFetch('/plannings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ promoteurId, clientId, datePassage }),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).` };
  }
  revalidatePath('/tournees');
  return { error: null };
}

/** Déplace une visite planifiée vers une autre date (drag & drop entre jours). */
export async function movePlanning(
  id: string,
  datePassage: string,
): Promise<{ error: string | null }> {
  let res: Response;
  try {
    res = await serverFetch(`/plannings/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ datePassage }),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).` };
  }
  revalidatePath('/tournees');
  return { error: null };
}

/** Relance le promoteur d'une visite manquée (notification in-app / mobile). */
export async function relancerVisite(planningId: string): Promise<{ error: string | null }> {
  let res: Response;
  try {
    res = await serverFetch('/notifications/relance', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ planningId }),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).` };
  }
  return { error: null };
}

export type RegleState = { error: string | null; ok: boolean };

/** Crée une règle de récurrence (magasin × jours × fréquence). */
export async function addRegle(_prev: RegleState, formData: FormData): Promise<RegleState> {
  const promoteurId = String(formData.get('promoteurId') ?? '');
  const clientId = String(formData.get('clientId') ?? '');
  const dateDebut = String(formData.get('dateDebut') ?? '');
  const recurrence = Number(formData.get('recurrence') ?? 1);
  const jours = formData.getAll('jours').map(Number).filter((n) => n >= 1 && n <= 6);

  if (!clientId) return { error: 'Choisis un magasin.', ok: false };
  if (jours.length === 0) return { error: 'Coche au moins un jour.', ok: false };

  let res: Response;
  try {
    res = await serverFetch('/plannifications', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ promoteurId, clientId, jours, recurrence, dateDebut }),
    });
  } catch {
    return { error: "Impossible de joindre l'API.", ok: false };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).`, ok: false };
  }

  revalidatePath('/tournees');
  return { error: null, ok: true };
}

/** Supprime une règle de récurrence (et ses occurrences futures non faites). */
export async function removeRegle(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  await serverFetch(`/plannifications/${id}`, { method: 'DELETE' }).catch(() => undefined);
  revalidatePath('/tournees');
}

/** Retire une visite planifiée. */
export async function removePlanning(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  await serverFetch(`/plannings/${id}`, { method: 'DELETE' }).catch(() => undefined);
  revalidatePath('/tournees');
}
