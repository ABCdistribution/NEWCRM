'use client';

import { useRef, useTransition } from 'react';
import { setUserSecteur } from '@/lib/admin-actions';

/** Rattachement d'un utilisateur à un secteur : enregistre au changement. */
export function SecteurSelect({
  userId,
  value,
  secteurs,
}: {
  userId: string;
  value: string | null;
  secteurs: { id: string; code: string; nom: string }[];
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const [pending, startTransition] = useTransition();

  return (
    <form ref={formRef} action={setUserSecteur}>
      <input type="hidden" name="userId" value={userId} />
      <select
        name="secteurId"
        defaultValue={value ?? ''}
        disabled={pending}
        onChange={() => startTransition(() => formRef.current?.requestSubmit())}
        className="rounded-lg border border-neutral-200 bg-white px-2 py-1 text-xs outline-none transition focus:border-brand disabled:opacity-50 dark:border-navy-700 dark:bg-navy-950"
      >
        <option value="">— aucun —</option>
        {secteurs.map((s) => (
          <option key={s.id} value={s.id}>
            {s.nom} ({s.code})
          </option>
        ))}
      </select>
    </form>
  );
}
