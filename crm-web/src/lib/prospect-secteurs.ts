import { serverFetch } from './api';

export type SecteurProposable = { id: string; code: string; nom: string };

/**
 * Secteurs que l'utilisateur peut choisir pour un nouveau prospect (GET /prospects/secteurs) : CHEF_SECTEUR =
 * les siens, DIRECTEUR_REGIONAL = ceux de sa région, ADMIN = tous. Ne PAS utiliser GET /secteurs, réservé à ADMIN
 * (403 pour les autres, donc liste vide). DIRECTION n'a pas accès à cette route (il ne crée pas de prospect).
 * Renvoie null si l'API est injoignable ou refuse l'accès.
 */
export async function listSecteursProposables(): Promise<SecteurProposable[] | null> {
  try {
    const res = await serverFetch('/prospects/secteurs');
    if (!res.ok) return null;
    const json = (await res.json()) as SecteurProposable[];
    return Array.isArray(json) ? json.map((s) => ({ id: s.id, code: s.code, nom: s.nom })) : null;
  } catch {
    return null;
  }
}
