import { redirect } from 'next/navigation';
import { createElement, type ReactElement } from 'react';
import { AccesRefuse } from '@/components/acces-refuse';
import { getMe, type Me, type Role } from './api';

export type { Role };

/** Encadrement : accès à l'espace Direction commerciale (et aux écrans terrain). */
export const ENCADREMENT: readonly Role[] = ['ADMIN', 'DIRECTION', 'DIRECTEUR_REGIONAL', 'CHEF_SECTEUR'];

/** Terrain : espace Promoteurs (ABC Sales). */
export const TERRAIN: readonly Role[] = ['COMMERCIAL', 'ADV'];

/** Tous les rôles connus de l'API. */
export const TOUS_ROLES: readonly Role[] = [...ENCADREMENT, ...TERRAIN, 'MARKETING'];

/** Espaces de l'application : pilotent le thème (`data-espace`) et le menu. */
export type Espace = 'promoteurs' | 'direction';

export function estEncadrement(role: Role): boolean {
  return ENCADREMENT.includes(role);
}

/** Espace (thème + menu) d'un rôle. */
export function espaceDe(role: Role): Espace {
  if (estEncadrement(role)) return 'direction';
  if (TERRAIN.includes(role)) return 'promoteurs';
  // MARKETING : à définir (espace provisoirement « direction »).
  return 'direction';
}

/**
 * Garde serveur d'une page. Pas de session → redirection vers /login.
 * Rôle non autorisé → renvoie l'écran « Accès refusé » à afficher à la place de la page.
 * Rôle autorisé → renvoie l'utilisateur.
 *
 * Usage : const acces = await requireRole(ROLES); if (acces.refuse) return acces.refuse;
 */
export async function requireRole(
  roles: readonly Role[],
): Promise<{ me: Me; refuse: null } | { me: Me; refuse: ReactElement }> {
  const me = await getMe();
  if (!me) redirect('/login');
  if (!roles.includes(me.role)) {
    return { me, refuse: createElement(AccesRefuse) };
  }
  return { me, refuse: null };
}
