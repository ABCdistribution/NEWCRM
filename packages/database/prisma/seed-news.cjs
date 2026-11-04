/* eslint-disable no-console */
/**
 * Seed de DÉVELOPPEMENT : les 8 news du prototype ABC Pilot.
 * Les auteurs d'origine ne sont pas des utilisateurs : la news est rattachée à un utilisateur
 * existant (ADMIN/MARKETING de préférence) et le nom d'origine est conservé dans `auteurNom`.
 *
 * Lancement :  node --env-file=../../crm-api/.env prisma/seed-news.cjs
 * Ré-exécutable (idempotent sur le titre). REFUSE de tourner hors base locale.
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

const NEWS = [
  { titre: 'Nouveautés HQ Mai', auteurNom: 'Manon LESAFFRE', date: '2026-05-26', publiee: true, contenu: 'Bonjour à tous, je vous informe que les 3 nouveautés HQ suivantes sont disponibles : masques, cravates et coffrets.' },
  { titre: "JLD MANUCURE - RUPTURE PAE JUSQU'À FIN MAI 2026", auteurNom: 'Marion CARON', date: '2026-05-06', publiee: true, contenu: 'Rupture sur les nouvelles références PAE JLD. Anciennes références à commander : 21244212…' },
  { titre: 'CRAVATE BUCCODENTAIRE APOTEKE DISPONIBLE', auteurNom: 'Manon LESAFFRE', date: '2026-03-11', publiee: true, contenu: "Bonjour à tous, l'ensemble des références buccodentaire APOTEKE est de nouveau disponible (gratuité incluse)." },
  { titre: 'LES MASQUES COREENS ET LA CRAVATE HQ SONT DE NOUVEAU EN STOCK !', auteurNom: 'Manon LESAFFRE', date: '2026-03-10', publiee: true, contenu: 'Bonjour à tous, le masque Collagène HQ Made in Corée est de nouveau en stock ainsi que la cravate.' },
  { titre: 'LES MASQUES HQ MADE IN COREE SONT DISPONIBLES !', auteurNom: 'Manon LESAFFRE', date: '2026-02-17', publiee: true, contenu: 'Tous les masques HQ Made in Corée sont de nouveau en stock ! Ils peuvent être commandés via les codes…' },
  { titre: 'URGENT : RUPTURE 7199 BROSSE STITCH', auteurNom: 'Cécile CALCUL', date: '2025-12-05', publiee: true, contenu: "La référence 7199 brosse Stitch est en rupture. Le switch est d'ores et déjà actif dans le CRM." },
  { titre: 'Rappel – Prêts-à-vendre Mini Prix Franck Provost déjà disponibles !', auteurNom: 'Audrey BRUN', date: '2025-09-23', publiee: true, contenu: 'Bonjour à tous, nous vous rappelons que 2 prêts-à-vendre Franck Provost – Mini Prix sont déjà disponibles.' },
  { titre: 'Disponibilité nouveautés Puériculture – Couverts silicone Tom & Jerry et Thermomètre bain Titi', auteurNom: 'Audrey BRUN', date: '2025-09-23', publiee: false, contenu: "Bonjour à tous, j'ai le plaisir de vous annoncer que de nouvelles références viennent enrichir notre gamme." },
];

async function main() {
  const auteur =
    (await prisma.user.findFirst({ where: { role: 'MARKETING', isActive: true }, orderBy: { username: 'asc' } })) ??
    (await prisma.user.findFirst({ where: { role: 'ADMIN', isActive: true }, orderBy: { username: 'asc' } })) ??
    (await prisma.user.findFirst({ where: { isActive: true }, orderBy: { username: 'asc' } }));
  if (!auteur) {
    console.error('Aucun utilisateur en base : lancer d’abord seed-dev-users.cjs.');
    process.exit(1);
  }

  let crees = 0;
  for (const n of NEWS) {
    const existe = await prisma.news.findFirst({ where: { titre: n.titre, deletedAt: null } });
    if (existe) continue;
    const d = new Date(`${n.date}T09:00:00.000Z`);
    await prisma.news.create({
      data: {
        titre: n.titre,
        contenu: n.contenu,
        publiee: n.publiee,
        publieeAt: n.publiee ? d : null,
        auteurId: auteur.id,
        auteurNom: n.auteurNom,
        createdAt: d,
      },
    });
    crees++;
  }
  console.log(`News : ${crees} créée(s), ${NEWS.length - crees} déjà présente(s).`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
