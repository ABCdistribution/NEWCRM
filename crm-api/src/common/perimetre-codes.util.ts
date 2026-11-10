import { PrismaService } from '../prisma/prisma.service';
import { idReprVariants } from './id-repr.util';

/**
 * Codes représentants du périmètre de l'utilisateur (variantes « 68 » ↔ « 068 » incluses).
 *  - ADMIN / DIRECTION / ADV / MARKETING : `null` = pas de restriction ;
 *  - COMMERCIAL : son propre code (`[]` s'il n'est relié à aucun code) ;
 *  - CHEF_SECTEUR : ses promoteurs (hiérarchie AD), repli sur sa région si son équipe n'est pas renseignée ;
 *  - DIRECTEUR_REGIONAL : tous les promoteurs de sa région.
 * `[]` = périmètre vide : l'appelant ne doit rien renvoyer.
 */
export async function codesRepresentantsDuPerimetre(
  prisma: PrismaService,
  user: { id: string; role: string; idRepr: string | null; regionId: string | null },
): Promise<string[] | null> {
  if (user.role === 'ADMIN' || user.role === 'DIRECTION' || user.role === 'ADV' || user.role === 'MARKETING') {
    return null;
  }
  if (user.role === 'COMMERCIAL') {
    return user.idRepr ? idReprVariants(user.idRepr) : [];
  }
  // Chef de secteur : les promoteurs dont il est le manager (hiérarchie AD) ;
  // repli sur sa région si son équipe n'est pas renseignée dans l'annuaire.
  let membres: { idRepr: string | null }[] = [];
  if (user.role === 'CHEF_SECTEUR') {
    membres = await prisma.user.findMany({
      where: { role: 'COMMERCIAL', directeurId: user.id, idRepr: { not: null } },
      select: { idRepr: true },
    });
  }
  if (membres.length === 0 && user.regionId) {
    // DR (cas nominal) et CS sans équipe : tous les promoteurs de la région.
    membres = await prisma.user.findMany({
      where: { role: 'COMMERCIAL', regionId: user.regionId, idRepr: { not: null } },
      select: { idRepr: true },
    });
  }
  return membres.flatMap((m) => (m.idRepr ? idReprVariants(m.idRepr) : []));
}
