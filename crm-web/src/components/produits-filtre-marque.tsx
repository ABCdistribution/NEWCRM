'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import type { MarqueRow } from '@/lib/api';

const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

/**
 * Sélecteur de marque de la page Produits : réécrit `?marque=` dans l'adresse en gardant les autres filtres
 * (recherche, promos / PEM, rappel) et repart de la page 1. La liste est rechargée par la page serveur.
 */
export function ProduitsFiltreMarque({ marques, marque }: { marques: MarqueRow[]; marque?: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();

  const choisir = (id: string) => {
    const sp = new URLSearchParams(params.toString());
    if (id) sp.set('marque', id);
    else sp.delete('marque');
    sp.delete('page');
    const q = sp.toString();
    router.replace(q ? `${pathname}?${q}` : pathname);
  };

  return (
    <>
      <label htmlFor="produits-marque" className="sr-only">
        Marque
      </label>
      <select
        id="produits-marque"
        value={marque ?? ''}
        onChange={(e) => choisir(e.target.value)}
        className={`h-9 rounded-full border border-neutral-200 bg-white px-3 text-xs font-medium text-neutral-700 ${FOCUS}`}
      >
        <option value="">Toutes les marques</option>
        {marques.map((m) => (
          <option key={m.id} value={m.id}>
            {m.nom} ({m.nbArticles})
          </option>
        ))}
      </select>
    </>
  );
}
