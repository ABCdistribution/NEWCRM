/**
 * Provisionne (ou met à jour) un utilisateur AD dans le CRM sans attendre son
 * premier login — utile pour les comptes hors force de vente (siège, direction)
 * que la synchro en masse (POST /sync/ad) ne parcourt pas.
 *
 * Usage : node scripts/provision-user.cjs <username> <ROLE> [displayName]
 *   ex.  : node scripts/provision-user.cjs rabah.chabane DIRECTION "Rabah CHABANE"
 *
 * Le compte est complété (email, photo, région…) à sa première connexion.
 */
require('dotenv').config();
const { PrismaClient } = require('../generated/prisma');
const { PrismaPg } = require('@prisma/adapter-pg');

const ROLES = ['COMMERCIAL', 'CHEF_SECTEUR', 'ADMIN', 'DIRECTEUR_REGIONAL', 'DIRECTION', 'ADV', 'MARKETING'];

const [username, role, displayName] = process.argv.slice(2);
if (!username || !ROLES.includes(role)) {
  console.error(`Usage : node scripts/provision-user.cjs <username> <${ROLES.join('|')}> [displayName]`);
  process.exit(1);
}

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });

prisma.user
  .upsert({
    where: { username },
    update: { role },
    create: { username, displayName: displayName ?? username, role },
  })
  .then((u) => console.log(`${u.username} → ${u.role} | actif: ${u.isActive}`))
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
