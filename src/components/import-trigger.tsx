'use client';

import { useActionState } from 'react';
import { Play } from 'lucide-react';
import { triggerImportClients, type ImportState } from '@/lib/admin-actions';

const INITIAL: ImportState = { error: null, ok: false };

/** Déclenchement manuel d'un import Minos clients (chemin de fichier côté serveur API). */
export function ImportTrigger() {
  const [state, action, pending] = useActionState(triggerImportClients, INITIAL);

  return (
    <form
      action={action}
      className="flex flex-wrap items-center gap-2 rounded-2xl bg-white p-4 shadow-card"
    >
      <input
        name="filePath"
        placeholder="Chemin du fichier CLI_*.txt sur le serveur API…"
        className="min-w-64 flex-1 rounded-lg border border-neutral-200 bg-white px-3 py-2 font-mono text-xs outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950"
      />
      <button
        type="submit"
        disabled={pending}
        className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        <Play size={14} />
        {pending ? 'Lancement…' : 'Importer (clients)'}
      </button>
      {state.error ? <p className="w-full text-xs text-red-400">{state.error}</p> : null}
      {state.ok ? <p className="w-full text-xs text-emerald-500">Import mis en file d&apos;attente ✅</p> : null}
    </form>
  );
}
