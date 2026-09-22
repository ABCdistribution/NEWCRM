'use client';

import { useRef, useTransition } from 'react';
import { setUserRole } from '@/lib/admin-actions';
import { ROLE_LABELS } from './badges';

/** Sélecteur de rôle : enregistre immédiatement au changement. */
export function RoleSelect({ userId, value }: { userId: string; value: string }) {
  const formRef = useRef<HTMLFormElement>(null);
  const [pending, startTransition] = useTransition();

  return (
    <form ref={formRef} action={setUserRole}>
      <input type="hidden" name="userId" value={userId} />
      <select
        name="role"
        defaultValue={value}
        disabled={pending}
        onChange={() => startTransition(() => formRef.current?.requestSubmit())}
        className="rounded-lg border border-neutral-200 bg-white px-2 py-1 text-xs outline-none transition focus:border-brand disabled:opacity-50 dark:border-navy-700 dark:bg-navy-950"
      >
        {Object.entries(ROLE_LABELS).map(([role, label]) => (
          <option key={role} value={role}>
            {label}
          </option>
        ))}
      </select>
    </form>
  );
}
