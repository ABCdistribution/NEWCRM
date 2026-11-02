import { getMe, listRapports } from '@/lib/api';
import { AccesRefuse } from '@/components/acces-refuse';
import { RapportsBoard } from '@/components/rapports-board';

export const metadata = { title: 'Rapports d’activité — ABC Pilot' };

const ALLOWED = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL'];

/** yyyy-mm-dd en heure locale. */
function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** Lundi de la semaine contenant `d` (heure locale). */
function lundiDe(d: Date): Date {
  const x = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  x.setDate(x.getDate() - ((x.getDay() + 6) % 7));
  return x;
}

export default async function RapportsPage({ searchParams }: { searchParams: Promise<{ semaine?: string }> }) {
  const me = await getMe();
  if (!me || !ALLOWED.includes(me.role)) return <AccesRefuse />;

  const sp = await searchParams;
  const base = sp.semaine && /^\d{4}-\d{2}-\d{2}$/.test(sp.semaine) ? new Date(`${sp.semaine}T12:00:00`) : new Date();
  const semaine = iso(lundiDe(base));
  const data = await listRapports(semaine);
  return <RapportsBoard data={data} semaine={semaine} nonDisponible={data === null} />;
}
