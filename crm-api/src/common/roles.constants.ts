import { Role } from '@crm/database';

/** Rôles autorisés à planifier / modifier les plannings et à relancer les promoteurs. */
export const PLANIFICATEURS = [Role.ADMIN, Role.DIRECTION, Role.DIRECTEUR_REGIONAL, Role.CHEF_SECTEUR] as const;
