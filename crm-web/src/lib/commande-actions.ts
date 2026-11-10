'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch, type StatutLivraison } from './api';
import { messagesApi } from './erreurs-api';
import { exigerRole, messageRefus } from './roles';
import { ROLES_LIVRAISON } from './commande-roles';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const STATUTS: readonly StatutLivraison[] = ['EN_PREPARATION', 'EXPEDIEE', 'LIVREE_PARTIELLE', 'LIVREE'];

/**
 * Met à jour le suivi de livraison d'une commande (ADV · Direction · ADMIN).
 * Renvoie null si OK, sinon le message d'erreur à afficher.
 */
export async function majLivraison(
  commandeId: string,
  data: {
    statutLivraison?: StatutLivraison;
    transporteur?: string;
    noSuivi?: string;
    commentaireLivraison?: string;
  },
): Promise<string | null> {
  try {
    await exigerRole(ROLES_LIVRAISON);
  } catch (e) {
    return messageRefus(e, "Accès refusé : vous n'avez pas le droit de modifier le suivi de livraison.");
  }
  if (!UUID.test(commandeId)) return 'Commande invalide.';
  if (data.statutLivraison !== undefined && !STATUTS.includes(data.statutLivraison)) {
    return 'Statut de livraison invalide.';
  }

  let res: Response;
  try {
    res = await serverFetch(`/commandes/${encodeURIComponent(commandeId)}/livraison`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
  } catch {
    return "L'API est injoignable. Réessayez dans un instant.";
  }
  if (!res.ok) {
    const messages = await messagesApi(res);
    return messages.length > 0 ? messages.join(' ') : `Échec de la mise à jour (HTTP ${res.status}).`;
  }
  revalidatePath(`/commandes/${commandeId}`);
  revalidatePath('/commandes');
  return null;
}
