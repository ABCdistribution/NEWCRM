'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';
import type { StatutLivraison } from './api';

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
    const res = await serverFetch(`/commandes/${commandeId}/livraison`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!res.ok) {
      const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
      const msg = Array.isArray(body?.message) ? body.message.join(', ') : body?.message;
      return msg ?? `Échec de la mise à jour (HTTP ${res.status}).`;
    }
    revalidatePath(`/commandes/${commandeId}`);
    revalidatePath('/commandes');
    return null;
  } catch {
    return "L'API est injoignable.";
  }
}
