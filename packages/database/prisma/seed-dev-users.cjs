/* eslint-disable no-console */
/**
 * Comptes FICTIFS pour une base de DÉVELOPPEMENT locale, afin que `seed.cjs` puisse s'y adosser
 * sans passer par la synchro AD (le seed ne crée pas d'utilisateurs).
 *
 * Ces comptes ne peuvent pas se connecter (la connexion passe toujours par l'AD) : ils servent
 * seulement de commerciaux / chefs de secteur dans les données de démonstration.
 *
 * Lancement :  node --env-file=../../crm-api/.env prisma/seed-dev-users.cjs
 * Ré-exécutable (upsert sur le username). REFUSE de tourner hors base locale.
 */
const { PrismaClient } = require('../generated/prisma');
const { PrismaPg } = require('@prisma/adapter-pg');

const url = process.env.DATABASE_URL ?? '';
const hote = (url.match(/@([^:/]+)/) ?? [])[1];
if (!['localhost', '127.0.0.1'].includes(hote)) {
  console.error(`Refusé : DATABASE_URL pointe sur « ${hote ?? 'inconnu'} », pas sur une base locale.`);
  process.exit(1);
}

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });

const COMPTES = [
  ...[1, 2, 3, 4, 5, 6].map((n) => ({
    username: `demo.commercial${n}`,
    displayName: `[DÉMO] Commercial ${n}`,
    role: 'COMMERCIAL',
    idRepr: String(900 + n),
  })),
  { username: 'demo.cs1', displayName: '[DÉMO] Chef de secteur 1', role: 'CHEF_SECTEUR', idRepr: null },
  { username: 'demo.cs2', displayName: '[DÉMO] Chef de secteur 2', role: 'CHEF_SECTEUR', idRepr: null },
  { username: 'demo.dr1', displayName: '[DÉMO] Directeur régional', role: 'DIRECTEUR_REGIONAL', idRepr: null },
];

async function main() {
  for (const c of COMPTES) {
    await prisma.user.upsert({
      where: { username: c.username },
      update: { displayName: c.displayName, role: c.role, idRepr: c.idRepr, isActive: true },
      create: { ...c, isActive: true },
    });
  }
  console.log(`${COMPTES.length} comptes de démonstration prêts.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
