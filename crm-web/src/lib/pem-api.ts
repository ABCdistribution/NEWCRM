import { serverFetch } from './api';
import { estUuid, lirePropositionOuverte, lireReponseFrequences, type FrequencesPem, type PropositionPem } from './pem';

/** Proposition de visite PEM ouverte d'un magasin (null si aucune, id invalide ou API indisponible). */
export async function getPropositionOuverte(clientId: string): Promise<PropositionPem | null> {
  if (!estUuid(clientId)) return null;
  try {
    const res = await serverFetch(`/pem/propositions?clientId=${encodeURIComponent(clientId)}`);
    if (!res.ok) return null;
    return lirePropositionOuverte(await res.json());
  } catch {
    return null;
  }
}

/** Fréquence des visites PEM par classe (null si l'API est indisponible ou répond autre chose). */
export async function getFrequencesPem(): Promise<FrequencesPem | null> {
  try {
    const res = await serverFetch('/pem/frequences');
    if (!res.ok) return null;
    return lireReponseFrequences(await res.json());
  } catch {
    return null;
  }
}
