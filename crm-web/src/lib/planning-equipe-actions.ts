'use server';

// Planning des promoteurs géré par l'encadrement (ADMIN, DIRECTION, DR, CS) : visites jour par jour,
// règles de récurrence, relance d'une visite manquée. Appels API côté serveur uniquement ;
// le périmètre (promoteurs de mon équipe) est décidé par l'API.
import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';
import { estUuid } from './equipe-utils';
import { messageErreurApi } from './erreurs-api';
import { ENCADREMENT, exigerRole, messageRefus } from './roles';

export type ResultatPlanning = { error: string | null };

const PAGE = '/planning-equipe';
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** Message utilisateur (français) d'une réponse API en échec. */
async function messageErreur(res: Response): Promise<string> {
  if (res.status === 403 || res.status === 404) return "Ce promoteur n'est pas dans votre équipe (ou l'élément n'existe plus).";
  return messageErreurApi(res, 'planning-equipe');
}

async function envoyer(
  chemin: string,
  method: 'POST' | 'PATCH' | 'DELETE',
  corps?: unknown,
  revalider = true,
): Promise<ResultatPlanning> {
  try {
    await exigerRole(ENCADREMENT);
  } catch (e) {
    return { error: messageRefus(e, 'Accès refusé : action réservée à l’encadrement.') };
  }
  let res: Response;
  try {
    res = await serverFetch(chemin, {
      method,
      ...(corps !== undefined ? { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(corps) } : {}),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) return { error: await messageErreur(res) };
  if (revalider) revalidatePath(PAGE);
  return { error: null };
}

/** Planifie une visite chez un client pour un promoteur de mon équipe. */
export async function ajouterVisite(promoteurId: string, clientId: string, datePassage: string): Promise<ResultatPlanning> {
  if (!estUuid(promoteurId)) return { error: 'Promoteur invalide.' };
  if (!estUuid(clientId)) return { error: 'Choisissez un client.' };
  if (!DATE_RE.test(datePassage)) return { error: 'Date invalide.' };
  return envoyer('/plannings', 'POST', { promoteurId, clientId, datePassage });
}

/** Déplace une visite vers un autre jour. */
export async function deplacerVisite(id: string, datePassage: string): Promise<ResultatPlanning> {
  if (!estUuid(id)) return { error: 'Visite invalide.' };
  if (!DATE_RE.test(datePassage)) return { error: 'Date invalide.' };
  return envoyer(`/plannings/${encodeURIComponent(id)}`, 'PATCH', { datePassage });
}

/** Retire une visite planifiée. */
export async function supprimerVisite(id: string): Promise<ResultatPlanning> {
  if (!estUuid(id)) return { error: 'Visite invalide.' };
  return envoyer(`/plannings/${encodeURIComponent(id)}`, 'DELETE');
}

/** Relance le promoteur d'une visite manquée (notification in-app / mobile). */
export async function relancerVisite(planningId: string): Promise<ResultatPlanning> {
  if (!estUuid(planningId)) return { error: 'Visite invalide.' };
  return envoyer('/notifications/relance', 'POST', { planningId }, false);
}

/** Crée une règle de récurrence (client × jours ISO 1..6 × fréquence en semaines). */
export async function creerRegle(input: {
  promoteurId: string;
  clientId: string;
  jours: number[];
  recurrence: number;
  dateDebut: string;
}): Promise<ResultatPlanning> {
  if (!estUuid(input.promoteurId)) return { error: 'Promoteur invalide.' };
  if (!estUuid(input.clientId)) return { error: 'Choisissez un client.' };
  const jours = [...new Set(input.jours)].filter((n) => Number.isInteger(n) && n >= 1 && n <= 6);
  if (jours.length === 0) return { error: 'Cochez au moins un jour.' };
  if (!Number.isInteger(input.recurrence) || input.recurrence < 1 || input.recurrence > 4) {
    return { error: 'Fréquence invalide.' };
  }
  if (!DATE_RE.test(input.dateDebut)) return { error: 'Date invalide.' };
  return envoyer('/plannifications', 'POST', {
    promoteurId: input.promoteurId,
    clientId: input.clientId,
    jours,
    recurrence: input.recurrence,
    dateDebut: input.dateDebut,
  });
}

/** Supprime une règle de récurrence (et ses occurrences futures non faites). */
export async function supprimerRegle(id: string): Promise<ResultatPlanning> {
  if (!estUuid(id)) return { error: 'Règle invalide.' };
  return envoyer(`/plannifications/${encodeURIComponent(id)}`, 'DELETE');
}
