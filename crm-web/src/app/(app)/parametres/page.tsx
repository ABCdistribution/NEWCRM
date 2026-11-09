import { redirect } from 'next/navigation';
import { AccesRefuse } from '@/components/acces-refuse';
import { requireRole } from '@/lib/roles';

export const metadata = { title: 'Paramètres' };

/**
 * Les paramètres sont l'onglet Configuration de l'administration : la page est réservée à ADMIN
 * (même règle que sa ligne dans la table des routes, lib/routes.ts) et y redirige. Les autres rôles
 * voient « Accès refusé ».
 */
export default async function ParametresPage() {
  const acces = await requireRole(['ADMIN']);
  if (acces.refuse) return <AccesRefuse message="Cette page est réservée aux administrateurs." />;
  redirect('/admin?onglet=configuration');
}
