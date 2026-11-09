'use client';

import { useState, useTransition } from 'react';
import { Power } from 'lucide-react';
import { setUserActive } from '@/lib/admin-actions';

/** Bouton activer / désactiver un compte (affiche l'erreur éventuelle). */
export function ActiveToggle({ userId, isActive }: { userId: string; isActive: boolean }) {
  const [pending, startTransition] = useTransition();
  const [erreur, setErreur] = useState<string | null>(null);

  const toggle = () => {
    const fd = new FormData();
    fd.set('userId', userId);
    fd.set('isActive', String(!isActive));
    startTransition(async () => {
      setErreur(await setUserActive(fd));
    });
  };

  return (
    <>
      <button
        type="button"
        onClick={toggle}
        disabled={pending}
        className={`rounded-lg p-1.5 transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/40 disabled:opacity-50 ${
          isActive
            ? 'text-neutral-400 hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950/40'
            : 'text-neutral-400 hover:bg-emerald-50 hover:text-emerald-500 dark:hover:bg-emerald-950/40'
        }`}
        aria-label={isActive ? 'Désactiver le compte' : 'Réactiver le compte'}
        title={isActive ? 'Désactiver' : 'Réactiver'}
      >
        <Power size={14} aria-hidden />
      </button>
      {erreur && (
        <span role="alert" className="ml-1 text-xs text-red-600">
          {erreur}
        </span>
      )}
    </>
  );
}
