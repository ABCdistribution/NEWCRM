// Règles de rôle propres à la prospection. Module pur (aucun appel réseau, pas de 'use server') :
// importable côté serveur (pages, Server Actions) comme côté client.
import type { Role } from './api';

/**
 * Rôles autorisés à ÉCRIRE sur les prospects : création, changement d'étape, coordonnées, conversion en client.
 * Même liste que l'API (POST /prospects, PATCH /prospects/:id, POST /prospects/:id/convert) : DIRECTION est en
 * lecture seule sur ces routes (« Direction = lecture globale »). L'API reste l'autorité ; cette liste évite
 * seulement de proposer à DIRECTION des boutons qui répondraient tous 403.
 *
 * Notes, appels, emails et pièces jointes restent ouverts à tout l'encadrement (DIRECTION compris) : l'API les
 * autorise. Les contacts du prospect (POST/PATCH/DELETE /:id/contacts) suivent la même liste d'écriture que
 * celle-ci : tout futur écran de contacts doit l'utiliser.
 */
export const PROSPECTS_ECRITURE: readonly Role[] = ['ADMIN', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

/** Ce rôle peut-il modifier les prospects (voir PROSPECTS_ECRITURE) ? */
export function peutEcrireProspects(role: Role): boolean {
  return PROSPECTS_ECRITURE.includes(role);
}
