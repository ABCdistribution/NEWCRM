import { redirect } from 'next/navigation';

/** Ancienne page de planning : le planning est désormais l'onglet « Planning » de la fiche du chef de secteur. */
export default async function PlanningMembreRedirect({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ semaine?: string }>;
}) {
  const { id } = await params;
  const { semaine } = await searchParams;
  const q = semaine && /^\d{4}-\d{2}-\d{2}$/.test(semaine) ? `&semaine=${semaine}` : '';
  redirect(`/pilotage/mon-equipe/${encodeURIComponent(id)}?onglet=planning${q}`);
}
