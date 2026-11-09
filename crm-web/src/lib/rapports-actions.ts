'use server';

import { getRapportDetail, type RapportDetail } from './api';
import { exigerRole } from './roles';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Détail d'un rapport (tournée prévue et réalisée), appelé depuis le tableau des rapports.
 * Même règle que la page /rapports (CHEF_SECTEUR exclu) ; le périmètre est filtré par l'API.
 */
export async function chargerRapportDetail(userId: string, semaine: string): Promise<RapportDetail | null> {
  await exigerRole(['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL']);
  if (!UUID.test(userId) || !/^\d{4}-\d{2}-\d{2}$/.test(semaine)) return null;
  return getRapportDetail(userId, semaine);
}
