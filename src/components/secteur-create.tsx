'use client';

import { useActionState, useEffect, useState } from 'react';
import { Plus, X } from 'lucide-react';
import { createSecteur, type SecteurFormState } from '@/lib/secteur-actions';

const INITIAL: SecteurFormState = { error: null, ok: false };
const field =
  'w-full rounded-lg border border-neutral-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950';
const labelCls = 'text-xs font-medium text-neutral-500';

export type ManagerOption = { id: string; displayName: string; role: string };

export function SecteurCreate({ managers }: { managers: ManagerOption[] }) {
  const [open, setOpen] = useState(false);
  const [state, action, pending] = useActionState(createSecteur, INITIAL);

  // Ferme la modale dès que la création réussit.
  useEffect(() => {
    if (state.ok) setOpen(false);
  }, [state.ok]);

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
      >
        <Plus size={15} /> Nouveau secteur
      </button>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-16">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 shadow-xl dark:bg-navy-900">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-bold">Nouveau secteur</h2>
          <button type="button" onClick={() => setOpen(false)} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer">
            <X size={18} />
          </button>
        </div>

        <form action={action} className="flex flex-col gap-3">
          <div className="grid grid-cols-3 gap-3">
            <label className="flex flex-col gap-1">
              <span className={labelCls}>Code *</span>
              <input name="code" required placeholder="34" className={field} />
            </label>
            <label className="col-span-2 flex flex-col gap-1">
              <span className={labelCls}>Nom *</span>
              <input name="nom" required placeholder="Hérault" className={field} />
            </label>
          </div>
          <label className="flex flex-col gap-1">
            <span className={labelCls}>Chef de secteur</span>
            <select name="managerId" defaultValue="" className={field}>
              <option value="">— aucun —</option>
              {managers.map((m) => (
                <option key={m.id} value={m.id}>
                  {m.displayName}
                </option>
              ))}
            </select>
          </label>

          {state.error ? <p className="text-sm text-red-500">{state.error}</p> : null}

          <div className="mt-1 flex justify-end gap-2">
            <button type="button" onClick={() => setOpen(false)} className="rounded-lg px-3 py-2 text-sm text-neutral-500 hover:text-neutral-700">
              Annuler
            </button>
            <button
              type="submit"
              disabled={pending}
              className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-4 py-2 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
            >
              <Plus size={15} /> {pending ? 'Création…' : 'Créer'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
