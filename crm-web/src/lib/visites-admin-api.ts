import { serverFetch } from './api';
import type { QuestionVisite, RaisonAbsenceCommande } from './visites-admin';

async function lireListe<T>(chemin: string): Promise<T[] | null> {
  try {
    const res = await serverFetch(chemin);
    if (!res.ok) return null;
    return (await res.json()) as T[];
  } catch {
    return null;
  }
}

/** Questionnaire de fin de visite, questions inactives comprises (null si l'API est indisponible). */
export function listQuestionnaire(): Promise<QuestionVisite[] | null> {
  return lireListe<QuestionVisite>('/questionnaire?tous=1');
}

/** Raisons d'absence de commande, inactives comprises (null si l'API est indisponible). */
export function listRaisonsAbsence(): Promise<RaisonAbsenceCommande[] | null> {
  return lireListe<RaisonAbsenceCommande>('/raisons-absence-commande?tous=1');
}
