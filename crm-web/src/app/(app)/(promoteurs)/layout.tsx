import { ENCADREMENT, requireRole, type Role } from '@/lib/roles';

/**
 * Écrans terrain. Rôles : COMMERCIAL, ADV, plus l'encadrement (décision : l'encadrement garde
 * l'accès aux écrans terrain). MARKETING : pas de décision, exclu pour l'instant.
 * Chaque page applique en plus sa propre règle via requireRole (cf. routes.ts).
 */
const ROLES: readonly Role[] = ['COMMERCIAL', 'ADV', ...ENCADREMENT];

export default async function PromoteursLayout({ children }: { children: React.ReactNode }) {
  const acces = await requireRole(ROLES);
  if (acces.refuse) return acces.refuse;
  return <>{children}</>;
}
