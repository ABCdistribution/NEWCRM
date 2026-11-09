'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { serverFetch, type ProspectStatut } from './api';
import { ENCADREMENT, exigerRole } from './roles';
import { estUuid } from './equipe-utils';

// Toutes les actions de la Direction commerciale rappellent leur contrôle de rôle (un layout ne protège pas
// les Server Actions). Le périmètre (secteur / région) reste décidé par l'API.

export type ProspectFormState = { error: string | null };
type Resultat = { error: string | null };

const ERR_ACCES = 'Accès refusé.';
const ERR_ID = 'Identifiant de prospect invalide.';
const ERR_API = "Impossible de joindre l'API.";

/** Rôle encadrement exigé ; renvoie un message d'erreur sinon. */
async function verifierAcces(): Promise<string | null> {
  try {
    await exigerRole(ENCADREMENT);
    return null;
  } catch {
    return ERR_ACCES;
  }
}

/** Message d'erreur de l'API (premier message de validation) ou texte par défaut. */
async function messageErreur(res: Response): Promise<string> {
  const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
  const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
  return msg ?? `Erreur serveur (${res.status}).`;
}

const JSON_HEADERS = { 'Content-Type': 'application/json' };

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
  const refus = await verifierAcces();
  if (refus) return { error: refus };

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
    res = await serverFetch('/prospects', { method: 'POST', headers: JSON_HEADERS, body: JSON.stringify(payload) });
  } catch {
    return { error: ERR_API };
  }
  if (!res.ok) return { error: await messageErreur(res) };

  const created = (await res.json().catch(() => null)) as { id?: string } | null;
  revalidatePath('/prospects');
  redirect(created?.id && estUuid(created.id) ? `/prospects/${created.id}` : '/prospects');
}

/** Change l'étape d'un prospect (PATCH /prospects/:id) — utilisé par le Kanban. */
export async function setProspectStatut(id: string, statut: ProspectStatut): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  if (!estUuid(id)) return { error: ERR_ID };
  if (!statut) return { error: 'Paramètres manquants.' };
  try {
    const res = await serverFetch(`/prospects/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: JSON_HEADERS,
      body: JSON.stringify({ statut }),
    });
    if (!res.ok) return { error: await messageErreur(res) };
  } catch {
    return { error: ERR_API };
  }
  revalidatePath('/prospects');
  return { error: null };
}

/** Met à jour un ou plusieurs champs d'un prospect (fiche). Renvoie un message d'erreur en cas d'échec. */
export async function updateProspect(formData: FormData): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  const id = String(formData.get('id') ?? '');
  if (!estUuid(id)) return { error: ERR_ID };
  const payload: Record<string, unknown> = {};
  for (const k of ['statut', 'source', 'motifPerte', 'assignedToId', 'secteurId'] as const) {
    if (formData.has(k)) payload[k] = optStr(formData.get(k)) ?? null;
  }
  for (const k of ['probabilite', 'potentielCaAnnuel'] as const) {
    if (formData.has(k)) payload[k] = optNum(formData.get(k)) ?? null;
  }
  try {
    const res = await serverFetch(`/prospects/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: JSON_HEADERS,
      body: JSON.stringify(payload),
    });
    if (!res.ok) return { error: await messageErreur(res) };
  } catch {
    return { error: ERR_API };
  }
  revalidatePath(`/prospects/${id}`);
  revalidatePath('/prospects');
  return { error: null };
}

/**
 * Convertit un prospect gagné en client (POST /prospects/:id/convert).
 * Action de formulaire : en cas d'échec, on revient sur la fiche avec ?erreur=conversion (affichée par la page).
 */
export async function convertProspect(formData: FormData): Promise<void> {
  const refus = await verifierAcces();
  if (refus) redirect('/prospects');
  const id = String(formData.get('id') ?? '');
  if (!estUuid(id)) redirect('/prospects');
  let clientId: string | undefined;
  let ok = false;
  try {
    const res = await serverFetch(`/prospects/${encodeURIComponent(id)}/convert`, { method: 'POST' });
    ok = res.ok;
    if (ok) clientId = ((await res.json().catch(() => null)) as { clientId?: string } | null)?.clientId;
  } catch {
    ok = false;
  }
  revalidatePath('/prospects');
  if (!ok) redirect(`/prospects/${id}?erreur=conversion`);
  if (clientId && estUuid(clientId)) redirect(`/clients/${clientId}`);
  redirect(`/prospects/${id}`);
}

/** Journalise un appel lancé depuis la fiche (bouton « Appeler »). */
export async function logAppelFiche(prospectId: string): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  if (!estUuid(prospectId)) return { error: ERR_ID };
  try {
    const res = await serverFetch(`/prospects/${encodeURIComponent(prospectId)}/appels`, {
      method: 'POST',
      headers: JSON_HEADERS,
      body: JSON.stringify({ commentaire: 'Appel lancé depuis la fiche Direction commerciale.' }),
    });
    if (!res.ok) return { error: await messageErreur(res) };
  } catch {
    return { error: ERR_API };
  }
  revalidatePath(`/prospects/${prospectId}`);
  return { error: null };
}

/** Journalise un email lancé depuis la fiche (bouton « Envoyer un mail »). */
export async function logEmailFiche(prospectId: string, destinataire: string): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  if (!estUuid(prospectId)) return { error: ERR_ID };
  try {
    const res = await serverFetch(`/prospects/${encodeURIComponent(prospectId)}/emails`, {
      method: 'POST',
      headers: JSON_HEADERS,
      body: JSON.stringify({ destinataire, commentaire: 'Email lancé depuis la fiche Direction commerciale.' }),
    });
    if (!res.ok) return { error: await messageErreur(res) };
  } catch {
    return { error: ERR_API };
  }
  revalidatePath(`/prospects/${prospectId}`);
  return { error: null };
}

/** Change l'étape depuis le stepper de la fiche — journalisé dans la timeline. */
export async function changerEtapeFiche(id: string, statut: ProspectStatut, motifPerte?: string): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  if (!estUuid(id)) return { error: ERR_ID };
  let res: Response;
  try {
    res = await serverFetch(`/prospects/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: JSON_HEADERS,
      body: JSON.stringify({ statut, ...(motifPerte ? { motifPerte } : {}) }),
    });
  } catch {
    return { error: ERR_API };
  }
  if (!res.ok) return { error: await messageErreur(res) };
  revalidatePath(`/prospects/${id}`);
  revalidatePath('/prospects');
  return { error: null };
}

/** Ajoute une note à la fiche — visible dans la timeline. */
export async function addNoteFiche(id: string, remarque: string): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  if (!estUuid(id)) return { error: ERR_ID };
  if (!remarque.trim()) return { error: 'La note est vide.' };
  let res: Response;
  try {
    res = await serverFetch(`/prospects/${encodeURIComponent(id)}/notes`, {
      method: 'POST',
      headers: JSON_HEADERS,
      body: JSON.stringify({ remarque }),
    });
  } catch {
    return { error: ERR_API };
  }
  if (!res.ok) return { error: await messageErreur(res) };
  revalidatePath(`/prospects/${id}`);
  return { error: null };
}

/** Met à jour les coordonnées de la fiche (adresse, téléphone, email). */
export async function updateCoordonneesFiche(
  id: string,
  coords: { adresse1?: string; codePostal?: string; ville?: string; telephone?: string; email?: string },
): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  if (!estUuid(id)) return { error: ERR_ID };
  let res: Response;
  try {
    res = await serverFetch(`/prospects/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: JSON_HEADERS,
      body: JSON.stringify(coords),
    });
  } catch {
    return { error: ERR_API };
  }
  if (!res.ok) return { error: await messageErreur(res) };
  revalidatePath(`/prospects/${id}`);
  return { error: null };
}

export type PieceJointe = {
  id: string;
  nom: string;
  mime: string;
  taille: number;
  createdAt: string;
  auteur: { displayName: string } | null;
};

/** Pièces jointes de la fiche prospect (null si indisponible ou accès refusé). */
export async function listPiecesJointes(prospectId: string): Promise<PieceJointe[] | null> {
  if (await verifierAcces()) return null;
  if (!estUuid(prospectId)) return null;
  try {
    const res = await serverFetch(`/prospects/${encodeURIComponent(prospectId)}/pieces-jointes`);
    if (!res.ok) return null;
    return (await res.json()) as PieceJointe[];
  } catch {
    return null;
  }
}

/** Dépose une pièce jointe (FormData avec le champ « fichier »). */
export async function uploadPieceJointe(prospectId: string, formData: FormData): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  if (!estUuid(prospectId)) return { error: ERR_ID };
  const fichier = formData.get('fichier');
  if (!(fichier instanceof File) || fichier.size === 0) return { error: 'Aucun fichier sélectionné.' };
  if (fichier.size > 10 * 1024 * 1024) return { error: 'Fichier trop volumineux (10 Mo maximum).' };
  let res: Response;
  try {
    res = await serverFetch(`/prospects/${encodeURIComponent(prospectId)}/pieces-jointes`, { method: 'POST', body: formData });
  } catch {
    return { error: ERR_API };
  }
  if (!res.ok) return { error: await messageErreur(res) };
  revalidatePath(`/prospects/${prospectId}`);
  return { error: null };
}

/** Supprime une pièce jointe de la fiche. */
export async function deletePieceJointe(prospectId: string, pjId: string): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  if (!estUuid(prospectId) || !estUuid(pjId)) return { error: ERR_ID };
  let res: Response;
  try {
    res = await serverFetch(
      `/prospects/${encodeURIComponent(prospectId)}/pieces-jointes/${encodeURIComponent(pjId)}`,
      { method: 'DELETE' },
    );
  } catch {
    return { error: ERR_API };
  }
  if (!res.ok) return { error: 'Suppression impossible.' };
  revalidatePath(`/prospects/${prospectId}`);
  return { error: null };
}
