'use client';

import { useRef, useState, useTransition } from 'react';
import { setUserRole } from '@/lib/admin-actions';
import { ROLE_LABELS } from './badges';

/** Sélecteur de rôle : enregistre immédiatement au changement, affiche l'erreur éventuelle. */
export function RoleSelect({ userId, value }: { userId: string; value: string }) {
  const formRef = useRef<HTMLFormElement>(null);
  const [pending, startTransition] = useTransition();
  const [erreur, setErreur] = useState<string | null>(null);

  return (
    <form
      ref={formRef}
      action={async (fd) => {
        setErreur(await setUserRole(fd));
      }}
    >
      <input type="hidden" name="userId" value={userId} />
      <select
        name="role"
        defaultValue={value}
        disabled={pending}
        aria-label="Rôle de l'utilisateur"
        onChange={() => startTransition(() => formRef.current?.requestSubmit())}
        className="rounded-lg border border-neutral-200 bg-white px-2 py-1 text-xs outline-none transition focus:border-brand focus-visible:ring-2 focus-visible:ring-brand/40 disabled:opacity-50 dark:border-navy-700 dark:bg-navy-950"
      >
        {Object.entries(ROLE_LABELS).map(([role, label]) => (
          <option key={role} value={role}>
            {label}
          </option>
        ))}
      </select>
      {erreur && (
        <p role="alert" className="mt-1 text-xs text-red-600">
          {erreur}
        </p>
      )}
    </form>
  );
}
