/* eslint-disable no-console */
/**
 * Complément de seed de DÉVELOPPEMENT : alimente les graphiques de prospection du pilotage
 * (« CA réalisé vs objectif » par semaine) en créant
 *   - des prospects GAGNÉS, convertis en magasins (avec leur potentiel annuel),
 *   - des commandes datées du MOIS EN COURS pour ces magasins,
 *   - des prospects encore ouverts (pipeline pondéré).
 * À lancer APRÈS `seed.cjs` (il s'appuie sur ses clients, articles et commerciaux).
 *
 * Lancement :  node --env-file=../../crm-api/.env prisma/seed-prospection.cjs
 * Ré-exécutable (clés d'idempotence DEMO-*). REFUSE de tourner hors base locale.
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

const GAGNES_POTENTIEL = [240000, 180000, 150000, 120000, 90000, 60000]; // somme 840 000 € → cible mensuelle 70 000 €
const OUVERTS = [
  { statut: 'NOUVEAU', probabilite: 10, potentiel: 40000 },
  { statut: 'NOUVEAU', probabilite: 10, potentiel: 25000 },
  { statut: 'CONTACTE', probabilite: 25, potentiel: 60000 },
  { statut: 'CONTACTE', probabilite: 25, potentiel: 35000 },
  { statut: 'PROPOSITION', probabilite: 40, potentiel: 90000 },
  { statut: 'VISITE', probabilite: 55, potentiel: 75000 },
  { statut: 'NEGOCIATION', probabilite: 70, potentiel: 150000 },
  { statut: 'NEGOCIATION', probabilite: 70, potentiel: 110000 },
];

async function main() {
  const commerciaux = await prisma.user.findMany({
    where: { role: 'COMMERCIAL', idRepr: { not: null }, isActive: true },
    orderBy: { username: 'asc' },
  });
  const articles = await prisma.article.findMany({ where: { familleId: { not: null } }, take: 60 });
  const candidats = await prisma.client.findMany({
    where: { deletedAt: null, prospectOrigine: { is: null } },
    orderBy: { codeAs400: 'asc' },
    take: GAGNES_POTENTIEL.length,
  });
  if (commerciaux.length === 0 || articles.length === 0 || candidats.length < GAGNES_POTENTIEL.length) {
    throw new Error("Données insuffisantes : lancer d'abord seed-dev-users.cjs puis seed.cjs.");
  }

  // 1) Prospects gagnés = magasins existants « issus de la prospection »
  let prospectsCrees = 0;
  for (let i = 0; i < candidats.length; i++) {
    const c = candidats[i];
    const idApk = `DEMO-GAGNE-${i + 1}`;
    if (await prisma.prospect.findUnique({ where: { idApk } })) continue;
    await prisma.prospect.create({
      data: {
        raisonSociale: c.raisonSociale,
        enseigne: c.enseigne ?? c.raisonSociale,
        ville: c.ville,
        statut: 'GAGNE',
        probabilite: 100,
        potentielCaAnnuel: GAGNES_POTENTIEL[i],
        source: 'TERRAIN',
        assignedToId: commerciaux[i % commerciaux.length].id,
        clientId: c.id,
        idApk,
      },
    });
    prospectsCrees++;
  }

  // 2) Commandes du mois en cours, étalées du 2 à aujourd'hui, pour ces magasins
  const maintenant = new Date();
  const jourMax = Math.max(2, maintenant.getDate());
  let commandesCreees = 0;
  let n = 0;
  for (let i = 0; i < candidats.length; i++) {
    for (let k = 0; k < 2; k++) {
      n++;
      const numero = `DEMOP${String(n).padStart(6, '0')}`;
      if (await prisma.commande.findUnique({ where: { numero } })) continue;
      const jour = 2 + Math.floor(((jourMax - 2) * ((i * 2 + k) / (candidats.length * 2 - 1))));
      const commande = await prisma.commande.create({
        data: {
          numero,
          clientId: candidats[i].id,
          raisonSocialeCmd: candidats[i].raisonSociale,
          idRepr: candidats[i].idCommercial1,
          typeCmd: 'CDE',
          dateCommande: new Date(maintenant.getFullYear(), maintenant.getMonth(), jour, 10, 0, 0),
          statutLivraison: 'EN_PREPARATION',
        },
      });
      for (let l = 1; l <= 3; l++) {
        const art = articles[(n * 3 + l) % articles.length];
        await prisma.commandeLigne.create({
          data: {
            commandeId: commande.id,
            noLigne: String(l * 10),
            articleId: art.id,
            libelleArticle: art.libelle,
            quantite: '24.0000',
            montant: String(((n + l) % 4) * 120 + 360) + '.0000', // 360 à 720 € par ligne
          },
        });
      }
      commandesCreees++;
    }
  }

  // 3) Prospects encore ouverts (pipeline pondéré)
  let ouvertsCrees = 0;
  for (let i = 0; i < OUVERTS.length; i++) {
    const idApk = `DEMO-OUVERT-${i + 1}`;
    if (await prisma.prospect.findUnique({ where: { idApk } })) continue;
    const o = OUVERTS[i];
    await prisma.prospect.create({
      data: {
        raisonSociale: `[DÉMO] Prospect ${i + 1}`,
        enseigne: `[DÉMO] Enseigne ${i + 1}`,
        ville: ['Lyon', 'Lille', 'Nantes', 'Bordeaux', 'Toulouse', 'Rennes', 'Nice', 'Dijon'][i],
        statut: o.statut,
        probabilite: o.probabilite,
        potentielCaAnnuel: o.potentiel,
        source: ['SALON', 'RECOMMANDATION', 'TERRAIN', 'WEB'][i % 4],
        assignedToId: commerciaux[i % commerciaux.length].id,
        idApk,
      },
    });
    ouvertsCrees++;
  }

  console.log(`Prospection de démo : ${prospectsCrees} gagnés, ${commandesCreees} commandes du mois, ${ouvertsCrees} ouverts.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
