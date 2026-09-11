'use client';

import { useTransition } from 'react';
import { Power } from 'lucide-react';
import { setUserActive } from '@/lib/admin-actions';

/** Bouton activer / désactiver un compte. */
export function ActiveToggle({ userId, isActive }: { userId: string; isActive: boolean }) {
  const [pending, startTransition] = useTransition();

  const toggle = () => {
    const fd = new FormData();
    fd.set('userId', userId);
    fd.set('isActive', String(!isActive));
    startTransition(async () => {
      await setUserActive(fd);
    });
  };

  return (
    <button
      type="button"
      onClick={toggle}
      disabled={pending}
      className={`rounded-lg p-1.5 transition disabled:opacity-50 ${
        isActive
          ? 'text-neutral-400 hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950/40'
          : 'text-neutral-400 hover:bg-emerald-50 hover:text-emerald-500 dark:hover:bg-emerald-950/40'
      }`}
      aria-label={isActive ? 'Désactiver le compte' : 'Réactiver le compte'}
      title={isActive ? 'Désactiver' : 'Réactiver'}
    >
      <Power size={14} />
    </button>
  );
}
