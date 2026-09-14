'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';

export type SecteurFormState = { error: string | null; ok: boolean };

/** Crée un secteur (POST /secteurs). */
export async function createSecteur(
  _prev: SecteurFormState,
  formData: FormData,
): Promise<SecteurFormState> {
  const code = String(formData.get('code') ?? '').trim();
  const nom = String(formData.get('nom') ?? '').trim();
  const managerId = String(formData.get('managerId') ?? '').trim();
  if (!code || !nom) return { error: 'Le code et le nom sont obligatoires.', ok: false };

  let res: Response;
  try {
    res = await serverFetch('/secteurs', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code, nom, managerId: managerId || null }),
    });
  } catch {
    return { error: "Impossible de joindre l'API.", ok: false };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).`, ok: false };
  }
  revalidatePath('/pilotage/secteurs');
  return { error: null, ok: true };
}

/** Modifie un secteur (nom et/ou chef). PATCH /secteurs/:id */
export async function updateSecteur(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  const payload: Record<string, unknown> = {};
  if (formData.has('nom')) payload.nom = String(formData.get('nom') ?? '').trim();
  if (formData.has('managerId')) {
    const m = String(formData.get('managerId') ?? '').trim();
    payload.managerId = m || null;
  }
  await serverFetch(`/secteurs/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  }).catch(() => undefined);
  revalidatePath('/pilotage/secteurs');
}
