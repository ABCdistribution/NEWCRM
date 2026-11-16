'use client';

import { useEffect, useRef, useState } from 'react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { Search, X } from 'lucide-react';
import type { StatutClients } from '@/lib/clients-liste';

const NIVEAUX = ['A', 'B', 'C', 'D', 'E', 'F', 'G'] as const;
const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';
const SELECT = `h-11 rounded-xl border border-neutral-200 bg-white px-3 text-sm ${FOCUS}`;

/**
 * Barre de filtres de la liste des clients : recherche (enseigne, code AS400, ville, code postal), niveau, état,
 * « Mes clients » (rôles qui ont un périmètre) et « Réinitialiser ». Chaque changement réécrit l'adresse
 * (`?search=&niveau=&statut=&tous=`) et repart de la page 1 ; la recherche attend la fin de la frappe.
 * Les données sont rechargées par la page serveur : ce composant ne filtre rien.
 */
export function ClientsFiltres({
  search,
  niveau,
  statut,
  mes,
  avecMes,
}: {
  search: string;
  niveau?: string;
  statut: StatutClients;
  /** « Mes clients » actif (uniquement quand `avecMes`). */
  mes: boolean;
  /** Le rôle a un périmètre : le filtre « Mes clients » est proposé. */
  avecMes: boolean;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [saisie, setSaisie] = useState(search);
  const derniere = useRef(search);

  // Garde le champ aligné sur l'adresse (retour arrière du navigateur, « Réinitialiser »).
  useEffect(() => {
    setSaisie(search);
    derniere.current = search;
  }, [search]);

  const aller = (modif: Record<string, string | null>) => {
    const sp = new URLSearchParams(params.toString());
    for (const [cle, valeur] of Object.entries(modif)) {
      if (valeur === null || valeur === '') sp.delete(cle);
      else sp.set(cle, valeur);
    }
    sp.delete('page');
    const q = sp.toString();
    router.replace(q ? `${pathname}?${q}` : pathname);
  };

  // Recherche : 400 ms après la dernière frappe.
  useEffect(() => {
    const texte = saisie.trim();
    if (texte === derniere.current) return;
    const minuteur = setTimeout(() => {
      derniere.current = texte;
      aller({ search: texte });
    }, 400);
    return () => clearTimeout(minuteur);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [saisie]);

  const modifie = search !== '' || niveau !== undefined || statut !== 'actifs' || (avecMes && !mes);

  return (
    <div className="flex flex-wrap items-center gap-3 rounded-2xl bg-white p-3 shadow-card">
      <div className="relative min-w-60 flex-1">
        <label htmlFor="clients-recherche" className="sr-only">
          Rechercher un client
        </label>
        <Search size={18} className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-neutral-400" aria-hidden />
        <input
          id="clients-recherche"
          type="search"
          value={saisie}
          onChange={(e) => setSaisie(e.target.value)}
          maxLength={80}
          placeholder="Rechercher par enseigne, code AS400, ville, CP…"
          className={`h-11 w-full rounded-xl border border-neutral-200 bg-neutral-50 pl-10 pr-3 text-sm ${FOCUS}`}
        />
      </div>

      {avecMes ? (
        <label className="flex h-11 cursor-pointer select-none items-center gap-2 rounded-xl border border-neutral-200 bg-white px-3 text-sm transition hover:border-brand/50">
          <input
            type="checkbox"
            checked={mes}
            onChange={() => aller({ tous: mes ? '1' : null })}
            className="h-4 w-4 accent-[var(--color-brand)]"
          />
          Mes clients
        </label>
      ) : null}

      <label className="sr-only" htmlFor="clients-niveau">
        Niveau
      </label>
      <select id="clients-niveau" value={niveau ?? ''} onChange={(e) => aller({ niveau: e.target.value })} className={SELECT}>
        <option value="">Tous les niveaux</option>
        {NIVEAUX.map((n) => (
          <option key={n} value={n}>
            Niveau {n}
          </option>
        ))}
        <option value="aucun">Sans niveau</option>
      </select>

      <label className="sr-only" htmlFor="clients-statut">
        État
      </label>
      <select
        id="clients-statut"
        value={statut}
        onChange={(e) => aller({ statut: e.target.value === 'actifs' ? null : e.target.value })}
        className={SELECT}
      >
        <option value="actifs">Clients actifs</option>
        <option value="inactifs">Clients inactifs</option>
        <option value="tous">Tous les clients</option>
      </select>

      <button
        type="button"
        onClick={() => {
          setSaisie('');
          derniere.current = '';
          router.replace(pathname);
        }}
        disabled={!modifie}
        className={`inline-flex h-11 items-center gap-1.5 rounded-xl border border-neutral-200 px-3 text-sm font-medium text-neutral-600 transition hover:bg-neutral-50 disabled:cursor-not-allowed disabled:opacity-40 ${FOCUS}`}
      >
        <X size={15} aria-hidden />
        Réinitialiser
      </button>
    </div>
  );
}
