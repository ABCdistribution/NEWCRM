'use server';

import { listPlannings, listPlanningMembre, type PlanningItem } from './api';

function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function mondayOf(d: Date): Date {
  const m = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const dow = (m.getDay() + 6) % 7; // 0 = lundi
  m.setDate(m.getDate() - dow);
  return m;
}

/** Visites planifiées de la semaine courante pour un promoteur (pour la modale équipe). */
export async function getPromoteurSemaine(
  promoteurId: string,
): Promise<{ items: PlanningItem[]; error: boolean }> {
  const monday = mondayOf(new Date());
  const next = new Date(monday);
  next.setDate(next.getDate() + 7);
  const items = await listPlannings(promoteurId, iso(monday), iso(next));
  return { items: items ?? [], error: items === null };
}

export type RapportHebdo = {
  semaine: string; // lundi ISO
  statut: 'PREVISION' | 'COMPLET';
  prevus: number;
  realises: number;
  synthese: string | null;
};

/**
 * Rapports d'activité d'un membre = HISTORIQUE réel de son planning : les
 * 3 dernières semaines + la courante, agrégées (étapes prévues / réalisées,
 * répartition prospection / suivi / ADM en synthèse).
 */
export async function getRapportsMembre(userId: string): Promise<RapportHebdo[]> {
  const lundiCourant = mondayOf(new Date());
  const debut = new Date(lundiCourant);
  debut.setDate(debut.getDate() - 21);
  const fin = new Date(lundiCourant);
  fin.setDate(fin.getDate() + 7);

  const result = await listPlanningMembre(userId, iso(debut), iso(fin));
  if (!result) return [];

  const rapports: RapportHebdo[] = [];
  for (let delta = 0; delta >= -3; delta--) {
    const lundi = new Date(lundiCourant);
    lundi.setDate(lundi.getDate() + delta * 7);
    const suivant = new Date(lundi);
    suivant.setDate(suivant.getDate() + 7);
    const semaine = result.etapes.filter(
      (e) => e.datePassage >= iso(lundi) && e.datePassage < iso(suivant),
    );
    if (semaine.length === 0) continue;
    const realises = semaine.filter((e) => e.fait).length;
    const parts = [
      [semaine.filter((e) => e.prospect).length, 'prospection'],
      [semaine.filter((e) => e.client).length, 'suivi magasin'],
      [semaine.filter((e) => e.adm).length, 'ADM'],
    ].filter(([n]) => (n as number) > 0);
    rapports.push({
      semaine: iso(lundi),
      statut: delta === 0 ? 'PREVISION' : 'COMPLET',
      prevus: semaine.length,
      realises,
      synthese: parts.length ? parts.map(([n, l]) => `${n} ${l}`).join(', ') : null,
    });
  }
  return rapports;
}
