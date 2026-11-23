import { Prisma } from '@crm/database';
import { PrismaService } from '../prisma/prisma.service';
import { codesRepresentantsDuPerimetre } from './perimetre-codes.util';

/**
 * Filtre Prisma des magasins du périmètre de l'appelant — même règle que « Mes clients » (`GET /clients?mes=1`) :
 * le magasin doit avoir pour représentant (idCommercial1 ou idCommercial2) un code du périmètre
 * (promoteur : le sien ; chef de secteur : ses promoteurs ; directeur régional : ceux de sa région ;
 * ADMIN / DIRECTION / ADV / MARKETING : tout). Se combine par AND avec les autres conditions, jamais à leur place.
 */
export async function filtreClientsDuPerimetre(
  prisma: PrismaService,
  user: { id: string; role: string; idRepr: string | null; regionId?: string | null },
): Promise<Prisma.ClientWhereInput> {
  const codes = await codesRepresentantsDuPerimetre(prisma, { ...user, regionId: user.regionId ?? null });
  if (codes === null) return {};
  if (codes.length === 0) return { id: { in: [] } };
  return { OR: [{ idCommercial1: { in: codes } }, { idCommercial2: { in: codes } }] };
}
