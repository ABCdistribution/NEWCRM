import { redirect } from 'next/navigation';
import { requireRole, type Role } from '@/lib/roles';
import { estUuid } from '@/lib/equipe-utils';

const ROLES_AUTORISES: readonly Role[] = ['DIRECTEUR_REGIONAL', 'ADMIN'];

/** Ancienne page de planning : le planning est désormais l'onglet « Planning » de la fiche du chef de secteur. */
export default async function PlanningMembreRedirect({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ semaine?: string }>;
}) {
  const acces = await requireRole(ROLES_AUTORISES);
  if (acces.refuse) return acces.refuse;
  const { id } = await params;
  if (!estUuid(id)) redirect('/mon-equipe');
  const { semaine } = await searchParams;
  const q = semaine && /^\d{4}-\d{2}-\d{2}$/.test(semaine) ? `&semaine=${semaine}` : '';
  redirect(`/mon-equipe/${encodeURIComponent(id)}?onglet=planning${q}`);
}
