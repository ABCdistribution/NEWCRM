'use server';

import { listPlannings, type PlanningItem } from './api';

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
