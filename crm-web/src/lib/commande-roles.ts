import type { Role } from './api';

/** Même liste que le @Roles du PATCH /commandes/:id/livraison de l'API (l'API reste juge). */
export const ROLES_LIVRAISON: readonly Role[] = ['ADV', 'DIRECTION', 'ADMIN'];
