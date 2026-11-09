import { Prisma, Role } from '@crm/database';

type Appelant = { id: string; role: string; regionId?: string | null };

/**
 * Filtre Prisma des utilisateurs que `me` encadre (soi-même exclu), aligné sur `UsersService.findAll` :
 *  - ADMIN / DIRECTION : `{}` (tous) ;
 *  - CHEF_SECTEUR : membres de ses secteurs OU utilisateurs dont il est le manager AD ;
 *  - DIRECTEUR_REGIONAL : sa région OU son équipe directe ;
 *  - autres rôles (COMMERCIAL, ADV, MARKETING) : `null` = aucun périmètre d'encadrement.
 */
export function perimetreEquipe(me: Appelant): Prisma.UserWhereInput | null {
  if (me.role === Role.ADMIN || me.role === Role.DIRECTION) return {};
  if (me.role === Role.CHEF_SECTEUR) {
    return { OR: [{ secteur: { managerId: me.id } }, { directeurId: me.id }] };
  }
  if (me.role === Role.DIRECTEUR_REGIONAL) {
    return me.regionId
      ? { OR: [{ regionId: me.regionId }, { directeurId: me.id }] }
      : { directeurId: me.id };
  }
  return null;
}
