import { getMe } from '@/lib/api';
import { AccesRefuse } from '@/components/acces-refuse';
import { RapportsBoard } from '@/components/rapports-board';

export const metadata = { title: 'Rapports d’activité — Helios' };

const ALLOWED = ['ADMIN', 'DIRECTION'];

export default async function RapportsPage() {
  const me = await getMe();
  if (!me || !ALLOWED.includes(me.role)) return <AccesRefuse />;
  return <RapportsBoard />;
}
