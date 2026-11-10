// Activité du mois de l'utilisateur connecté (bandeau du haut) : lecture côté serveur (serverFetch uniquement).
import { serverFetch } from './api';
import type { Activite } from './carte';

/**
 * Visites, commandes, CA et objectif mensuel de l'utilisateur lui-même (`GET /dashboard/mon-activite`, mois en cours),
 * ou null si l'API ne répond pas : le bandeau s'affiche alors sans cette ligne. Rien n'est calculé ni filtré ici.
 */
export async function getMonActivite(): Promise<Activite | null> {
  try {
    const res = await serverFetch('/dashboard/mon-activite');
    if (!res.ok) return null;
    const a = (await res.json()) as Partial<Activite> | null;
    if (!a || typeof a.visites !== 'number' || typeof a.commandes !== 'number' || typeof a.ca !== 'number') return null;
    return {
      visites: a.visites,
      commandes: a.commandes,
      ca: a.ca,
      objectif: typeof a.objectif === 'number' ? a.objectif : null,
      tauxPct: typeof a.tauxPct === 'number' ? a.tauxPct : null,
    };
  } catch {
    return null;
  }
}
