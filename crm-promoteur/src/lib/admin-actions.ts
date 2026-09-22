'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';
import type { Role } from './api';

/** Change le rôle ou l'activation d'un utilisateur (ADMIN). Renvoie null si OK, sinon le message d'erreur. */
export async function majUtilisateur(
  id: string,
  data: { role?: Role; isActive?: boolean },
): Promise<string | null> {
  try {
    const res = await serverFetch(`/users/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!res.ok) {
      const body = (await res.json().catch(() => null)) as { message?: string | string[] } | null;
      const msg = Array.isArray(body?.message) ? body.message.join(', ') : body?.message;
      return msg ?? `Échec de la mise à jour (HTTP ${res.status}).`;
    }
    revalidatePath('/utilisateurs');
    return null;
  } catch {
    return "L'API est injoignable.";
  }
}

/** Résultat de la synchronisation AD en masse (POST /sync/ad). */
export type SyncAdResult = {
  lus: number;
  crees: number;
  maj: number;
  directeursLies: number;
  sansRegion: string[];
  sansManager: string[];
  conflitsIdRepr: string[];
};

/** Lance la synchro de la force de vente depuis l'AD (ADMIN). */
export async function lancerSyncAd(): Promise<SyncAdResult | { erreur: string }> {
  try {
    const res = await serverFetch('/sync/ad', { method: 'POST' });
    if (!res.ok) return { erreur: `Échec de la synchronisation (HTTP ${res.status}).` };
    revalidatePath('/utilisateurs');
    return (await res.json()) as SyncAdResult;
  } catch {
    return { erreur: "L'API est injoignable." };
  }
}
