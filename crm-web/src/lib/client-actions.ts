'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';
import { ENCADREMENT, TERRAIN, exigerRole } from './roles';

/**
 * Édition de la fiche client (contacts, notes, périodicité) : terrain et encadrement
 * (l'encadrement garde l'accès aux écrans terrain). Le périmètre reste filtré par l'API.
 */
const EDITEURS = [...TERRAIN, ...ENCADREMENT];

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const estUuid = (v: string) => UUID.test(v);

export type ContactFormState = { error: string | null; ok: boolean };
export type NoteFormState = { error: string | null; ok: boolean };
export type ActionState = { error: string | null };

/** Message d'erreur français tiré de la réponse de l'API (message de validation sinon code HTTP). */
async function messageErreur(res: Response): Promise<string> {
  if (res.status === 401) return 'Session expirée, reconnectez-vous.';
  if (res.status === 403) return "Vous n'avez pas le droit d'effectuer cette action.";
  if (res.status === 404) return 'Élément introuvable.';
  const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
  const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
  return msg ?? `Erreur serveur (${res.status}).`;
}

/** Appel d'API d'une mutation : renvoie null si succès, sinon un message d'erreur français. */
async function muter(path: string, method: 'POST' | 'PATCH' | 'DELETE', payload?: unknown): Promise<string | null> {
  try {
    const res = await serverFetch(path, {
      method,
      ...(payload === undefined
        ? {}
        : { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }),
    });
    if (!res.ok) return await messageErreur(res);
    return null;
  } catch {
    return "Impossible de joindre l'API.";
  }
}

/** Rôle autorisé ? Renvoie un message d'erreur sinon (une action ne doit pas lever vers l'utilisateur). */
async function controleRole(): Promise<string | null> {
  try {
    await exigerRole(EDITEURS);
    return null;
  } catch {
    return 'Accès refusé.';
  }
}

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
  const refus = await controleRole();
  if (refus) return { error: refus, ok: false };

  const clientId = String(formData.get('clientId') ?? '');
  const contactId = String(formData.get('contactId') ?? '');
  const payload = contactPayload(formData);

  if (!estUuid(clientId)) return { error: 'Client invalide.', ok: false };
  if (contactId && !estUuid(contactId)) return { error: 'Contact invalide.', ok: false };
  if (!payload.nom) return { error: 'Le nom du contact est obligatoire.', ok: false };

  const base = `/clients/${encodeURIComponent(clientId)}/contacts`;
  const error = contactId
    ? await muter(`${base}/${encodeURIComponent(contactId)}`, 'PATCH', payload)
    : await muter(base, 'POST', payload);
  if (error) return { error, ok: false };

  revalidatePath(`/clients/${clientId}`);
  return { error: null, ok: true };
}

/** Supprime (logiquement) un contact. */
export async function deleteContact(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const refus = await controleRole();
  if (refus) return { error: refus };

  const clientId = String(formData.get('clientId') ?? '');
  const contactId = String(formData.get('contactId') ?? '');
  if (!estUuid(clientId) || !estUuid(contactId)) return { error: 'Identifiant invalide.' };

  const error = await muter(
    `/clients/${encodeURIComponent(clientId)}/contacts/${encodeURIComponent(contactId)}`,
    'DELETE',
  );
  if (error) return { error };

  revalidatePath(`/clients/${clientId}`);
  return { error: null };
}

/** Ajoute une note terrain au magasin. */
export async function addNote(_prev: NoteFormState, formData: FormData): Promise<NoteFormState> {
  const refus = await controleRole();
  if (refus) return { error: refus, ok: false };

  const clientId = String(formData.get('clientId') ?? '');
  const remarque = String(formData.get('remarque') ?? '').trim();

  if (!estUuid(clientId)) return { error: 'Client invalide.', ok: false };
  if (!remarque) return { error: 'La note est vide.', ok: false };

  const error = await muter(`/clients/${encodeURIComponent(clientId)}/notes`, 'POST', { remarque });
  if (error) return { error, ok: false };

  revalidatePath(`/clients/${clientId}`);
  return { error: null, ok: true };
}

/** Supprime (logiquement) une note terrain. */
export async function deleteNote(_prev: ActionState, formData: FormData): Promise<ActionState> {
  const refus = await controleRole();
  if (refus) return { error: refus };

  const clientId = String(formData.get('clientId') ?? '');
  const noteId = String(formData.get('noteId') ?? '');
  if (!estUuid(clientId) || !estUuid(noteId)) return { error: 'Identifiant invalide.' };

  const error = await muter(
    `/clients/${encodeURIComponent(clientId)}/notes/${encodeURIComponent(noteId)}`,
    'DELETE',
  );
  if (error) return { error };

  revalidatePath(`/clients/${clientId}`);
  return { error: null };
}

/** Définit la périodicité de visite du magasin (valeur vide = aucune). */
export async function setPeriodicite(formData: FormData): Promise<ActionState> {
  const refus = await controleRole();
  if (refus) return { error: refus };

  const clientId = String(formData.get('clientId') ?? '');
  const periodiciteId = String(formData.get('periodiciteId') ?? '').trim() || null;
  if (!estUuid(clientId)) return { error: 'Client invalide.' };
  if (periodiciteId && !estUuid(periodiciteId)) return { error: 'Périodicité invalide.' };

  const error = await muter(`/clients/${encodeURIComponent(clientId)}/periodicite`, 'PATCH', { periodiciteId });
  if (error) return { error };

  revalidatePath(`/clients/${clientId}`);
  return { error: null };
}
