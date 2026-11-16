'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';

/**
 * Bascule « Mes commandes » / « Mes visites » (cochée par défaut) : décochée, la liste montre tout (`?tous=1`).
 * Les autres filtres de l'adresse sont conservés ; la page repart de la page 1. La liste est rechargée par la page
 * serveur, qui fait appliquer la restriction par l'API : ce composant ne filtre rien.
 */
export function MesToggle({ libelle }: { libelle: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const mes = params.get('tous') !== '1';

  const basculer = () => {
    const sp = new URLSearchParams(params.toString());
    if (mes) sp.set('tous', '1');
    else sp.delete('tous');
    sp.delete('page');
    const q = sp.toString();
    router.push(q ? `${pathname}?${q}` : pathname);
  };

  return (
    <label className="flex h-10 cursor-pointer select-none items-center gap-2 rounded-xl border border-neutral-200 bg-white px-3 text-sm transition hover:border-brand/50 focus-within:ring-2 focus-within:ring-brand/40">
      <input type="checkbox" checked={mes} onChange={basculer} className="h-4 w-4 accent-[var(--color-brand)]" />
      {libelle}
    </label>
  );
}
