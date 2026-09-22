'use client';

import { useRouter, useSearchParams } from 'next/navigation';

/**
 * Filtre du portefeuille : coché (défaut) = uniquement MES magasins ;
 * décoché = tous les magasins du référentiel (tous=1 dans l'URL).
 */
export function MesMagasinsToggle() {
  const router = useRouter();
  const params = useSearchParams();
  const mesMagasins = params.get('tous') !== '1';

  const basculer = () => {
    const next = new URLSearchParams(params.toString());
    if (mesMagasins) next.set('tous', '1');
    else next.delete('tous');
    next.delete('page'); // le changement de périmètre repart de la page 1
    router.push(`?${next.toString()}`);
  };

  return (
    <label className="flex cursor-pointer select-none items-center gap-2 rounded-xl border border-neutral-200 bg-white px-3 py-2 text-sm shadow-sm transition hover:border-brand dark:border-navy-700 dark:bg-navy-950">
      <input
        type="checkbox"
        checked={mesMagasins}
        onChange={basculer}
        className="h-4 w-4 accent-[var(--color-brand)]"
      />
      Mes magasins uniquement
    </label>
  );
}
