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
 *
 * ATTENTION : un layout ne protège pas les pages ni les Server Actions : chaque page [id] / action /
 * route handler doit rappeler requireRole (ou exigerRole dans une action) ou s'appuyer sur l'API.
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

/**
 * Variante pour les Server Actions : renvoie l'utilisateur si son rôle est autorisé,
 * sinon lève une erreur « Accès refusé » (à intercepter pour renvoyer un message à l'utilisateur).
 * Pas de session : lève aussi (une action ne redirige pas proprement vers /login).
 */
export async function exigerRole(roles: readonly Role[]): Promise<Me> {
  const me = await getMe();
  if (!me || !roles.includes(me.role)) throw new Error('Accès refusé');
  return me;
}
