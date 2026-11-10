import { Role } from '@crm/database';

/**
 * Rôles qui ont accès aux commandes et aux visites : tous sauf le marketing (décision de l'utilisateur : le marketing
 * n'a accès ni aux commandes ni aux visites, ni aux historiques qui les contiennent).
 */
export const ROLES_COMMANDES_VISITES = [
  Role.ADMIN,
  Role.DIRECTION,
  Role.DIRECTEUR_REGIONAL,
  Role.CHEF_SECTEUR,
  Role.COMMERCIAL,
  Role.ADV,
] as const;

/** Rôles autorisés à planifier / modifier les plannings et à relancer les promoteurs. */
export const PLANIFICATEURS = [Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL, Role.CHEF_SECTEUR] as const;
