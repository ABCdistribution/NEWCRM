'use server';

import { getClientHistorique, listPlanningsMagasin, serverFetch, type PlanningMagasin } from './api';

export type SuiviMagasin = {
  aVenir: PlanningMagasin[];
  effectuees: {
    id: string;
    createdAt: string;
    dnAbc: number | null;
    dnConcurrence: number | null;
    pem: boolean;
    promoteur: { displayName: string };
  }[];
  error: boolean;
};

/** Détail de suivi d'un magasin : visites effectuées (historique) + planifiées à venir. */
export async function getSuiviMagasin(clientId: string): Promise<SuiviMagasin> {
  const [historique, aVenir] = await Promise.all([
    getClientHistorique(clientId),
    listPlanningsMagasin(clientId),
  ]);
  return {
    aVenir,
    effectuees: (historique?.visites ?? []).slice(0, 6),
    error: historique === null,
  };
}

/** Journalise un appel passé au magasin (bouton « Appeler » de la modale). */
export async function logAppelMagasin(clientId: string) {
  await serverFetch(`/clients/${clientId}/appels`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
  }).catch(() => null);
}

/** Journalise un email envoyé au magasin. */
export async function logEmailMagasin(clientId: string, destinataire: string) {
  await serverFetch(`/clients/${clientId}/emails`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ destinataire }),
  }).catch(() => null);
}

/** Enregistre le questionnaire de visite commerciale d'un magasin. */
export async function saveVisiteCommerciale(
  clientId: string,
  dto: {
    avecRdv: boolean;
    objets: string[];
    remplissage: string;
    compteRendu: string;
    prochaineVisite?: string;
    reponses: { libelle: string; ok: boolean; remarque?: string }[];
  },
): Promise<{ error: string | null }> {
  let res: Response;
  try {
    res = await serverFetch(`/clients/${clientId}/visites-commerciales`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(dto),
    });
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!res.ok) return { error: `Erreur serveur (${res.status}).` };
  return { error: null };
}
