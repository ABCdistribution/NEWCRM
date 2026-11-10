import type { Role } from './roles';

/** Rôles autorisés à éditer promos et PEM (même règle que l'API : ADMIN, DIRECTION, MARKETING). */
export const PROMOS_EDITION: readonly Role[] = ['ADMIN', 'DIRECTION', 'MARKETING'];
