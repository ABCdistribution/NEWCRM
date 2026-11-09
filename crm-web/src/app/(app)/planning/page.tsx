import { requireRole, ENCADREMENT, TERRAIN } from '@/lib/roles';
import { PlanningActivite } from './planning-activite';
import { PlanningLecture } from './planning-lecture';

export const metadata = { title: 'Mon planning' };

/**
 * Une seule URL, deux vues selon le rôle :
 * - COMMERCIAL / ADV : leurs visites planifiées, en lecture seule ;
 * - encadrement : planning personnel d'activité (prospection + suivi magasins), éditable.
 */
export default async function PlanningPage({
  searchParams,
}: {
  searchParams: Promise<{ semaine?: string }>;
}) {
  const acces = await requireRole([...ENCADREMENT, ...TERRAIN]);
  if (acces.refuse) return acces.refuse;
  const { semaine } = await searchParams;
  const { me } = acces;

  if (TERRAIN.includes(me.role)) return <PlanningLecture userId={me.id} semaine={semaine} />;
  return <PlanningActivite semaine={semaine} />;
}
