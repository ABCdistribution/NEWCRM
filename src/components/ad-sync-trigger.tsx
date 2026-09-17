'use client';

import { useActionState } from 'react';
import { RefreshCw } from 'lucide-react';
import { syncAd, type AdSyncState } from '@/lib/admin-actions';

const INITIAL: AdSyncState = { error: null, ok: false };

/** Synchronisation en masse de la force de vente française depuis l'AD. */
export function AdSyncTrigger() {
  const [state, action, pending] = useActionState(syncAd, INITIAL);

  return (
    <form action={action} className="flex flex-col items-end gap-1.5">
      <button
        type="submit"
        disabled={pending}
        className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        <RefreshCw size={14} className={pending ? 'animate-spin' : ''} />
        {pending ? 'Synchronisation…' : "Synchroniser depuis l'AD"}
      </button>
      {state.error ? <p className="text-xs text-red-500">{state.error}</p> : null}
      {state.ok && state.stats ? (
        <p className="max-w-md text-right text-xs text-emerald-600">
          ✅ {state.stats.lus} comptes lus · {state.stats.crees} créés · {state.stats.maj} mis à
          jour · {state.stats.photos ?? 0} photos rapatriées · {state.stats.directeursLies} rattachés à un directeur
          {state.stats.conflitsIdRepr.length > 0
            ? ` · ⚠️ codes en conflit : ${state.stats.conflitsIdRepr.join(', ')}`
            : ''}
        </p>
      ) : null}
    </form>
  );
}
