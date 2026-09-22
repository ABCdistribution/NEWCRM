/**
 * One-off : initialise le suivi de livraison des commandes existantes selon
 * leur ancienneté (données de démo — le vrai suivi sera tenu par l'ADV) :
 *   - commande non annulée de plus de 7 jours  → LIVREE  (livrée à J+3)
 *   - entre 2 et 7 jours                       → EXPEDIEE (expédiée à J+1)
 *   - moins de 2 jours                         → EN_PREPARATION (défaut)
 * Ne touche pas aux commandes déjà passées à un autre statut que le défaut.
 */
require('dotenv').config();
const { PrismaClient } = require('../generated/prisma');
const { PrismaPg } = require('@prisma/adapter-pg');

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });

async function main() {
  const jours = (n) => new Date(Date.now() - n * 24 * 3600 * 1000);

  const livrees = await prisma.$executeRaw`
    UPDATE commandes
    SET "statutLivraison" = 'LIVREE',
        "dateExpedition"  = "dateCommande" + interval '1 day',
        "dateLivraison"   = "dateCommande" + interval '3 days'
    WHERE "dateAnnulation" IS NULL
      AND "statutLivraison" = 'EN_PREPARATION'
      AND "dateCommande" < ${jours(7)}`;

  const expediees = await prisma.$executeRaw`
    UPDATE commandes
    SET "statutLivraison" = 'EXPEDIEE',
        "dateExpedition"  = "dateCommande" + interval '1 day'
    WHERE "dateAnnulation" IS NULL
      AND "statutLivraison" = 'EN_PREPARATION'
      AND "dateCommande" >= ${jours(7)}
      AND "dateCommande" < ${jours(2)}`;

  console.log(`Livrées : ${livrees} · Expédiées : ${expediees} · le reste demeure EN_PREPARATION`);
}

main()
  .catch((e) => { console.error(e); process.exitCode = 1; })
  .finally(() => prisma.$disconnect());
