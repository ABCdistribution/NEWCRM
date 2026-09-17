'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { serverFetch, type ProspectStatut } from './api';

export type ProspectFormState = { error: string | null };

/** Nombre optionnel depuis un champ de formulaire (virgule ou point acceptés). */
function optNum(v: FormDataEntryValue | null): number | undefined {
  const s = String(v ?? '').trim().replace(',', '.');
  if (s === '') return undefined;
  const n = Number(s);
  return Number.isFinite(n) ? n : undefined;
}

function optStr(v: FormDataEntryValue | null): string | undefined {
  const s = String(v ?? '').trim();
  return s === '' ? undefined : s;
}

/** Crée un prospect (POST /prospects) puis redirige vers sa fiche. */
export async function createProspect(
  _prev: ProspectFormState,
  formData: FormData,
): Promise<ProspectFormState> {
  const raisonSociale = String(formData.get('raisonSociale') ?? '').trim();
  const enseigne = String(formData.get('enseigne') ?? '').trim();
  if (!raisonSociale || !enseigne) {
    return { error: 'La raison sociale et l’enseigne sont obligatoires.' };
  }

  const payload = {
    raisonSociale,
    enseigne,
    adresse1: optStr(formData.get('adresse1')),
    codePostal: optStr(formData.get('codePostal')),
    ville: optStr(formData.get('ville')),
    telephone: optStr(formData.get('telephone')),
    email: optStr(formData.get('email')),
    secteurId: optStr(formData.get('secteurId')),
    statut: optStr(formData.get('statut')) ?? 'NOUVEAU',
    source: optStr(formData.get('source')),
    niveauClass: optStr(formData.get('niveauClass')),
    probabilite: optNum(formData.get('probabilite')),
    potentielCaAnnuel: optNum(formData.get('potentielCaAnnuel')),
  };

  let res: Response;
  try {
    res = await serverFetch('/prospects', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).` };
  }

  const created = (await res.json().catch(() => null)) as { id?: string } | null;
  revalidatePath('/pilotage/prospects');
  redirect(created?.id ? `/pilotage/prospects/${created.id}` : '/pilotage/prospects');
}

/** Change l'étape d'un prospect (PATCH /prospects/:id) — utilisé par le Kanban. */
export async function setProspectStatut(
  id: string,
  statut: ProspectStatut,
): Promise<{ error: string | null }> {
  if (!id || !statut) return { error: 'Paramètres manquants.' };
  try {
    const res = await serverFetch(`/prospects/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ statut }),
    });
    if (!res.ok) return { error: `Erreur serveur (${res.status}).` };
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  revalidatePath('/pilotage/prospects');
  return { error: null };
}

/** Met à jour un ou plusieurs champs d'un prospect (fiche). */
export async function updateProspect(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  const payload: Record<string, unknown> = {};
  for (const k of ['statut', 'source', 'motifPerte', 'assignedToId', 'secteurId'] as const) {
    if (formData.has(k)) payload[k] = optStr(formData.get(k)) ?? null;
  }
  for (const k of ['probabilite', 'potentielCaAnnuel'] as const) {
    if (formData.has(k)) payload[k] = optNum(formData.get(k)) ?? null;
  }
  await serverFetch(`/prospects/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  }).catch(() => undefined);
  revalidatePath(`/pilotage/prospects/${id}`);
  revalidatePath('/pilotage/prospects');
}

/** Convertit un prospect gagné en client (POST /prospects/:id/convert). */
export async function convertProspect(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  const res = await serverFetch(`/prospects/${id}/convert`, { method: 'POST' }).catch(() => null);
  const body = (await res?.json().catch(() => null)) as { clientId?: string } | null;
  revalidatePath('/pilotage/prospects');
  if (body?.clientId) redirect(`/pilotage/clients/${body.clientId}`);
  redirect(`/pilotage/prospects/${id}`);
}


/** Journalise un appel lancé depuis la fiche (bouton « Appeler »). */
export async function logAppelFiche(prospectId: string): Promise<void> {
  await serverFetch(`/prospects/${prospectId}/appels`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ commentaire: 'Appel lancé depuis la fiche Helios.' }),
  }).catch(() => undefined);
  revalidatePath(`/pilotage/prospects/${prospectId}`);
}

/** Journalise un email lancé depuis la fiche (bouton « Envoyer un mail »). */
export async function logEmailFiche(prospectId: string, destinataire: string): Promise<void> {
  await serverFetch(`/prospects/${prospectId}/emails`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ destinataire, commentaire: 'Email lancé depuis la fiche Helios.' }),
  }).catch(() => undefined);
  revalidatePath(`/pilotage/prospects/${prospectId}`);
}

/** Change l'étape depuis le stepper de la fiche — journalisé dans la timeline. */
export async function changerEtapeFiche(
  id: string,
  statut: ProspectStatut,
  motifPerte?: string,
): Promise<{ error: string | null }> {
  let res: Response;
  try {
    res = await serverFetch(`/prospects/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ statut, ...(motifPerte ? { motifPerte } : {}) }),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).` };
  }
  revalidatePath(`/pilotage/prospects/${id}`);
  revalidatePath('/pilotage/prospects');
  return { error: null };
}

/** Ajoute une note à la fiche — visible dans la timeline. */
export async function addNoteFiche(id: string, remarque: string): Promise<{ error: string | null }> {
  if (!remarque.trim()) return { error: 'La note est vide.' };
  let res: Response;
  try {
    res = await serverFetch(`/prospects/${id}/notes`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ remarque }),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) return { error: `Erreur serveur (${res.status}).` };
  revalidatePath(`/pilotage/prospects/${id}`);
  return { error: null };
}

/** Met à jour les coordonnées de la fiche (adresse, téléphone, email). */
export async function updateCoordonneesFiche(
  id: string,
  coords: { adresse1?: string; codePostal?: string; ville?: string; telephone?: string; email?: string },
): Promise<{ error: string | null }> {
  let res: Response;
  try {
    res = await serverFetch(`/prospects/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(coords),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
    const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
    return { error: msg ?? `Erreur serveur (${res.status}).` };
  }
  revalidatePath(`/pilotage/prospects/${id}`);
  return { error: null };
}
