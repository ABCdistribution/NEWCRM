'use client';

import { useActionState } from 'react';
import { saveObjectif, type ObjectifState } from '@/lib/admin-actions';

const INITIAL: ObjectifState = { error: null, ok: false };

/** Saisie inline de l'objectif ANNUEL d'un magasin : Entrée ou perte de focus = enregistrement. */
export function ObjectifInput({
  clientId,
  annee,
  value,
}: {
  clientId: string;
  annee: number;
  value: number | null;
}) {
  const [state, action, pending] = useActionState(saveObjectif, INITIAL);

  return (
    <form action={action} className="inline-flex items-center gap-1.5">
      <input type="hidden" name="clientId" value={clientId} />
      <input type="hidden" name="annee" value={annee} />
      <input
        name="cibleCa"
        type="text"
        inputMode="decimal"
        defaultValue={value ?? ''}
        placeholder="—"
        disabled={pending}
        onBlur={(e) => {
          const initial = value === null ? '' : String(value);
          if (e.target.value.trim() !== initial) e.target.form?.requestSubmit();
        }}
        className={`w-28 rounded-lg border px-2 py-1 text-right text-sm outline-none transition focus:border-brand disabled:opacity-50 dark:bg-navy-950 ${
          state.error
            ? 'border-red-400'
            : state.ok
              ? 'border-emerald-500'
              : 'border-neutral-200 dark:border-navy-700'
        }`}
        title={state.error ?? undefined}
      />
    </form>
  );
}
