'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';
import { exigerRole, messageRefus } from './roles';
import { messageErreurApi } from './erreurs-api';
import {
  LONGUEUR_QUESTION,
  LONGUEUR_RAISON,
  controlerLibelle,
  directionValide,
  typeQuestionValide,
} from './visites-admin';

/** Administration des visites (questionnaire, raisons d'absence de commande) : ADMIN seul. */
const ADMIN = ['ADMIN'] as const;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REFUSE = 'Accès refusé : action réservée aux administrateurs.';
const INJOIGNABLE = "Impossible de joindre l'API.";

/**
 * Appel d'API commun : garde de rôle, id validé (UUID) puis encodé, statut vérifié.
 * Renvoie un message d'erreur en français, ou null en cas de succès.
 */
async function appeler(
  base: string,
  id: string | null,
  suffixe: string,
  method: 'POST' | 'PATCH' | 'DELETE',
  corps: Record<string, unknown> | null,
  contexte: string,
): Promise<string | null> {
  try {
    await exigerRole(ADMIN);
  } catch (e) {
    return messageRefus(e, REFUSE);
  }
  if (id !== null && !UUID.test(id)) return 'Élément invalide.';
  const chemin = `${base}${id !== null ? `/${encodeURIComponent(id)}` : ''}${suffixe}`;
  let res: Response;
  try {
    res = await serverFetch(chemin, {
      method,
      ...(corps ? { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(corps) } : {}),
    });
  } catch {
    return INJOIGNABLE;
  }
  if (!res.ok) return messageErreurApi(res, `admin visites : ${contexte}`);
  revalidatePath('/admin');
  return null;
}

const champ = (fd: FormData, nom: string): string => String(fd.get(nom) ?? '');
/** Case à cocher d'un formulaire : « on » (case native) ou « true ». */
const coche = (fd: FormData, nom: string): boolean => ['on', 'true'].includes(champ(fd, nom));

// --- Questionnaire de fin de visite -----------------------------------------------------------

const Q = '/questionnaire/questions';

export async function ajouterQuestion(formData: FormData): Promise<string | null> {
  const { libelle, erreur } = controlerLibelle(champ(formData, 'libelle'), LONGUEUR_QUESTION);
  if (erreur) return erreur;
  const type = champ(formData, 'type') || 'CASE_A_COCHER';
  if (!typeQuestionValide(type)) return 'Type de question invalide.';
  return appeler(Q, null, '', 'POST', { libelle, type, obligatoire: coche(formData, 'obligatoire') }, 'ajout d’une question');
}

/** Modifie les seuls champs présents dans le formulaire (libellé, type, obligatoire, actif). */
export async function modifierQuestion(formData: FormData): Promise<string | null> {
  const corps: Record<string, unknown> = {};
  if (formData.has('libelle')) {
    const { libelle, erreur } = controlerLibelle(champ(formData, 'libelle'), LONGUEUR_QUESTION);
    if (erreur) return erreur;
    corps.libelle = libelle;
  }
  if (formData.has('type')) {
    const type = champ(formData, 'type');
    if (!typeQuestionValide(type)) return 'Type de question invalide.';
    corps.type = type;
  }
  if (formData.has('obligatoire')) corps.obligatoire = coche(formData, 'obligatoire');
  if (formData.has('actif')) corps.actif = coche(formData, 'actif');
  if (Object.keys(corps).length === 0) return 'Aucune modification à enregistrer.';
  return appeler(Q, champ(formData, 'id'), '', 'PATCH', corps, 'modification d’une question');
}

export async function deplacerQuestion(formData: FormData): Promise<string | null> {
  const direction = champ(formData, 'direction');
  if (!directionValide(direction)) return 'Direction invalide.';
  return appeler(Q, champ(formData, 'id'), '/deplacer', 'POST', { direction }, 'déplacement d’une question');
}

export async function supprimerQuestion(formData: FormData): Promise<string | null> {
  return appeler(Q, champ(formData, 'id'), '', 'DELETE', null, 'suppression d’une question');
}

// --- Raisons d'absence de commande ------------------------------------------------------------

const R = '/raisons-absence-commande';

export async function ajouterRaison(formData: FormData): Promise<string | null> {
  const { libelle, erreur } = controlerLibelle(champ(formData, 'libelle'), LONGUEUR_RAISON);
  if (erreur) return erreur;
  return appeler(R, null, '', 'POST', { libelle }, 'ajout d’une raison');
}

/** Renomme et/ou active-désactive une raison (champs présents seulement). */
export async function modifierRaison(formData: FormData): Promise<string | null> {
  const corps: Record<string, unknown> = {};
  if (formData.has('libelle')) {
    const { libelle, erreur } = controlerLibelle(champ(formData, 'libelle'), LONGUEUR_RAISON);
    if (erreur) return erreur;
    corps.libelle = libelle;
  }
  if (formData.has('actif')) corps.actif = coche(formData, 'actif');
  if (Object.keys(corps).length === 0) return 'Aucune modification à enregistrer.';
  return appeler(R, champ(formData, 'id'), '', 'PATCH', corps, 'modification d’une raison');
}

export async function deplacerRaison(formData: FormData): Promise<string | null> {
  const direction = champ(formData, 'direction');
  if (!directionValide(direction)) return 'Direction invalide.';
  return appeler(R, champ(formData, 'id'), '/deplacer', 'POST', { direction }, 'déplacement d’une raison');
}

export async function supprimerRaison(formData: FormData): Promise<string | null> {
  return appeler(R, champ(formData, 'id'), '', 'DELETE', null, 'suppression d’une raison');
}
