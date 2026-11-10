'use server';

import { qs, serverFetch } from './api';
import { exigerRole, messageRefus, TOUS_ROLES } from './roles';
import { assainirRecherche, type RechercheGlobale } from './recherche';

export type ReponseRecherche = { data: RechercheGlobale; erreur?: undefined } | { data?: undefined; erreur: string };

const MIN = 2;
const MAX = 80;

/**
 * Recherche générale du bandeau : `GET /search?q=`. Tous les rôles connectés peuvent chercher (la garde est rappelée
 * ici comme sur chaque action) ; ce qu'ils trouvent est borné par rôle ET périmètre côté API, rien n'est filtré ici.
 * Les erreurs sont renvoyées en message français, jamais avalées ni relayées telles quelles.
 */
export async function rechercherGlobal(texte: string): Promise<ReponseRecherche> {
  try {
    await exigerRole(TOUS_ROLES);
  } catch (e) {
    return { erreur: messageRefus(e, 'Accès refusé.') };
  }

  const q = String(texte ?? '').trim().replace(/\s+/g, ' ').slice(0, MAX);
  if (q.length < MIN) return { data: { q, groupes: [] } };

  let res: Response;
  try {
    res = await serverFetch(`/search${qs({ q })}`);
  } catch {
    return { erreur: "La recherche est indisponible : l'API ne répond pas." };
  }
  if (!res.ok) {
    return { erreur: res.status === 403 ? "Vous n'avez pas accès à la recherche." : `La recherche est indisponible (erreur ${res.status}).` };
  }
  try {
    return { data: assainirRecherche(await res.json(), q) };
  } catch {
    return { erreur: 'La recherche a renvoyé une réponse illisible.' };
  }
}
