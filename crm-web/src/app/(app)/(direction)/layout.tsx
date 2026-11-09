import { ENCADREMENT, requireRole } from '@/lib/roles';

/** Écrans de la Direction commerciale : encadrement uniquement (COMMERCIAL / ADV → accès refusé). */
export default async function DirectionLayout({ children }: { children: React.ReactNode }) {
  const acces = await requireRole(ENCADREMENT);
  if (acces.refuse) return acces.refuse;
  return <>{children}</>;
}
