/*
 * Seed COMPLÉMENTAIRE (17/09/2026) : remplit les tables encore vides pour que
 * toutes les pages Helios & Selios aient des données — questionnaire de visite,
 * relevés DN / promos / étapes / réponses, contacts, notes, journal appels &
 * emails (clients et prospects), notifications, opportunités, récurrences de
 * visites (Selios), tournées types, stratégies PEM, switchs d'articles.
 *
 * Idempotent : chaque section est sautée si sa table contient déjà des lignes.
 *
 * Usage (dans le conteneur API, qui porte DATABASE_URL) :
 *   docker cp crm-api/scripts/seed-complements.cjs www-api-1:/app/crm-api/scripts/
 *   docker exec www-api-1 node crm-api/scripts/seed-complements.cjs
 */
const { PrismaClient } = require('@crm/database');
const { PrismaPg } = require('@prisma/adapter-pg');

const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL absent de l’environnement.');
  process.exit(1);
}
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });

// RNG déterministe : le seed produit toujours les mêmes données.
function mulberry32(a) {
  return function () {
    let t = (a += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20260917);
const entre = (min, max) => Math.floor(rand() * (max - min + 1)) + min;
const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const ilYA = (jours, h = 10) => new Date(Date.now() - jours * 864e5 + h * 36e5 - 10 * 36e5);

async function main() {
  // Matière première : visites, magasins actifs avec promoteur, prospects, articles, utilisateurs.
  const visites = await prisma.visite.findMany({
    where: { deletedAt: null },
    orderBy: { createdAt: 'desc' },
    take: 40,
    select: { id: true, clientId: true, promoteurId: true, createdAt: true },
  });
  const marques = await prisma.marque.findMany({ select: { nom: true } });
  const articles = await prisma.article.findMany({
    where: { actif: true },
    take: 24,
    orderBy: { codeAs400: 'asc' },
    select: { id: true, libelle: true },
  });
  const prospects = await prisma.prospect.findMany({
    where: { deletedAt: null },
    select: { id: true, enseigne: true, assignedToId: true, createdById: true, email: true },
  });
  const chefs = await prisma.user.findMany({
    where: { role: 'CHEF_SECTEUR', isActive: true },
    orderBy: { displayName: 'asc' },
    take: 5,
    select: { id: true, displayName: true, idRepr: true },
  });
  const directeurs = await prisma.user.findMany({
    where: { role: 'DIRECTEUR_REGIONAL', isActive: true },
    take: 3,
    select: { id: true, displayName: true },
  });
  const promoteurs = await prisma.user.findMany({
    where: { role: 'COMMERCIAL', isActive: true, username: { startsWith: 'demo.' } },
    select: { id: true, displayName: true, idRepr: true },
  });
  const admin = await prisma.user.findFirst({ where: { role: 'ADMIN' }, select: { id: true } });
  // Magasins « vivants » : ceux qui ont déjà une visite ou une commande de démo.
  const clientIds = [...new Set(visites.map((v) => v.clientId).filter(Boolean))];
  const magasins = await prisma.client.findMany({
    where: { id: { in: clientIds }, deletedAt: null },
    select: { id: true, enseigne: true, email: true, idCommercial1: true, idCommercial2: true },
  });
  const csParCode = new Map();
  for (const u of [...chefs, ...promoteurs]) {
    if (u.idRepr) {
      csParCode.set(u.idRepr, u);
      csParCode.set(String(Number(u.idRepr)), u);
    }
  }
  const auteurDuMagasin = (m) =>
    csParCode.get(m.idCommercial2 ?? '') ?? csParCode.get(m.idCommercial1 ?? '') ?? chefs[0] ?? admin;

  // --- 1. Questionnaire de visite -----------------------------------------
  if ((await prisma.questionVisite.count()) === 0) {
    const QUESTIONS = [
      { libelle: 'Le rayon est-il conforme au planogramme ?', type: 'CASE_A_COCHER', ordre: 1, obligatoire: true },
      { libelle: 'PLV de la promo en cours posée ?', type: 'CASE_A_COCHER', ordre: 2, obligatoire: true },
      { libelle: 'Nombre de facings ABC relevés', type: 'NOMBRE', ordre: 3, obligatoire: false },
      { libelle: 'État général du rayon (1 à 5)', type: 'NOTE_1_5', ordre: 4, obligatoire: false },
      { libelle: 'Remarques du chef de rayon', type: 'TEXTE', ordre: 5, obligatoire: false },
    ];
    for (const q of QUESTIONS) {
      await prisma.questionVisite.create({ data: { ...q, creeParId: admin?.id ?? null } });
    }
    console.log(`✔ Questionnaire de visite : ${QUESTIONS.length} questions`);
  } else console.log('· Questionnaire déjà présent');

  // --- 2. Détails des visites : DN, étapes, promos, réponses ---------------
  if ((await prisma.visiteDN.count()) === 0 && visites.length > 0) {
    const questions = await prisma.questionVisite.findMany({ orderBy: { ordre: 'asc' } });
    let dns = 0;
    for (const v of visites.slice(0, 30)) {
      await prisma.visiteDN.createMany({
        data: [
          { visiteId: v.id, type: 'ABC', marque: pick(marques)?.nom ?? 'ABC', metrage: entre(2, 8) },
          { visiteId: v.id, type: 'CONCURRENCE', marque: pick(['L\'Oréal', 'Gilbert', 'Vivelle Dop', 'MDD']), metrage: entre(3, 10) },
        ],
      });
      dns += 2;
      await prisma.visiteStep.createMany({
        data: [
          { visiteId: v.id, etape: 'ARRIVEE', horodatage: v.createdAt },
          { visiteId: v.id, etape: 'RELEVE_RAYON', horodatage: new Date(v.createdAt.getTime() + 15 * 6e4) },
          { visiteId: v.id, etape: 'DEPART', horodatage: new Date(v.createdAt.getTime() + entre(25, 55) * 6e4) },
        ],
      });
      if (articles.length && rand() < 0.6) {
        await prisma.visitePromo.create({ data: { visiteId: v.id, articleId: pick(articles).id } });
      }
      for (const q of questions) {
        const valeur =
          q.type === 'CASE_A_COCHER' ? pick(['oui', 'non', 'oui']) :
          q.type === 'NOMBRE' ? String(entre(4, 24)) :
          q.type === 'NOTE_1_5' ? String(entre(2, 5)) :
          pick(['RAS', 'Prévoir réassort gamme soin', 'Demande PLV comptoir', 'Chef de rayon absent']);
        await prisma.visiteReponse.create({ data: { visiteId: v.id, questionId: q.id, valeur } });
      }
    }
    console.log(`✔ Détails de visites : ${dns} relevés DN, étapes, promos & réponses sur ${Math.min(visites.length, 30)} visites`);
  } else console.log('· Détails de visites déjà présents');

  // --- 3. Contacts & notes des magasins ------------------------------------
  if ((await prisma.clientContact.count()) === 0 && magasins.length > 0) {
    const PRENOMS = ['Claire', 'Marc', 'Sophie', 'Julien', 'Nadia', 'Paul', 'Emma', 'Karim'];
    const NOMS = ['Lefèvre', 'Garnier', 'Rossi', 'Petit', 'Nguyen', 'Moreau', 'Blanc', 'Dupas'];
    let n = 0;
    for (const m of magasins.slice(0, 15)) {
      const auteur = auteurDuMagasin(m);
      await prisma.clientContact.create({
        data: {
          clientId: m.id, prenom: pick(PRENOMS), nom: pick(NOMS), typePoste: 'Chef de rayon',
          poste: 'Rayon hygiène-beauté', portable: `06 ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)}`,
          mail: `rayon.hb@${m.enseigne.toLowerCase().replace(/[^a-z]/g, '')}.fr`.slice(0, 60), creeParId: auteur?.id ?? null,
        },
      });
      await prisma.clientContact.create({
        data: {
          clientId: m.id, prenom: pick(PRENOMS), nom: pick(NOMS), typePoste: 'Directeur',
          poste: 'Direction du magasin', fixe: `04 ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)}`,
          creeParId: auteur?.id ?? null,
        },
      });
      await prisma.clientNote.create({
        data: {
          clientId: m.id, auteurId: auteur?.id ?? null,
          remarque: pick([
            'Réagencement du rayon prévu le mois prochain — repasser poser la PLV.',
            'Bon accueil, le directeur souhaite une OP sur les accessoires cheveux.',
            'Attention : concurrent très présent en tête de gondole.',
            'Demande un réassort rapide sur la gamme manucure.',
          ]),
          createdAt: ilYA(entre(1, 20)),
        },
      });
      n++;
    }
    console.log(`✔ Contacts & notes : ${n} magasins équipés (2 contacts + 1 note)`);
  } else console.log('· Contacts magasins déjà présents');

  // --- 4. Journal appels & emails des magasins (nouvelles tables) ----------
  if ((await prisma.clientAppel.count()) === 0 && magasins.length > 0) {
    let n = 0;
    for (const m of magasins.slice(0, 12)) {
      const auteur = auteurDuMagasin(m);
      await prisma.clientAppel.create({
        data: {
          clientId: m.id, auteurId: auteur?.id ?? null, dateAppel: ilYA(entre(0, 12)),
          dureeSec: entre(60, 540), resultat: pick(['REPONDU', 'REPONDU', 'MESSAGERIE', 'RAPPEL_PREVU']),
          commentaire: pick(['Point commandes du mois.', 'Relance sur la promo en cours.', null, 'Prise de RDV tournée.']),
        },
      });
      if (rand() < 0.7) {
        await prisma.clientEmail.create({
          data: {
            clientId: m.id, auteurId: auteur?.id ?? null, dateEmail: ilYA(entre(0, 15)),
            destinataire: m.email ?? 'contact@magasin.fr',
            sujet: pick(['Confirmation de passage', 'Catalogue promos du mois', 'Suivi de commande']),
          },
        });
      }
      n++;
    }
    console.log(`✔ Journal magasins : appels/emails sur ${n} magasins`);
  } else console.log('· Journal magasins déjà présent');

  // --- 5. Emails prospects (la table appels est déjà servie) ----------------
  if ((await prisma.prospectEmail.count()) === 0 && prospects.length > 0) {
    let n = 0;
    for (const p of prospects) {
      if (rand() < 0.6) continue;
      await prisma.prospectEmail.create({
        data: {
          prospectId: p.id, auteurId: p.assignedToId ?? p.createdById ?? null, dateEmail: ilYA(entre(0, 10)),
          destinataire: p.email ?? 'contact@prospect.fr',
          sujet: pick(['Présentation ABC Distribution', 'Proposition de référencement', 'Suite à notre échange']),
          commentaire: pick([null, 'Catalogue joint.', 'Relance après appel sans réponse.']),
        },
      });
      n++;
    }
    console.log(`✔ Emails prospects : ${n}`);
  } else console.log('· Emails prospects déjà présents');

  // --- 6. Notifications (cloche Selios) -------------------------------------
  if ((await prisma.notification.count()) === 0) {
    const destinataires = [...chefs, ...directeurs, ...promoteurs, ...(admin ? [admin] : [])];
    let n = 0;
    for (const u of destinataires) {
      const modeles = [
        { type: 'RELANCE_VISITE', titre: 'Magasin à revisiter', message: 'INTERMARCHE n’a pas été visité depuis plus de 30 jours.', lien: '/clients' },
        { type: 'RAPPEL_QUALITE', titre: 'Rappel produit en cours', message: 'Un article de la gamme soin fait l’objet d’un rappel : vérifier les magasins.', lien: '/qualite' },
        { type: 'PROMO_DEBUT', titre: 'Nouvelle promo active', message: 'L’OP « rentrée beauté » démarre aujourd’hui dans vos magasins.', lien: '/promos' },
      ];
      for (const [i, mo] of modeles.entries()) {
        await prisma.notification.create({
          data: { userId: u.id, ...mo, luAt: i === 2 ? ilYA(1) : null, createdAt: ilYA(entre(0, 5)) },
        });
        n++;
      }
    }
    console.log(`✔ Notifications : ${n} pour ${destinataires.length} utilisateurs`);
  } else console.log('· Notifications déjà présentes');

  // --- 7. Opportunités (référencements, OP, mises en avant) -----------------
  if ((await prisma.opportunite.count()) === 0) {
    let n = 0;
    for (const p of prospects.slice(0, 5)) {
      await prisma.opportunite.create({
        data: {
          type: 'REFERENCEMENT', prospectId: p.id, libelle: `Référencement gamme accessoires — ${p.enseigne}`,
          valeurEstimee: entre(4, 30) * 1000, statut: 'OUVERTE', assignedToId: p.assignedToId ?? null,
          articles: articles.length ? { connect: articles.slice(0, 3).map((a) => ({ id: a.id })) } : undefined,
        },
      });
      n++;
    }
    for (const m of magasins.slice(0, 6)) {
      const auteur = auteurDuMagasin(m);
      await prisma.opportunite.create({
        data: {
          type: pick(['OP', 'MISE_EN_AVANT']), clientId: m.id,
          libelle: pick([`OP fêtes des mères — ${m.enseigne}`, `Tête de gondole soin — ${m.enseigne}`, `Box comptoir manucure — ${m.enseigne}`]),
          valeurEstimee: entre(1, 12) * 500, statut: pick(['OUVERTE', 'OUVERTE', 'GAGNEE']),
          dateDebut: ilYA(entre(5, 20)), dateFin: new Date(Date.now() + entre(10, 40) * 864e5),
          assignedToId: auteur?.id ?? null,
          articles: articles.length ? { connect: [{ id: pick(articles).id }] } : undefined,
        },
      });
      n++;
    }
    console.log(`✔ Opportunités : ${n}`);
  } else console.log('· Opportunités déjà présentes');

  // --- 8. Récurrences de visites Selios (Plannification) --------------------
  if ((await prisma.plannification.count()) === 0 && promoteurs.length > 0) {
    // Ancre : lundi de la semaine courante.
    const lundi = new Date();
    lundi.setDate(lundi.getDate() - ((lundi.getDay() + 6) % 7));
    lundi.setHours(8, 0, 0, 0);
    let n = 0;
    for (const promo of promoteurs) {
      const codes = [promo.idRepr, String(Number(promo.idRepr))].filter(Boolean);
      const siens = await prisma.client.findMany({
        where: { deletedAt: null, actif: true, OR: [{ idCommercial1: { in: codes } }, { idCommercial2: { in: codes } }] },
        take: 4,
        select: { id: true },
      });
      for (const c of siens) {
        await prisma.plannification.create({
          data: {
            promoteurId: promo.id, clientId: c.id,
            jours: pick(['1', '2', '4', '1,4', '2,5']), recurrence: pick([1, 1, 2]),
            dateDebut: new Date(lundi.getTime() - entre(1, 4) * 7 * 864e5),
          },
        });
        n++;
      }
    }
    console.log(`✔ Récurrences de visites (Selios) : ${n}`);
  } else console.log('· Récurrences déjà présentes');

  // --- 9. Tournées types (Helios, modèle Tournee) ---------------------------
  if ((await prisma.tournee.count()) === 0) {
    const porteurs = [...chefs, ...promoteurs];
    const annee = new Date().getFullYear();
    let n = 0;
    for (const u of porteurs) {
      const codes = [u.idRepr, String(Number(u.idRepr))].filter(Boolean);
      const siens = await prisma.client.findMany({
        where: { deletedAt: null, actif: true, OR: [{ idCommercial1: { in: codes } }, { idCommercial2: { in: codes } }] },
        take: 3,
        select: { id: true },
      });
      for (const c of siens) {
        await prisma.tournee.create({
          data: {
            promoteurId: u.id, clientId: c.id,
            jours: pick(['1', '2', '3', '4']), semaines: pick(['1,3', '2,4', '1,2,3,4']),
            semaineDebut: entre(36, 38), annee,
          },
        });
        n++;
      }
    }
    console.log(`✔ Tournées types : ${n}`);
  } else console.log('· Tournées types déjà présentes');

  // --- 10. Stratégies PEM + switchs d'articles ------------------------------
  if ((await prisma.stratPem.count()) === 0 && articles.length >= 6) {
    const strat = await prisma.stratPem.create({ data: { nom: 'Rentrée beauté 2026', actif: true } });
    for (let i = 0; i < 4; i++) {
      await prisma.stratPemLigne.create({ data: { stratPemId: strat.id, articleId: articles[i].id, ordre: i + 1 } });
    }
    const strat2 = await prisma.stratPem.create({ data: { nom: 'Fond de rayon prioritaire', actif: true } });
    for (let i = 4; i < 6; i++) {
      await prisma.stratPemLigne.create({ data: { stratPemId: strat2.id, articleId: articles[i].id, ordre: i - 3 } });
    }
    console.log('✔ Stratégies PEM : 2 (6 lignes)');
  } else console.log('· Stratégies PEM déjà présentes');

  if ((await prisma.articleSwitch.count()) === 0 && articles.length >= 8) {
    for (let i = 0; i < 3; i++) {
      await prisma.articleSwitch.create({
        data: { articleId: articles[i].id, cibleId: articles[i + 4].id, seuil: entre(2, 6) },
      });
    }
    console.log('✔ Switchs d’articles : 3');
  } else console.log('· Switchs déjà présents');

  console.log('Seed complémentaire terminé.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
