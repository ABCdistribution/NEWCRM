'use server';

import { revalidatePath } from 'next/cache';
import { serverFetch } from './api';

/** Marque toutes les notifications comme lues. */
export async function marquerToutLu(): Promise<void> {
  await serverFetch('/notifications/lu-tout', { method: 'POST' }).catch(() => undefined);
  revalidatePath('/', 'layout');
}

/** Marque UNE notification comme lue. */
export async function marquerLu(id: string): Promise<void> {
  await serverFetch(`/notifications/${id}/lu`, { method: 'PATCH' }).catch(() => undefined);
  revalidatePath('/', 'layout');
}
