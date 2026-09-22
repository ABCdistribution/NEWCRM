/* eslint-disable no-console */
/**
 * Seed de DÉVELOPPEMENT / RECETTE — peuple TOUTES les tables avec des données
 * réalistes au format Minos/AS400, pour tester l'application avant le vrai import.
 *
 * Lancement :  pnpm --filter @crm/database db:seed   (ou : node prisma/seed.cjs)
 *
 * Ré-exécutable :
 *  - référentiels (régions, secteurs, users, centrales, catalogue, clients…) : upsert
 *    sur leur clé métier (code, codeAs400, username, numero…) ;
 *  - données transactionnelles (visites, commandes, plannings…) : créées seulement
 *    si leur table est vide, pour ne jamais dupliquer.
 *
 * Les codes AS400 seedés sont préfixés « 9 » (clients 9xxxx, articles 9xxxxx) pour
 * ne pas entrer en collision avec les vrais codes lors de l'import ERP à venir.
 */
const { PrismaClient } = require('../generated/prisma');
const { PrismaPg } = require('@prisma/adapter-pg');
require('dotenv').config();

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

// --- Aléatoire DÉTERMINISTE (mulberry32) : mêmes données à chaque exécution. ---
let rngState = 0xabc0123;
function rand() {
  rngState |= 0;
  rngState = (rngState + 0x6d2b79f5) | 0;
  let t = Math.imul(rngState ^ (rngState >>> 15), 1 | rngState);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const int = (min, max) => min + Math.floor(rand() * (max - min + 1));
const chance = (p) => rand() < p;
const daysAgo = (n) => new Date(Date.now() - n * 24 * 3600 * 1000);
const daysAhead = (n) => new Date(Date.now() + n * 24 * 3600 * 1000);

async function main() {
  console.log('— Seed CRM ABC —');

  // =====================================================================
  // 1) Régions & secteurs
  // =====================================================================
  const regionsDef = [
    { code: 'NORD', nom: 'Nord' },
    { code: 'SUD', nom: 'Sud' },
  ];
  const regions = {};
  for (const r of regionsDef) {
    regions[r.code] = await prisma.region.upsert({
      where: { code: r.code },
      update: { nom: r.nom },
      create: r,
    });
  }

  const secteursDef = [
    { code: 'S-IDF', nom: 'Île-de-France', region: 'NORD' },
    { code: 'S-NOR', nom: 'Normandie / Hauts-de-France', region: 'NORD' },
    { code: 'S-RHA', nom: 'Rhône-Alpes', region: 'SUD' },
    { code: 'S-PAC', nom: 'Provence-Côte d’Azur', region: 'SUD' },
  ];
  const secteurs = {};
  for (const s of secteursDef) {
    secteurs[s.code] = await prisma.secteur.upsert({
      where: { code: s.code },
      update: { nom: s.nom, regionId: regions[s.region].id },
      create: { code: s.code, nom: s.nom, regionId: regions[s.region].id },
    });
  }

  // =====================================================================
  // 2) Utilisateurs — les VRAIS comptes AD, jamais de faux.
  //    Prérequis : la synchro de la force de vente (POST /sync/ad, ADMIN)
  //    a provisionné les utilisateurs ; le seed ne fait que s'y adosser.
  // =====================================================================
  const admin = await prisma.user.findFirst({ where: { role: 'ADMIN' } });
  const commerciaux = await prisma.user.findMany({
    where: { role: 'COMMERCIAL', idRepr: { not: null }, isActive: true },
    orderBy: { username: 'asc' },
  });
  const chefsSecteur = await prisma.user.findMany({
    where: { role: 'CHEF_SECTEUR', isActive: true },
    orderBy: { username: 'asc' },
  });
  if (!admin || commerciaux.length === 0) {
    throw new Error(
      "Aucun admin ou commercial en base : lancer d'abord la synchro AD (POST /sync/ad) — le seed ne crée pas d'utilisateurs.",
    );
  }
  // Chefs de secteur réels affectés aux secteurs de démo (round-robin).
  const codesSecteurs = ['S-IDF', 'S-NOR', 'S-RHA', 'S-PAC'];
  for (let i = 0; i < codesSecteurs.length && chefsSecteur.length > 0; i++) {
    await prisma.secteur.update({
      where: { id: secteurs[codesSecteurs[i]].id },
      data: { managerId: chefsSecteur[i % chefsSecteur.length].id },
    });
  }
  console.log(`Users AD : admin ${admin.username}, ${commerciaux.length} commerciaux, ${chefsSecteur.length} chefs de secteur`);

  // =====================================================================
  // 3) Centrales d'achat (3 niveaux : centrale → sous-centrale → feuille)
  // =====================================================================
  async function upsertCentrale(code, nom, parentId = null) {
    return prisma.centrale.upsert({ where: { code }, update: { nom, parentId }, create: { code, nom, parentId } });
  }
  const carrefour = await upsertCentrale('CARR', 'Carrefour');
  const carrHyp = await upsertCentrale('CARR-HYP', 'Carrefour Hypermarchés', carrefour.id);
  const carrMkt = await upsertCentrale('CARR-MKT', 'Carrefour Market', carrefour.id);
  const carrHypIdf = await upsertCentrale('CARR-HYP-IDF', 'Carrefour Hyp. Île-de-France', carrHyp.id);
  const carrMktNat = await upsertCentrale('CARR-MKT-NAT', 'Carrefour Market National', carrMkt.id);
  const leclerc = await upsertCentrale('LECL', 'E.Leclerc');
  const leclScapnor = await upsertCentrale('LECL-SCAPNOR', 'Scapnor (Leclerc Nord)', leclerc.id);
  const leclScapnorHyp = await upsertCentrale('LECL-SCAPNOR-H', 'Scapnor Hypermarchés', leclScapnor.id);
  const su = await upsertCentrale('SU', 'Système U');
  const suSud = await upsertCentrale('SU-SUD', 'U Sud', su.id);
  const suSudExp = await upsertCentrale('SU-SUD-EXP', 'U Express Sud', suSud.id);
  const feuillesCentrales = [carrHypIdf, carrMktNat, leclScapnorHyp, suSudExp];

  // =====================================================================
  // 4) Périodicités de visite (nomenclature legacy 1..6)
  // =====================================================================
  const periodicitesDef = [
    { code: 1, libelle: 'Hebdomadaire' },
    { code: 2, libelle: 'Bimensuelle' },
    { code: 3, libelle: 'Mensuelle' },
    { code: 4, libelle: 'Bimestrielle' },
    { code: 5, libelle: 'Trimestrielle' },
    { code: 6, libelle: 'Semestrielle' },
  ];
  const periodicites = [];
  for (const p of periodicitesDef) {
    periodicites.push(await prisma.periodicite.upsert({ where: { code: p.code }, update: { libelle: p.libelle }, create: p }));
  }

  // =====================================================================
  // 5) Catalogue : marques → gammes → familles → articles + tarifs
  // =====================================================================
  async function upsertMarque(code, nom) {
    return prisma.marque.upsert({ where: { code }, update: { nom }, create: { code, nom } });
  }
  async function upsertGamme(code, nom, marqueId) {
    return prisma.gamme.upsert({ where: { code }, update: { nom, marqueId }, create: { code, nom, marqueId } });
  }
  async function upsertFamille(code, nom, gammeId) {
    return prisma.famille.upsert({ where: { code }, update: { nom, gammeId }, create: { code, nom, gammeId } });
  }

  const mAbc = await upsertMarque('ABC', 'ABC Cosmétique');
  const mBelle = await upsertMarque('BEL', 'Belle France');
  const mDerma = await upsertMarque('DER', 'DermaSoft');

  const gSoin = await upsertGamme('G-SOIN', 'Soin visage', mAbc.id);
  const gCorps = await upsertGamme('G-CORPS', 'Soin corps', mAbc.id);
  const gCapil = await upsertGamme('G-CAPIL', 'Capillaire', mBelle.id);
  const gMaquil = await upsertGamme('G-MAQ', 'Maquillage', mBelle.id);
  const gHyg = await upsertGamme('G-HYG', 'Hygiène', mDerma.id);
  const gSolaire = await upsertGamme('G-SOL', 'Solaire', mDerma.id);

  const familles = [
    await upsertFamille('F-CREME', 'Crèmes hydratantes', gSoin.id),
    await upsertFamille('F-SERUM', 'Sérums', gSoin.id),
    await upsertFamille('F-LAIT', 'Laits corporels', gCorps.id),
    await upsertFamille('F-SHAMP', 'Shampooings', gCapil.id),
    await upsertFamille('F-COLOR', 'Colorations', gCapil.id),
    await upsertFamille('F-ROUGE', 'Rouges à lèvres', gMaquil.id),
    await upsertFamille('F-GELD', 'Gels douche', gHyg.id),
    await upsertFamille('F-SPF', 'Protections SPF', gSolaire.id),
  ];
  const hierarchie = {
    'F-CREME': [mAbc, gSoin], 'F-SERUM': [mAbc, gSoin], 'F-LAIT': [mAbc, gCorps],
    'F-SHAMP': [mBelle, gCapil], 'F-COLOR': [mBelle, gCapil], 'F-ROUGE': [mBelle, gMaquil],
    'F-GELD': [mDerma, gHyg], 'F-SPF': [mDerma, gSolaire],
  };

  const nomsProduits = {
    'F-CREME': ['Crème hydratante 24h', 'Crème nuit régénérante', 'Crème anti-âge Q10', 'Crème matifiante', 'Crème peaux sensibles'],
    'F-SERUM': ['Sérum vitamine C', 'Sérum acide hyaluronique', 'Sérum éclat', 'Sérum anti-taches', 'Sérum contour des yeux'],
    'F-LAIT': ['Lait corps karité', 'Lait hydratant amande', 'Lait raffermissant', 'Baume corps nourrissant', 'Lait après-soleil'],
    'F-SHAMP': ['Shampooing doux usage fréquent', 'Shampooing antipelliculaire', 'Shampooing cheveux colorés', 'Shampooing solide', 'Après-shampooing démêlant'],
    'F-COLOR': ['Coloration châtain 4.0', 'Coloration blond 7.3', 'Coloration acajou 5.5', 'Kit racines brun', 'Coloration noir 1.0'],
    'F-ROUGE': ['Rouge mat 101', 'Rouge satin 205', 'Gloss nude 310', 'Rouge longue tenue 412', 'Baume teinté 520'],
    'F-GELD': ['Gel douche surgras', 'Gel douche fleur d’oranger', 'Gel douche 0 % savon', 'Gel douche exfoliant', 'Huile de douche'],
    'F-SPF': ['Lait solaire SPF 30', 'Spray solaire SPF 50 enfant', 'Crème visage SPF 50+', 'Huile solaire SPF 20', 'Stick lèvres SPF 30'],
  };

  const articles = [];
  let numArticle = 0;
  for (const f of familles) {
    const [marque, gamme] = hierarchie[f.code];
    for (const libelle of nomsProduits[f.code]) {
      numArticle += 1;
      const codeAs400 = String(900000 + numArticle);
      const art = await prisma.article.upsert({
        where: { codeAs400 },
        update: { libelle },
        create: {
          codeAs400,
          libelle,
          gencode: `37612345${String(10000 + numArticle).slice(1)}`,
          typeArticle: pick(['PF', 'PF', 'PF', 'PLV']),
          sousFamille: f.code.replace('F-', ''),
          marqueId: marque.id,
          gammeId: gamme.id,
          familleId: f.id,
          familleAcd: f.code.replace('F-', 'ACD-'),
          codeTva: '001',
          pcb: pick([6, 6, 12, 12, 24]),
          statut: 'ACTIF',
          sousStatut: chance(0.1) ? 'RAPPE' : null,
          retourAutorise: chance(0.1),
          stock: int(0, 500),
          details: `Référence ${codeAs400} — ${libelle}.`,
          avantages: 'Formule dermatologiquement testée, fabriquée en France.',
        },
      });
      articles.push(art);
      // Tarif de base Minos (base tarifaire « 80 »), 4 décimales.
      const montant = (int(250, 2400) / 100).toFixed(4);
      await prisma.tarif.upsert({
        where: { articleId_codeTarif: { articleId: art.id, codeTarif: '80' } },
        update: { montant },
        create: { articleId: art.id, codeTarif: '80', montant },
      });
    }
  }
  console.log(`Catalogue : 3 marques, 6 gammes, ${familles.length} familles, ${articles.length} articles + tarifs`);

  // =====================================================================
  // 6) Clients / magasins (rattachés secteurs + centrales + commerciaux)
  // =====================================================================
  const enseignesDef = [
    ['Carrefour', carrHypIdf], ['Carrefour Market', carrMktNat], ['E.Leclerc', leclScapnorHyp],
    ['Super U', suSudExp], ['U Express', suSudExp], ['Intermarché', null], ['Monoprix', null], ['Auchan', null],
  ];
  const villes = [
    ['75011', 'Paris', 'S-IDF'], ['92100', 'Boulogne-Billancourt', 'S-IDF'], ['94200', 'Ivry-sur-Seine', 'S-IDF'],
    ['78000', 'Versailles', 'S-IDF'], ['76000', 'Rouen', 'S-NOR'], ['59000', 'Lille', 'S-NOR'],
    ['80000', 'Amiens', 'S-NOR'], ['14000', 'Caen', 'S-NOR'], ['69003', 'Lyon', 'S-RHA'],
    ['38000', 'Grenoble', 'S-RHA'], ['42000', 'Saint-Étienne', 'S-RHA'], ['73000', 'Chambéry', 'S-RHA'],
    ['13001', 'Marseille', 'S-PAC'], ['06000', 'Nice', 'S-PAC'], ['83000', 'Toulon', 'S-PAC'], ['84000', 'Avignon', 'S-PAC'],
  ];
  const niveaux = ['A', 'B', 'B', 'C', 'C', 'C', 'D', 'D', 'E', 'F', 'G'];

  const clients = [];
  for (let i = 1; i <= 32; i++) {
    const codeAs400 = String(90000 + i);
    const [enseigne, centrale] = pick(enseignesDef);
    const [cp, ville, secteurCode] = pick(villes);
    const secteur = secteurs[secteurCode];
    const commerciauxSecteur = commerciaux.filter((c) => c.secteurId === secteur.id);
    const commercial = commerciauxSecteur.length ? pick(commerciauxSecteur) : pick(commerciaux);
    const client = await prisma.client.upsert({
      where: { codeAs400 },
      update: { secteurId: secteur.id },
      create: {
        codeAs400,
        enseigne: `${enseigne} ${ville}`,
        raisonSociale: `${enseigne.toUpperCase().replace(/[^A-Z ]/g, '')} DISTRIBUTION ${ville.toUpperCase()}`,
        adresse1: `${int(1, 120)} avenue ${pick(['de la République', 'du Général Leclerc', 'Jean Jaurès', 'des Champs', 'Victor Hugo'])}`,
        codePostal: cp,
        ville,
        pays: 'France',
        devise: 'EUR',
        siret: `8${int(10, 99)}${int(100000000, 999999999)}`.slice(0, 14),
        tel1: `01${int(10000000, 99999999)}`,
        contact1: pick(['M. Bernard', 'Mme Lopez', 'M. Nguyen', 'Mme Dubois', 'M. Rossi']),
        email: `magasin${i}@${enseigne.toLowerCase().replace(/[^a-z]/g, '')}.example`,
        idCommercial1: commercial.idRepr,
        niveauClass: pick(niveaux),
        statutCommande: pick(['OK', 'OK', 'OK', 'BLOQUE']),
        secteurId: secteur.id,
        centraleId: (centrale ?? pick(feuillesCentrales)).id,
        commerciaux: { connect: [{ id: commercial.id }] },
      },
    });
    clients.push({ ...client, _commercial: commercial });
  }
  console.log(`Clients : ${clients.length} magasins`);

  // Périodicité de visite pour chaque magasin (si absente).
  for (const c of clients) {
    const deja = await prisma.clientPeriodicite.findFirst({ where: { clientId: c.id, deletedAt: null } });
    if (!deja) {
      await prisma.clientPeriodicite.create({
        data: { clientId: c.id, periodiciteId: pick(periodicites).id, affecteParId: admin.id },
      });
    }
  }

  // Contacts & notes (données transactionnelles : seulement si tables vides).
  if ((await prisma.clientContact.count()) === 0) {
    const postes = [['PDG', 'Direction'], ['Directeur', 'Direction magasin'], ['Chef de rayon', 'Rayon DPH'], ['Adjoint', 'Rayon beauté']];
    for (const c of clients) {
      for (let k = 0; k < int(1, 3); k++) {
        const [typePoste, poste] = pick(postes);
        const prenom = pick(['Julie', 'Thomas', 'Sarah', 'Nicolas', 'Laura', 'Hugo', 'Fatima', 'Paul']);
        const nom = pick(['Bernard', 'Lopez', 'Nguyen', 'Dubois', 'Rossi', 'Meyer', 'Fontaine', 'Chevalier']);
        await prisma.clientContact.create({
          data: {
            clientId: c.id, prenom, nom, poste, typePoste,
            portable: `06${int(10000000, 99999999)}`,
            mail: `${prenom.toLowerCase()}.${nom.toLowerCase()}@magasin.example`,
            creeParId: c._commercial.id,
          },
        });
      }
    }
    console.log('Contacts magasins créés');
  }
  if ((await prisma.clientNote.count()) === 0) {
    const remarques = [
      'Chef de rayon très réceptif, prévoir PLV pour la prochaine opération.',
      'Rayon réorganisé, notre gamme soin a perdu une étagère — à surveiller.',
      'Demande un passage avant les fêtes pour l’implantation solaire.',
      'Concurrent en tête de gondole ce mois-ci.',
      'Magasin en travaux jusqu’à la fin du mois, accès réserve compliqué.',
    ];
    for (const c of clients) {
      if (chance(0.6)) {
        await prisma.clientNote.create({
          data: { clientId: c.id, remarque: pick(remarques), auteurId: c._commercial.id, createdAt: daysAgo(int(1, 60)) },
        });
      }
    }
    console.log('Notes terrain créées');
  }

  // =====================================================================
  // 7) Merch : switchs, promos, PEM, stratégies
  // =====================================================================
  if ((await prisma.articleSwitch.count()) === 0) {
    for (let k = 0; k < 6; k++) {
      const a = pick(articles);
      let b = pick(articles);
      if (b.id === a.id) b = articles[(articles.indexOf(a) + 1) % articles.length];
      await prisma.articleSwitch.create({ data: { articleId: a.id, cibleId: b.id, seuil: pick([5, 10, 20]), creeParId: admin.id } });
    }
  }
  if ((await prisma.promo.count()) === 0) {
    for (let k = 0; k < 8; k++) {
      const art = pick(articles);
      await prisma.promo.create({
        data: {
          articleId: art.id,
          libelle: pick(['-25 % en tête de gondole', 'Lot de 2 : le 2e à -50 %', 'Offre de rentrée', 'Format +20 % gratuit']),
          dateDebut: daysAgo(int(0, 20)),
          dateFin: daysAhead(int(5, 30)),
        },
      });
    }
  }
  if ((await prisma.pemArticle.count()) === 0) {
    for (const art of articles.filter(() => chance(0.2))) {
      await prisma.pemArticle.create({ data: { articleId: art.id } });
    }
  }
  if ((await prisma.stratPem.count()) === 0) {
    for (const nom of ['Implantation rentrée 2026', 'Mise en avant solaire été']) {
      const strat = await prisma.stratPem.create({ data: { nom } });
      const selection = articles.filter(() => chance(0.15)).slice(0, 6);
      for (let k = 0; k < selection.length; k++) {
        await prisma.stratPemLigne.create({ data: { stratPemId: strat.id, articleId: selection[k].id, ordre: k + 1 } });
      }
    }
    console.log('Merch : switchs, promos, PEM, stratégies');
  }

  // =====================================================================
  // 8) Questionnaire de fin de visite
  // =====================================================================
  const questionsDef = [
    { libelle: 'La PLV est-elle en place ?', type: 'CASE_A_COCHER', ordre: 1, obligatoire: true },
    { libelle: 'Nombre de facings de notre marque', type: 'NOMBRE', ordre: 2, obligatoire: true },
    { libelle: 'État général du rayon (1-5)', type: 'NOTE_1_5', ordre: 3, obligatoire: true },
    { libelle: 'Ruptures constatées (références)', type: 'TEXTE', ordre: 4, obligatoire: false },
    { libelle: 'Le chef de rayon a-t-il été rencontré ?', type: 'CASE_A_COCHER', ordre: 5, obligatoire: false },
  ];
  let questions = await prisma.questionVisite.findMany({ where: { deletedAt: null } });
  if (questions.length === 0) {
    questions = [];
    for (const q of questionsDef) {
      questions.push(await prisma.questionVisite.create({ data: { ...q, creeParId: admin.id } }));
    }
    console.log('Questionnaire de visite : 5 questions');
  }

  // =====================================================================
  // 9) Visites (90 derniers jours) + relevés DN, étapes, réponses, promos vues
  // =====================================================================
  if ((await prisma.visite.count()) === 0) {
    let nApk = 0;
    for (const c of clients) {
      for (let k = 0; k < int(1, 4); k++) {
        nApk += 1;
        const quand = daysAgo(int(0, 90));
        const visite = await prisma.visite.create({
          data: {
            promoteurId: c._commercial.id,
            clientId: c.id,
            idApk: `SEED-V${String(nApk).padStart(5, '0')}`,
            motif: pick(['Visite planifiée', 'Appel client', 'Passage opportunité', 'Urgence rupture']),
            pmcEtat: pick(['OK', 'OK', 'A_REVOIR', null]),
            pmcCommentaire: chance(0.3) ? 'Tête de gondole négociée pour le mois prochain.' : null,
            dnAbc: int(4, 18),
            dnConcurrence: int(4, 18),
            dnGondoleHaute: int(0, 6),
            dnGondoleBasse: int(0, 6),
            pem: chance(0.3),
            createdAt: quand,
          },
        });
        await prisma.visiteDN.createMany({
          data: [
            { visiteId: visite.id, type: 'ABC', marque: 'ABC Cosmétique', gamme: 'Soin visage', metrage: (int(50, 300) / 100).toFixed(2) },
            { visiteId: visite.id, type: 'CONCURRENCE', marque: pick(['L’Oréal', 'Garnier', 'Nivea']), gamme: 'Soin visage', metrage: (int(50, 400) / 100).toFixed(2) },
          ],
        });
        const arrivee = new Date(quand.getTime() + 9 * 3600 * 1000);
        await prisma.visiteStep.createMany({
          data: [
            { visiteId: visite.id, etape: 'ARRIVEE', horodatage: arrivee },
            { visiteId: visite.id, etape: 'RAYON', horodatage: new Date(arrivee.getTime() + 10 * 60000) },
            { visiteId: visite.id, etape: 'DEPART', horodatage: new Date(arrivee.getTime() + int(20, 55) * 60000) },
          ],
        });
        for (const q of questions) {
          const valeur =
            q.type === 'CASE_A_COCHER' ? String(chance(0.7)) :
            q.type === 'NOMBRE' ? String(int(2, 14)) :
            q.type === 'NOTE_1_5' ? String(int(2, 5)) :
            chance(0.4) ? 'RAS' : 'Rupture sérum vitamine C et gel douche surgras';
          await prisma.visiteReponse.create({ data: { visiteId: visite.id, questionId: q.id, valeur } });
        }
        if (chance(0.4)) {
          await prisma.visitePromo.create({ data: { visiteId: visite.id, articleId: pick(articles).id } });
        }
        if (chance(0.3)) {
          await prisma.visitePhoto.create({
            data: { visiteId: visite.id, fichier: `visites/seed/${visite.id}-rayon.jpg`, taille: int(200000, 1500000), idVisiteApk: visite.idApk, appName: 'crm-mobile' },
          });
        }
      }
    }
    console.log(`Visites : ${await prisma.visite.count()} (avec DN, étapes, réponses, photos)`);
  }

  // =====================================================================
  // 10) Planification : récurrences, plannings, tournées
  // =====================================================================
  if ((await prisma.plannification.count()) === 0) {
    for (const c of clients.filter(() => chance(0.5))) {
      const regle = await prisma.plannification.create({
        data: {
          promoteurId: c._commercial.id,
          clientId: c.id,
          jours: pick(['1', '2', '4', '1,4', '2,5']),
          recurrence: pick([1, 2, 4]),
          dateDebut: daysAgo(30),
        },
      });
      // Occurrences : 2 passées (faites ou non) + 2 à venir.
      for (const decalage of [-14, -7, 7, 14]) {
        await prisma.planning.create({
          data: {
            promoteurId: c._commercial.id,
            clientId: c.id,
            datePassage: daysAhead(decalage),
            fait: decalage < 0 ? chance(0.8) : false,
            raison: decalage < 0 && chance(0.15) ? 'Magasin fermé (inventaire)' : null,
            plannificationId: regle.id,
          },
        });
      }
    }
    console.log('Planification : récurrences + occurrences');
  }
  if ((await prisma.tournee.count()) === 0) {
    for (const c of clients.filter(() => chance(0.6))) {
      await prisma.tournee.create({
        data: {
          promoteurId: c._commercial.id,
          clientId: c.id,
          jours: pick(['1', '2', '3', '4', '5']),
          semaines: pick(['1,2,3,4', '1,3', '2,4']),
          semaineDebut: 36,
          annee: 2026,
        },
      });
    }
    console.log('Tournées types créées');
  }

  // =====================================================================
  // 11) Commandes ERP (12 derniers mois + N-1 pour les comparatifs)
  // =====================================================================
  if ((await prisma.commande.count()) === 0) {
    let numero = 0;
    for (const c of clients) {
      // Entre 4 et 10 commandes réparties sur 14 mois (dont N-1 pour le Δ).
      for (let k = 0; k < int(4, 10); k++) {
        numero += 1;
        const dateCommande = daysAgo(int(0, 420));
        const ageJours = (Date.now() - dateCommande.getTime()) / 86_400_000;
        // Suivi de livraison plausible selon l'ancienneté (LIVREE au-delà d'une semaine).
        const statutLivraison = ageJours > 7 ? 'LIVREE' : ageJours > 2 ? 'EXPEDIEE' : 'EN_PREPARATION';
        const commande = await prisma.commande.create({
          data: {
            numero: `SEED${String(numero).padStart(6, '0')}`,
            clientId: c.id,
            raisonSocialeCmd: c.raisonSociale,
            idRepr: c._commercial.idRepr,
            typeCmd: pick(['CDE', 'CDE', 'CDE', 'AVR']),
            dateCommande,
            dateAnnulation: chance(0.05) ? new Date(dateCommande.getTime() + 2 * 24 * 3600 * 1000) : null,
            statutLivraison,
            dateExpedition: statutLivraison !== 'EN_PREPARATION' ? new Date(dateCommande.getTime() + 86_400_000) : null,
            dateLivraison: statutLivraison === 'LIVREE' ? new Date(dateCommande.getTime() + 3 * 86_400_000) : null,
          },
        });
        const nbLignes = int(1, 6);
        for (let l = 1; l <= nbLignes; l++) {
          const art = pick(articles);
          const quantite = pick([6, 12, 12, 24, 48]);
          const prixUnitaire = int(250, 2400) / 100;
          await prisma.commandeLigne.create({
            data: {
              commandeId: commande.id,
              noLigne: String(l * 10), // numérotation Minos par pas de 10
              articleId: art.id,
              libelleArticle: art.libelle,
              quantite: quantite.toFixed(4),
              montant: (quantite * prixUnitaire).toFixed(4),
            },
          });
        }
      }
    }
    console.log(`Commandes ERP : ${await prisma.commande.count()} (avec lignes)`);
  }

  // =====================================================================
  // 12) Commandes mobiles (APK)
  // =====================================================================
  if ((await prisma.commandeApk.count()) === 0) {
    let n = 0;
    for (const c of clients.filter(() => chance(0.4))) {
      n += 1;
      const cmd = await prisma.commandeApk.create({
        data: {
          idCommandeApk: `SA${String(n).padStart(6, '0')}`, // 10 caractères max (champ IDCRM)
          promoteurId: c._commercial.id,
          clientId: c.id,
          commentaire: chance(0.5) ? 'Réassort suite à visite — livraison souhaitée sous 8 jours.' : null,
          dateCommande: daysAgo(int(0, 30)),
        },
      });
      const nb = int(1, 5);
      for (let l = 1; l <= nb; l++) {
        const art = pick(articles);
        await prisma.commandeApkLigne.create({
          data: {
            commandeApkId: cmd.id,
            ordre: l,
            articleId: art.id,
            quantite: pick([6, 12, 24]),
            prixIndicatif: (int(250, 2400) / 100).toFixed(4),
          },
        });
      }
    }
    console.log('Commandes mobiles (APK) créées');
  }

  // =====================================================================
  // 13) Objectifs annuels de CA par magasin
  // =====================================================================
  for (const c of clients) {
    for (const annee of [2025, 2026]) {
      await prisma.objectif.upsert({
        where: { clientId_annee: { clientId: c.id, annee } },
        update: {},
        create: { clientId: c.id, annee, cibleCa: (int(8000, 60000)).toFixed(2), creeParId: admin.id },
      });
    }
  }
  console.log('Objectifs 2025/2026 par magasin');

  // =====================================================================
  // 14) Notifications + journal d'import
  // =====================================================================
  if ((await prisma.notification.count()) === 0) {
    for (const u of commerciaux) {
      await prisma.notification.create({
        data: {
          userId: u.id,
          emetteurId: admin.id,
          type: 'RELANCE_VISITE',
          titre: 'Visites en retard',
          message: 'Des magasins de votre portefeuille n’ont pas été visités depuis plus de 60 jours.',
          lien: '/tournees',
        },
      });
    }
    await prisma.notification.create({
      data: {
        userId: admin.id,
        type: 'INFO',
        titre: 'Jeu de données de test',
        message: 'La base contient des données seedées (codes 9xxxx) — à purger avant l’import AS400 réel.',
      },
    });
  }
  if ((await prisma.erpImportLog.count()) === 0) {
    await prisma.erpImportLog.create({
      data: {
        fileName: 'seed-demo.dataset', source: 'MINOS', status: 'SUCCESS',
        rowsTotal: 500, rowsOk: 500, rowsFailed: 0,
        startedAt: daysAgo(1), finishedAt: daysAgo(1),
      },
    });
  }

  console.log('— Seed terminé —');
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
