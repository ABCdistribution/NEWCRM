'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';

export type ContactFormState = { error: string | null; ok: boolean };

/** Extrait les champs contact du formulaire, en omettant les valeurs vides. */
function contactPayload(formData: FormData): Record<string, string> {
  const payload: Record<string, string> = {};
  for (const key of ['prenom', 'nom', 'poste', 'typePoste', 'fixe', 'portable', 'mail']) {
    const v = String(formData.get(key) ?? '').trim();
    if (v) payload[key] = v;
  }
  return payload;
}

/** Crée ou met à jour un contact (selon la présence de contactId). */
export async function saveContact(
  _prev: ContactFormState,
  formData: FormData,
): Promise<ContactFormState> {
  const clientId = String(formData.get('clientId') ?? '');
  const contactId = String(formData.get('contactId') ?? '');
  const payload = contactPayload(formData);

  if (!clientId) return { error: 'Client manquant.', ok: false };
  if (!payload.nom) return { error: 'Le nom du contact est obligatoire.', ok: false };

  const path = contactId
    ? `/clients/${clientId}/contacts/${contactId}`
    : `/clients/${clientId}/contacts`;

  let res: Response;
  try {
    res = await serverFetch(path, {
      method: contactId ? 'PATCH' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  } catch {
    return { error: "Impossible de joindre l'API.", ok: false };
  }

  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).`, ok: false };
  }

  revalidatePath(`/clients/${clientId}`);
  return { error: null, ok: true };
}

/** Supprime (logiquement) un contact. */
export async function deleteContact(formData: FormData): Promise<void> {
  const clientId = String(formData.get('clientId') ?? '');
  const contactId = String(formData.get('contactId') ?? '');
  if (!clientId || !contactId) return;

  try {
    await serverFetch(`/clients/${clientId}/contacts/${contactId}`, { method: 'DELETE' });
  } catch {
    return;
  }
  revalidatePath(`/clients/${clientId}`);
}

export type NoteFormState = { error: string | null; ok: boolean };

/** Ajoute une note terrain au magasin. */
export async function addNote(_prev: NoteFormState, formData: FormData): Promise<NoteFormState> {
  const clientId = String(formData.get('clientId') ?? '');
  const remarque = String(formData.get('remarque') ?? '').trim();

  if (!clientId) return { error: 'Client manquant.', ok: false };
  if (!remarque) return { error: 'La note est vide.', ok: false };

  let res: Response;
  try {
    res = await serverFetch(`/clients/${clientId}/notes`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ remarque }),
    });
  } catch {
    return { error: "Impossible de joindre l'API.", ok: false };
  }

  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).`, ok: false };
  }

  revalidatePath(`/clients/${clientId}`);
  return { error: null, ok: true };
}

/** Supprime (logiquement) une note terrain. */
export async function deleteNote(formData: FormData): Promise<void> {
  const clientId = String(formData.get('clientId') ?? '');
  const noteId = String(formData.get('noteId') ?? '');
  if (!clientId || !noteId) return;

  try {
    await serverFetch(`/clients/${clientId}/notes/${noteId}`, { method: 'DELETE' });
  } catch {
    return;
  }
  revalidatePath(`/clients/${clientId}`);
}

/** Définit la périodicité de visite du magasin (valeur vide = aucune). */
export async function setPeriodicite(formData: FormData): Promise<void> {
  const clientId = String(formData.get('clientId') ?? '');
  if (!clientId) return;
  const periodiciteId = String(formData.get('periodiciteId') ?? '').trim() || null;

  try {
    await serverFetch(`/clients/${clientId}/periodicite`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ periodiciteId }),
    });
  } catch {
    return;
  }
  revalidatePath(`/clients/${clientId}`);
}
