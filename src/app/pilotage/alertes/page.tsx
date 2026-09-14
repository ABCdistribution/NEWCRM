import { getMe } from '@/lib/api';
import { AccesRefuse } from '@/components/acces-refuse';
import { AlertesBoard } from '@/components/alertes-board';

export const metadata = { title: 'Centre d’alertes — Helios' };

const ALLOWED = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

export default async function AlertesPage() {
  const me = await getMe();
  if (!me || !ALLOWED.includes(me.role)) return <AccesRefuse />;
  const canManageRules = me.role === 'ADMIN' || me.role === 'DIRECTION';
  return <AlertesBoard canManageRules={canManageRules} />;
}
