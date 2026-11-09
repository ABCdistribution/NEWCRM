import { requireRole, ENCADREMENT } from '@/lib/roles';
import { AlertesBoard } from '@/components/alertes-board';

export const metadata = { title: 'Centre d’alertes — Direction commerciale' };

export default async function AlertesPage() {
  const acces = await requireRole(ENCADREMENT);
  if (acces.refuse) return acces.refuse;
  const canManageRules = acces.me.role === 'ADMIN' || acces.me.role === 'DIRECTION';
  return <AlertesBoard canManageRules={canManageRules} />;
}
