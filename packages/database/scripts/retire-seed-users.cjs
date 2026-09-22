/**
 * One-off : réattribue les données seedées des FAUX utilisateurs (seed initial)
 * vers les VRAIS utilisateurs AD (synchro /sync/ad), puis supprime les faux.
 */
const { PrismaClient } = require('../generated/prisma');
const { PrismaPg } = require('@prisma/adapter-pg');

require('dotenv').config();
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });

const FAKE = {
  DR: ['jl.moreau', 'c.fabre'],
  CS: ['m.lefevre', 's.garnier'],
  COM: ['p.durand', 'a.rousseau', 'k.benali', 'e.martin', 'l.girard', 'n.petit'],
};
const ALL_FAKE = [...FAKE.DR, ...FAKE.CS, ...FAKE.COM];

async function main() {
  const fakes = await prisma.user.findMany({ where: { username: { in: ALL_FAKE } } });
  if (fakes.length === 0) {
    console.log('Aucun faux utilisateur — rien à faire.');
    return;
  }
  const notFake = { username: { notIn: ALL_FAKE } };
  const realCom = await prisma.user.findMany({
    where: { ...notFake, role: 'COMMERCIAL', idRepr: { not: null } },
    orderBy: { username: 'asc' },
  });
  const realCs = await prisma.user.findMany({ where: { ...notFake, role: 'CHEF_SECTEUR' }, orderBy: { username: 'asc' } });
  const realDr = await prisma.user.findMany({ where: { ...notFake, role: 'DIRECTEUR_REGIONAL' }, orderBy: { username: 'asc' } });
  if (realCom.length === 0) throw new Error('Aucun vrai commercial en base — lancer la synchro AD d’abord.');

  // fake.id -> vrai user (round-robin par rôle, repli commerciaux)
  const map = new Map();
  let iCom = 0, iCs = 0, iDr = 0;
  for (const f of fakes) {
    if (FAKE.DR.includes(f.username) && realDr.length) map.set(f.id, realDr[iDr++ % realDr.length]);
    else if (FAKE.CS.includes(f.username) && realCs.length) map.set(f.id, realCs[iCs++ % realCs.length]);
    else map.set(f.id, realCom[iCom++ % realCom.length]);
  }
  for (const f of fakes) console.log(`  ${f.username} (${f.idRepr ?? '—'}) → ${map.get(f.id).username} (${map.get(f.id).idRepr ?? '—'})`);

  for (const f of fakes) {
    const real = map.get(f.id);
    // FKs simples : tout ce que le faux user possède passe au vrai.
    await prisma.visite.updateMany({ where: { promoteurId: f.id }, data: { promoteurId: real.id } });
    await prisma.planning.updateMany({ where: { promoteurId: f.id }, data: { promoteurId: real.id } });
    await prisma.plannification.updateMany({ where: { promoteurId: f.id }, data: { promoteurId: real.id } });
    await prisma.tournee.updateMany({ where: { promoteurId: f.id }, data: { promoteurId: real.id } });
    await prisma.commandeApk.updateMany({ where: { promoteurId: f.id }, data: { promoteurId: real.id } });
    await prisma.clientContact.updateMany({ where: { creeParId: f.id }, data: { creeParId: real.id } });
    await prisma.clientNote.updateMany({ where: { auteurId: f.id }, data: { auteurId: real.id } });
    await prisma.clientPeriodicite.updateMany({ where: { affecteParId: f.id }, data: { affecteParId: real.id } });
    await prisma.articleSwitch.updateMany({ where: { creeParId: f.id }, data: { creeParId: real.id } });
    await prisma.objectif.updateMany({ where: { creeParId: f.id }, data: { creeParId: real.id } });
    await prisma.questionVisite.updateMany({ where: { creeParId: f.id }, data: { creeParId: real.id } });
    await prisma.client.updateMany({ where: { creeParId: f.id }, data: { creeParId: real.id } });
    await prisma.notification.updateMany({ where: { userId: f.id }, data: { userId: real.id } });
    await prisma.notification.updateMany({ where: { emetteurId: f.id }, data: { emetteurId: real.id } });
    await prisma.secteur.updateMany({ where: { managerId: f.id }, data: { managerId: real.id } });
    await prisma.user.updateMany({ where: { directeurId: f.id }, data: { directeurId: null } });

    // Codes représentants portés par les données seedées (clients + commandes ERP).
    if (f.idRepr && real.idRepr) {
      await prisma.client.updateMany({ where: { idCommercial1: f.idRepr }, data: { idCommercial1: real.idRepr } });
      await prisma.client.updateMany({ where: { idCommercial2: f.idRepr }, data: { idCommercial2: real.idRepr } });
      await prisma.commande.updateMany({ where: { idRepr: f.idRepr }, data: { idRepr: real.idRepr } });
    }

    // N-N _ClientCommerciaux : remplacer le faux par le vrai sur chaque client suivi.
    const suivis = await prisma.client.findMany({ where: { commerciaux: { some: { id: f.id } } }, select: { id: true } });
    for (const cl of suivis) {
      await prisma.client.update({
        where: { id: cl.id },
        data: { commerciaux: { disconnect: { id: f.id }, connect: { id: real.id } } },
      });
    }
  }

  const del = await prisma.user.deleteMany({ where: { username: { in: ALL_FAKE } } });
  console.log(`Faux utilisateurs supprimés : ${del.count}`);
}

main()
  .catch((e) => { console.error(e); process.exitCode = 1; })
  .finally(() => prisma.$disconnect());
