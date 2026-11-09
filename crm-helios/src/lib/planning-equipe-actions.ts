'use server';

// Planning des promoteurs géré par l'encadrement (DR, CS, direction, admin).
// Appels API côté serveur uniquement ; les droits (périmètre) restent décidés par l'API.
import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';
import { estUuid } from './equipe-utils';

export type ResultatPlanning = { error: string | null };

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** Message utilisateur (français) d'une réponse API en échec. */
async function messageErreur(res: Response): Promise<string> {
  if (res.status === 401) return 'Session expirée : reconnectez-vous.';
  if (res.status === 403 || res.status === 404) return "Ce promoteur n'est pas dans votre équipe (ou la visite n'existe plus).";
  const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
  const msg = Array.isArray(body?.message) ? body.message[0] : body?.message;
  return msg ?? `Erreur serveur (${res.status}).`;
}

async function envoyer(chemin: string, method: 'POST' | 'PATCH' | 'DELETE', corps?: unknown): Promise<ResultatPlanning> {
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
  revalidatePath('/pilotage/planning-equipe');
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
