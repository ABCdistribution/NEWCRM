'use server';

import { getClientHistorique, listPlanningsMagasin, serverFetch, type PlanningMagasin } from './api';
import { adresseMail } from './contact-liens';
import { messageErreurApi } from './erreurs-api';
import { ENCADREMENT, exigerRole, messageRefus } from './roles';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

/** Détail de suivi d'un magasin : visites effectuées (historique) + planifiées à venir. Encadrement uniquement. */
export async function getSuiviMagasin(clientId: string): Promise<SuiviMagasin> {
  try {
    await exigerRole(ENCADREMENT);
  } catch {
    return { aVenir: [], effectuees: [], error: true };
  }
  // UUID vérifié ici : idSur (notFound) n'a pas de sens dans une Server Action.
  if (!UUID.test(clientId)) return { aVenir: [], effectuees: [], error: true };

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

/** Message d'erreur français d'une réponse d'API en échec. */
async function messageErreur(res: Response): Promise<string> {
  if (res.status === 403) return "Vous n'avez pas le droit d'effectuer cette action.";
  if (res.status === 404) return 'Client introuvable.';
  return messageErreurApi(res, 'magasins');
}

/** POST d'une mutation sur un client : vérifie rôle, UUID et statut HTTP. */
async function posterSurClient(
  clientId: string,
  sousChemin: string,
  payload: unknown,
): Promise<{ error: string | null }> {
  try {
    await exigerRole(ENCADREMENT);
  } catch (e) {
    return { error: messageRefus(e, 'Accès refusé.') };
  }
  if (!UUID.test(clientId)) return { error: 'Client invalide.' };

  try {
    const res = await serverFetch(`/clients/${encodeURIComponent(clientId)}/${sousChemin}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!res.ok) return { error: await messageErreur(res) };
    return { error: null };
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
}

/** Journalise un appel passé au magasin (bouton « Appeler » de la modale). */
export async function logAppelMagasin(clientId: string): Promise<{ error: string | null }> {
  return posterSurClient(clientId, 'appels', {});
}

/**
 * Journalise un email envoyé au magasin. L'adresse journalisée est celle de la fiche client, lue ici côté
 * serveur : on n'accepte pas d'adresse venant du navigateur (le journal de contacts ne doit pas être falsifiable).
 */
export async function logEmailMagasin(clientId: string): Promise<{ error: string | null }> {
  try {
    await exigerRole(ENCADREMENT);
  } catch (e) {
    return { error: messageRefus(e, 'Accès refusé.') };
  }
  if (!UUID.test(clientId)) return { error: 'Client invalide.' };

  let destinataire: string | null;
  try {
    const res = await serverFetch(`/clients/${encodeURIComponent(clientId)}`);
    if (!res.ok) return { error: await messageErreur(res) };
    destinataire = adresseMail(((await res.json()) as { email?: string | null }).email);
  } catch {
    return { error: "Impossible de joindre l'API." };
  }
  if (!destinataire) return { error: "Ce client n'a pas d'adresse email valide." };
  return posterSurClient(clientId, 'emails', { destinataire });
}

/** Enregistre le questionnaire de visite commerciale d'un magasin. Encadrement uniquement. */
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
  return posterSurClient(clientId, 'visites-commerciales', dto);
}
