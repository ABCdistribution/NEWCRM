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

  revalidatePath(`/pilotage/clients/${clientId}`);
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
  revalidatePath(`/pilotage/clients/${clientId}`);
}
