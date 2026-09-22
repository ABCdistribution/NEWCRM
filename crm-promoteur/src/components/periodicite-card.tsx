'use client';

import { useRef, useState, useTransition } from 'react';
import { CalendarClock, Pencil, X } from 'lucide-react';
import { setPeriodicite } from '@/lib/client-actions';

export type PeriodiciteRef = { id: string; code: number | null; libelle: string };

export function PeriodiciteCard({
  clientId,
  actuelle,
  referentiel,
}: {
  clientId: string;
  actuelle: PeriodiciteRef | null;
  referentiel: PeriodiciteRef[];
}) {
  const [editing, setEditing] = useState(false);
  const [pending, startTransition] = useTransition();
  const formRef = useRef<HTMLFormElement>(null);

  const submit = (formData: FormData) => {
    startTransition(async () => {
      await setPeriodicite(formData);
      setEditing(false);
    });
  };

  return (
    <div className="rounded-2xl bg-white shadow-card">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3 font-semibold dark:border-navy-700">
        <CalendarClock size={17} className="text-brand" />
        Périodicité de visite
        <button
          type="button"
          onClick={() => setEditing((v) => !v)}
          className="ml-auto inline-flex items-center gap-1 rounded-lg border border-neutral-200 px-2.5 py-1 text-xs font-medium text-neutral-600 transition hover:border-brand hover:text-brand dark:border-navy-700 dark:text-neutral-300"
        >
          {editing ? <X size={13} /> : <Pencil size={13} />}
          {editing ? 'Fermer' : 'Modifier'}
        </button>
      </h2>

      <div className="px-5 py-4">
        {editing ? (
          <form ref={formRef} action={submit} className="flex items-center gap-2">
            <input type="hidden" name="clientId" value={clientId} />
            <select
              name="periodiciteId"
              defaultValue={actuelle?.id ?? ''}
              className="w-full rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950"
            >
              <option value="">Aucune périodicité</option>
              {referentiel.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.libelle}
                </option>
              ))}
            </select>
            <button
              type="submit"
              disabled={pending}
              className="shrink-0 rounded-xl bg-brand px-3 py-1.5 text-xs font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80 disabled:opacity-50"
            >
              {pending ? '…' : 'Enregistrer'}
            </button>
          </form>
        ) : actuelle ? (
          <p className="text-sm font-medium">{actuelle.libelle}</p>
        ) : (
          <p className="text-sm text-neutral-400">Aucune périodicité définie.</p>
        )}
      </div>
    </div>
  );
}
