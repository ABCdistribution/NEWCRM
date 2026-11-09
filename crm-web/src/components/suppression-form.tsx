'use client';

import { useActionState } from 'react';
import { Trash2 } from 'lucide-react';
import type { ActionState } from '@/lib/client-actions';

/**
 * Bouton « corbeille » d'une suppression (contact, note) : confirmation, état d'attente et
 * message d'erreur visible si l'API refuse. Visible au clavier (focus) comme au survol.
 */
export function SuppressionForm({
  action,
  champs,
  confirmation,
  libelle,
}: {
  action: (prev: ActionState, formData: FormData) => Promise<ActionState>;
  champs: Record<string, string>;
  confirmation: string;
  libelle: string;
}) {
  const [state, formAction, pending] = useActionState(action, { error: null });

  return (
    <form
      action={formAction}
      className="relative shrink-0"
      onSubmit={(e) => {
        if (!confirm(confirmation)) e.preventDefault();
      }}
    >
      {Object.entries(champs).map(([nom, valeur]) => (
        <input key={nom} type="hidden" name={nom} value={valeur} />
      ))}
      <button
        type="submit"
        disabled={pending}
        className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-600 focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-brand disabled:opacity-50 dark:hover:bg-red-950/40 dark:focus-visible:outline-accent"
        aria-label={libelle}
      >
        <Trash2 size={14} />
      </button>
      {state.error ? (
        <p role="alert" className="absolute right-0 top-full z-10 mt-1 w-56 rounded-lg border border-red-200 bg-red-50 px-2 py-1 text-xs text-red-700 shadow-card dark:border-red-900/50 dark:bg-red-950/40 dark:text-red-300">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
