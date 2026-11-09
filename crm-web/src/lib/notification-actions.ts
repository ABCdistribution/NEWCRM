'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';

export type ResultatNotif = { erreur: string | null };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ECHEC = 'Impossible de mettre à jour les notifications. Réessaie dans un instant.';

async function appeler(path: string, method: 'POST' | 'PATCH'): Promise<ResultatNotif> {
  try {
    const res = await serverFetch(path, { method });
    if (!res.ok) return { erreur: ECHEC };
  } catch {
    return { erreur: ECHEC };
  }
  revalidatePath('/', 'layout');
  return { erreur: null };
}

/** Marque toutes les notifications comme lues. */
export async function marquerToutLu(): Promise<ResultatNotif> {
  return appeler('/notifications/lu-tout', 'POST');
}

/** Marque UNE notification comme lue. */
export async function marquerLu(id: string): Promise<ResultatNotif> {
  if (!UUID.test(id)) return { erreur: 'Notification invalide.' };
  return appeler(`/notifications/${encodeURIComponent(id)}/lu`, 'PATCH');
}
