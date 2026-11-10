'use server';

import { qs, serverFetch } from './api';
import { exigerRole, messageRefus } from './roles';
import { assainirPassesInactifs, moisValide, type PassesInactifs } from './clients-inactifs';

export type ReponsePassesInactifs =
  | { data: PassesInactifs; indisponible?: undefined; erreur?: undefined }
  /** L'API ne tient pas encore l'historique des passages en inactif (`disponible: false`). */
  | { indisponible: true; data?: undefined; erreur?: undefined }
  | { erreur: string; data?: undefined; indisponible?: undefined };

const ROLES = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR', 'ADV'] as const;

/**
 * Clients passés inactifs sur un mois : `GET /clients/passes-inactifs?mois=AAAA-MM`. La garde de rôle est rappelée ici
 * comme sur chaque action ; le périmètre (DR : sa région, CS : ses promoteurs) est borné par l'API, rien n'est filtré
 * ici. Tant que l'API répond `disponible: false` (historique non enregistré), la réponse est « indisponible » : le modal
 * l'annonce au lieu d'une liste vide trompeuse.
 */
export async function chargerPassesInactifs(mois: string): Promise<ReponsePassesInactifs> {
  try {
    await exigerRole(ROLES);
  } catch (e) {
    return { erreur: messageRefus(e, 'Accès refusé.') };
  }
  if (!moisValide(mois)) return { erreur: 'Mois invalide.' };

  let res: Response;
  try {
    res = await serverFetch(`/clients/passes-inactifs${qs({ mois })}`);
  } catch {
    return { erreur: "L'historique est indisponible : l'API ne répond pas." };
  }
  if (res.status === 403) return { erreur: "Vous n'avez pas accès à cet historique." };
  if (!res.ok) return { erreur: `L'historique est indisponible (erreur ${res.status}).` };
  try {
    const data = assainirPassesInactifs(await res.json());
    return data.disponible ? { data } : { indisponible: true };
  } catch {
    return { erreur: "L'historique a renvoyé une réponse illisible." };
  }
}
