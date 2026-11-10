'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { ROLE_LABELS } from '@/components/badges';

const SELECT =
  'rounded-lg border border-neutral-300 bg-white px-3 py-2 text-sm outline-none transition focus:border-brand focus:ring-2 focus:ring-brand/30 dark:border-navy-700 dark:bg-navy-950';

/** Filtres de la liste des comptes (secteur, rôle, statut), portés par l'URL ; ils se cumulent avec la recherche. */
export function UtilisateursFiltres({ secteurs }: { secteurs: { id: string; nom: string }[] }) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const valeur = (nom: string) => searchParams.get(nom) ?? '';
  const filtreActif = ['secteur', 'role', 'statut'].some((n) => valeur(n));

  function changer(nom: string, v: string) {
    const params = new URLSearchParams(searchParams.toString());
    if (v) params.set(nom, v);
    else params.delete(nom);
    params.delete('page'); // un nouveau filtre repart de la première page
    router.push(`${pathname}?${params}`);
  }

  function reinitialiser() {
    const params = new URLSearchParams(searchParams.toString());
    for (const n of ['secteur', 'role', 'statut', 'page']) params.delete(n);
    router.push(`${pathname}?${params}`);
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <select aria-label="Filtrer par secteur" value={valeur('secteur')} onChange={(e) => changer('secteur', e.target.value)} className={SELECT}>
        <option value="">Tous les secteurs</option>
        <option value="aucun">Sans secteur</option>
        {secteurs.map((s) => (
          <option key={s.id} value={s.id}>
            {s.nom}
          </option>
        ))}
      </select>
      <select aria-label="Filtrer par rôle" value={valeur('role')} onChange={(e) => changer('role', e.target.value)} className={SELECT}>
        <option value="">Tous les rôles</option>
        {Object.entries(ROLE_LABELS).map(([code, libelle]) => (
          <option key={code} value={code}>
            {libelle}
          </option>
        ))}
      </select>
      <select aria-label="Filtrer par statut" value={valeur('statut')} onChange={(e) => changer('statut', e.target.value)} className={SELECT}>
        <option value="">Actifs et inactifs</option>
        <option value="actif">Actifs</option>
        <option value="inactif">Inactifs</option>
      </select>
      {filtreActif ? (
        <button type="button" onClick={reinitialiser} className="text-sm text-neutral-500 underline-offset-2 hover:underline">
          Réinitialiser
        </button>
      ) : null}
    </div>
  );
}
