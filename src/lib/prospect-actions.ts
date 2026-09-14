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
  revalidatePath('/prospects');
  redirect(created?.id ? `/prospects/${created.id}` : '/prospects');
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
  revalidatePath('/prospects');
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
  revalidatePath(`/prospects/${id}`);
  revalidatePath('/prospects');
}

/** Convertit un prospect gagné en client (POST /prospects/:id/convert). */
export async function convertProspect(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!id) return;
  const res = await serverFetch(`/prospects/${id}/convert`, { method: 'POST' }).catch(() => null);
  const body = (await res?.json().catch(() => null)) as { clientId?: string } | null;
  revalidatePath('/prospects');
  if (body?.clientId) redirect(`/clients/${body.clientId}`);
  redirect(`/prospects/${id}`);
}
