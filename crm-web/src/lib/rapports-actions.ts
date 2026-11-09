'use server';

import { getRapportDetail, type RapportDetail } from './api';
import { exigerRole, messageRefus } from './roles';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type RapportDetailResultat = { detail: RapportDetail; error: null } | { detail: null; error: string };

/**
 * Détail d'un rapport (tournée prévue et réalisée), appelé depuis le tableau des rapports.
 * Même règle que la page /rapports (CHEF_SECTEUR exclu) ; le périmètre est filtré par l'API.
 * Ne lève jamais : exigerRole lève « Accès refusé » aussi quand la session a expiré, et ErreurServiceIndisponible
 * quand l'API est injoignable ; ces deux erreurs sont converties en message pour l'utilisateur (messageRefus).
 */
export async function chargerRapportDetail(userId: string, semaine: string): Promise<RapportDetailResultat> {
  try {
    await exigerRole(['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL']);
  } catch (e) {
    return {
      detail: null,
      error: messageRefus(e, 'Accès refusé (rôle insuffisant ou session expirée). Rechargez la page ou reconnectez-vous.'),
    };
  }
  if (!UUID.test(userId) || !/^\d{4}-\d{2}-\d{2}$/.test(semaine)) {
    return { detail: null, error: 'Rapport indisponible.' };
  }
  const detail = await getRapportDetail(userId, semaine);
  return detail ? { detail, error: null } : { detail: null, error: 'Rapport indisponible.' };
}
