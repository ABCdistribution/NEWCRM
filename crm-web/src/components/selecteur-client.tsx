'use client';

import { useRouter } from 'next/navigation';

/** Sélecteur « Tous les clients » + clients du promoteur : met à jour `?client=` (la liste est rechargée côté serveur). */
export function SelecteurClient({
  clients,
  valeur,
  base,
}: {
  clients: { id: string; enseigne: string; ville: string | null }[];
  valeur: string;
  /** URL de l'onglet courant, avec son `?onglet=` : on y ajoute `&client=`. */
  base: string;
}) {
  const router = useRouter();
  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor="equipe-client" className="text-xs font-semibold uppercase tracking-wide text-neutral-400">
        Client
      </label>
      <select
        id="equipe-client"
        value={valeur}
        onChange={(e) => router.push(e.target.value === 'tous' ? base : `${base}&client=${encodeURIComponent(e.target.value)}`, { scroll: false })}
        className="w-full rounded-xl border border-neutral-200 bg-white px-3 py-2.5 text-sm shadow-card focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:border-navy-700 dark:bg-navy-950 sm:max-w-md"
      >
        <option value="tous">Tous les clients ({clients.length})</option>
        {clients.map((c) => (
          <option key={c.id} value={c.id}>
            {c.enseigne}
            {c.ville ? ` — ${c.ville}` : ''}
          </option>
        ))}
      </select>
    </div>
  );
}
