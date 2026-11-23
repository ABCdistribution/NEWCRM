import { serverFetch } from './api';
import type { CentraleAdmin, ProduitIndispensable } from './produits-indispensables';

async function lireListe<T>(chemin: string): Promise<T[] | null> {
  try {
    const res = await serverFetch(chemin);
    if (!res.ok) return null;
    const corps: unknown = await res.json();
    return Array.isArray(corps) ? (corps as T[]) : null;
  } catch {
    return null;
  }
}

/** Enseignes avec leur nombre de magasins (null si l'API est indisponible). */
export function listCentrales(): Promise<CentraleAdmin[] | null> {
  return lireListe<CentraleAdmin>('/centrales');
}

/** Produits indispensables de toutes les enseignes (null si l'API est indisponible). */
export function listProduitsIndispensables(): Promise<ProduitIndispensable[] | null> {
  return lireListe<ProduitIndispensable>('/produits-indispensables');
}
