import { redirect } from 'next/navigation';
import { AccesRefuse } from '@/components/acces-refuse';
import { requireRole, TOUS_ROLES } from '@/lib/roles';

export const metadata = { title: 'Paramètres' };

/** Les paramètres sont l'onglet Configuration de l'administration (ADMIN) ; les autres rôles n'y ont pas accès. */
export default async function ParametresPage() {
  const acces = await requireRole(TOUS_ROLES);
  if (acces.refuse) return acces.refuse;
  if (acces.me.role === 'ADMIN') redirect('/admin?onglet=configuration');
  return <AccesRefuse message="Cette page est réservée aux administrateurs." />;
}
