import { Prisma } from '@crm/database';

/**
 * Filtre Prisma des prospects du périmètre de l'appelant (règle unique, partagée par le module prospection et par la
 * tournée personnelle) :
 *  - CHEF_SECTEUR : prospects de ses secteurs, qui lui sont assignés ou qu'il a créés ;
 *  - DIRECTEUR_REGIONAL : prospects de sa région (+ les siens : une fiche créée à la main n'a pas de secteur) ;
 *  - ADMIN / DIRECTION : tout (`{}`).
 *  - tout autre rôle (COMMERCIAL, ADV, MARKETING…) : AUCUN prospect (filtre qui ne correspond à rien). Les écrans de
 *    prospection (crm-web, crm-app) sont réservés à l'encadrement ; un COMMERCIAL autorisé sur les pièces jointes, notes,
 *    appels et emails d'un prospect ne doit pas pour autant lire ou écrire la fiche d'un autre.
 * Se combine par AND avec les autres conditions, jamais à leur place.
 */
export function filtreProspectsDuPerimetre(user: {
  id: string;
  role: string;
  regionId?: string | null;
}): { type: 'secteur' | 'region' | 'global'; where: Prisma.ProspectWhereInput } {
  if (user.role === 'CHEF_SECTEUR') {
    return {
      type: 'secteur',
      where: {
        OR: [{ secteur: { managerId: user.id } }, { assignedToId: user.id }, { createdById: user.id }],
      },
    };
  }
  if (user.role === 'DIRECTEUR_REGIONAL') {
    // Sa région + ses propres fiches : un prospect créé à la main n'a pas de secteur, il doit rester visible par son
    // créateur (sinon 404 post-création).
    return user.regionId
      ? {
          type: 'region',
          where: {
            OR: [{ secteur: { regionId: user.regionId } }, { assignedToId: user.id }, { createdById: user.id }],
          },
        }
      : { type: 'region', where: { OR: [{ assignedToId: user.id }, { createdById: user.id }] } };
  }
  if (user.role === 'ADMIN' || user.role === 'DIRECTION') return { type: 'global', where: {} };
  // Refus par défaut : aucun identifiant ne peut correspondre à une liste vide.
  return { type: 'secteur', where: { id: { in: [] } } };
}
