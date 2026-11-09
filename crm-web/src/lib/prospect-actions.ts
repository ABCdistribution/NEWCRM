'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { PROSPECT_STATUTS, serverFetch, type ProspectStatut } from './api';
import { ENCADREMENT, exigerRole, messageRefus, type Role } from './roles';
import { PROSPECTS_ECRITURE } from './prospect-roles';
import { estMotifPerte } from './prospect-motifs';
import { estUuid } from './equipe-utils';
import { adresseMail } from './contact-liens';
import { messageErreurApi } from './erreurs-api';

// Toutes les actions de la Direction commerciale rappellent leur contrôle de rôle (un layout ne protège pas
// les Server Actions). Le périmètre (secteur / région) reste décidé par l'API.
//
// Deux niveaux, alignés sur l'API :
//  - verifierAcces()   : tout l'encadrement (DIRECTION compris) — lecture, notes, appels, emails, pièces jointes ;
//  - verifierEcriture(): ADMIN, DIRECTEUR_REGIONAL, CHEF_SECTEUR — création, étape, coordonnées, conversion
//    (DIRECTION est en lecture seule sur ces routes, voir prospect-roles.ts).

export type ProspectFormState = { error: string | null };
type Resultat = { error: string | null };

const ERR_ACCES = 'Accès refusé (rôle insuffisant ou session expirée).';
const ERR_ID = 'Identifiant de prospect invalide.';
const ERR_API = "Impossible de joindre l'API.";

/** Rôle exigé parmi `roles` ; renvoie un message d'erreur sinon (exigerRole lève aussi sans session). */
async function verifier(roles: readonly Role[]): Promise<string | null> {
  try {
    await exigerRole(roles);
    return null;
  } catch (e) {
    return messageRefus(e, ERR_ACCES);
  }
}

/** Rôle encadrement exigé ; renvoie un message d'erreur sinon. */
const verifierAcces = () => verifier(ENCADREMENT);

/** Rôle autorisé à écrire sur les prospects (hors DIRECTION) ; renvoie un message d'erreur sinon. */
const verifierEcriture = () => verifier(PROSPECTS_ECRITURE);

/** Message d'erreur affichable pour une réponse d'API en échec (401, 5xx, validation traduite : erreurs-api.ts). */
const messageErreur = (res: Response): Promise<string> => messageErreurApi(res, 'prospects');

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
  const refus = await verifierEcriture();
  if (refus) return { error: refus };

  const raisonSociale = String(formData.get('raisonSociale') ?? '').trim();
  const enseigne = String(formData.get('enseigne') ?? '').trim();
  if (!raisonSociale || !enseigne) {
    return { error: 'La raison sociale et l’enseigne sont obligatoires.' };
  }
  // Le secteur vient d'une liste fournie par l'API ; un identifiant mal formé n'a aucune raison d'arriver ici.
  // (L'appartenance du secteur au périmètre de l'appelant est à vérifier côté API.)
  const secteurId = optStr(formData.get('secteurId'));
  if (secteurId && !estUuid(secteurId)) return { error: 'Secteur invalide.' };

  const payload = {
    raisonSociale,
    enseigne,
    adresse1: optStr(formData.get('adresse1')),
    codePostal: optStr(formData.get('codePostal')),
    ville: optStr(formData.get('ville')),
    telephone: optStr(formData.get('telephone')),
    email: optStr(formData.get('email')),
    secteurId,
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

/**
 * Convertit un prospect gagné en client (POST /prospects/:id/convert).
 * Action de formulaire : en cas d'échec, on revient sur la fiche avec ?erreur=… (affichée par la page) :
 * `role` (rôle sans droit d'écriture : refus local ou 403 de l'API) ou `conversion` (autre échec).
 */
export async function convertProspect(formData: FormData): Promise<void> {
  const id = String(formData.get('id') ?? '');
  if (!estUuid(id)) redirect('/prospects');
  const refus = await verifierEcriture();
  if (refus) redirect(`/prospects/${id}?erreur=role`);
  let clientId: string | undefined;
  let ok = false;
  let interdit = false;
  try {
    const res = await serverFetch(`/prospects/${encodeURIComponent(id)}/convert`, { method: 'POST' });
    ok = res.ok;
    interdit = res.status === 403;
    if (ok) clientId = ((await res.json().catch(() => null)) as { clientId?: string } | null)?.clientId;
  } catch {
    ok = false;
  }
  revalidatePath('/prospects');
  if (!ok) redirect(`/prospects/${id}?erreur=${interdit ? 'role' : 'conversion'}`);
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

/**
 * Journalise un email lancé depuis la fiche (bouton « Envoyer un mail »). L'adresse journalisée est celle de la
 * fiche prospect, lue ici côté serveur : on n'accepte pas d'adresse venant du navigateur (le journal de contacts
 * ne doit pas être falsifiable).
 */
export async function logEmailFiche(prospectId: string): Promise<Resultat> {
  const refus = await verifierAcces();
  if (refus) return { error: refus };
  if (!estUuid(prospectId)) return { error: ERR_ID };
  try {
    const lecture = await serverFetch(`/prospects/${encodeURIComponent(prospectId)}`);
    if (!lecture.ok) return { error: await messageErreur(lecture) };
    const prospect = (await lecture.json().catch(() => null)) as { email?: string | null } | null;
    const destinataire = adresseMail(prospect?.email);
    if (!destinataire) return { error: "Ce prospect n'a pas d'adresse email valide." };
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

/**
 * Change l'étape d'un prospect (PATCH /prospects/:id) — journalisé dans la timeline.
 * Action unique pour le stepper de la fiche ET le Kanban. Le passage en PERDU exige un motif (l'API le refuse
 * sinon, sauf si la fiche en porte déjà un) : les deux écrans le demandent avant d'appeler cette action.
 */
export async function changerEtapeFiche(id: string, statut: ProspectStatut, motifPerte?: string): Promise<Resultat> {
  const refus = await verifierEcriture();
  if (refus) return { error: refus };
  if (!estUuid(id)) return { error: ERR_ID };
  if (!PROSPECT_STATUTS.includes(statut)) return { error: 'Étape invalide.' };
  if (motifPerte !== undefined && !estMotifPerte(motifPerte)) return { error: 'Motif de perte invalide.' };
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

/** Coordonnées modifiables depuis la fiche, avec la longueur maximale acceptée par l'API (UpdateProspectDto). */
const COORDONNEES: readonly { cle: 'adresse1' | 'codePostal' | 'ville' | 'telephone' | 'email'; libelle: string; max: number }[] = [
  { cle: 'adresse1', libelle: 'Adresse', max: 200 },
  { cle: 'codePostal', libelle: 'Code postal', max: 10 },
  { cle: 'ville', libelle: 'Ville', max: 100 },
  { cle: 'telephone', libelle: 'Téléphone', max: 20 },
  { cle: 'email', libelle: 'Email', max: 200 },
];

/** Met à jour les coordonnées de la fiche (adresse, téléphone, email). */
export async function updateCoordonneesFiche(
  id: string,
  coords: { adresse1?: string; codePostal?: string; ville?: string; telephone?: string; email?: string },
): Promise<Resultat> {
  const refus = await verifierEcriture();
  if (refus) return { error: refus };
  if (!estUuid(id)) return { error: ERR_ID };
  // Liste blanche : le typage TypeScript disparaît à l'exécution, un appel forgé ne doit pas pouvoir glisser
  // d'autres champs (secteurId, assignedToId, statut…) dans le PATCH. Le payload est construit champ par champ.
  if (!coords || typeof coords !== 'object') return { error: 'Coordonnées invalides.' };
  const payload: Record<string, string> = {};
  for (const { cle, libelle, max } of COORDONNEES) {
    const v = coords[cle];
    if (v === undefined) continue;
    if (typeof v !== 'string') return { error: `Champ « ${libelle} » invalide.` };
    const valeur = v.trim();
    if (valeur.length > max) return { error: `Champ « ${libelle} » trop long (${max} caractères maximum).` };
    payload[cle] = valeur;
  }
  let res: Response;
  try {
    res = await serverFetch(`/prospects/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: JSON_HEADERS,
      body: JSON.stringify(payload),
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
