'use client';

import { useRouter } from 'next/navigation';

/** Sélecteur de promoteur : recharge la grille au changement. */
export function PromoteurSelect({
  promoteurs,
  value,
  semaine,
}: {
  promoteurs: { id: string; displayName: string; idRepr: string | null }[];
  value: string;
  semaine: string;
}) {
  const router = useRouter();
  return (
    <select
      value={value}
      onChange={(e) => router.push(`/pilotage/tournees?promoteur=${e.target.value}&semaine=${semaine}`)}
      className="rounded-lg border border-neutral-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950"
    >
      {promoteurs.map((p) => (
        <option key={p.id} value={p.id}>
          {p.displayName} ({p.idRepr})
        </option>
      ))}
    </select>
  );
}
