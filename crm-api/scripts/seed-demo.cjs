/*
 * Seed de DONNÉES DE DÉMO (magasins, visites, commandes) — en attendant les imports Minos.
 * Idempotent : upsert sur les clés uniques (codeAs400, numero, username, code périodicité) ;
 * les visites ne sont créées que si les promoteurs de démo n'en ont aucune.
 *
 * Usage (dans le conteneur API, qui porte DATABASE_URL) :
 *   docker cp crm-api/scripts/seed-demo.cjs www-api-1:/app/crm-api/scripts/
 *   docker exec www-api-1 node crm-api/scripts/seed-demo.cjs
 */
const { PrismaClient } = require('@crm/database');
const { PrismaPg } = require('@prisma/adapter-pg');

const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL absent de l’environnement.');
  process.exit(1);
}

// RNG déterministe : le seed produit toujours les mêmes données.
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(20260914);
const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const entre = (min, max) => Math.floor(rand() * (max - min + 1)) + min;
const ilYA = (jours, heures = 10) => new Date(Date.now() - jours * 86_400_000 + heures * 3_600_000 - 10 * 3_600_000);

const PERIODICITES = [
  { code: 1, libelle: '2 fois par semaine' },
  { code: 2, libelle: '1 fois par semaine' },
  { code: 3, libelle: 'Toutes les 2 semaines' },
  { code: 4, libelle: 'Toutes les 3 semaines' },
  { code: 5, libelle: '1 fois par mois' },
  { code: 6, libelle: "Plus d'un mois" },
];

const PROMOTEURS = [
  { username: 'demo.sophie', displayName: 'Sophie Martin', idRepr: '968', secteur: 'S01' },
  { username: 'demo.karim', displayName: 'Karim Benali', idRepr: '972', secteur: 'S02' },
];

const CLIENTS = [
  { code: 'DEMO0001', enseigne: 'Carrefour Évry 2', rs: 'CARREFOUR HYPERMARCHES SAS', ville: 'Évry-Courcouronnes', cp: '91000', cls: 'A' },
  { code: 'DEMO0002', enseigne: 'E.Leclerc Rouen', rs: 'SODIROUEN SAS', ville: 'Rouen', cp: '76000', cls: 'A' },
  { code: 'DEMO0003', enseigne: 'Intermarché Lille Fives', rs: 'ITM LILLE DISTRIBUTION', ville: 'Lille', cp: '59800', cls: 'B' },
  { code: 'DEMO0004', enseigne: 'Auchan Vélizy 2', rs: 'AUCHAN HYPERMARCHE SA', ville: 'Vélizy-Villacoublay', cp: '78140', cls: 'A' },
  { code: 'DEMO0005', enseigne: 'Monoprix Paris Vaugirard', rs: 'MONOPRIX EXPLOITATION', ville: 'Paris 15e', cp: '75015', cls: 'C' },
  { code: 'DEMO0006', enseigne: 'Super U Nantes Beaulieu', rs: 'NANTES DIS SAS', ville: 'Nantes', cp: '44200', cls: 'B' },
  { code: 'DEMO0007', enseigne: 'Cora Reims Cormontreuil', rs: 'CORA SAS REIMS', ville: 'Cormontreuil', cp: '51350', cls: 'C' },
  { code: 'DEMO0008', enseigne: 'Casino Lyon Part-Dieu', rs: 'DISTRIBUTION CASINO FRANCE', ville: 'Lyon 3e', cp: '69003', cls: 'D' },
  { code: 'DEMO0009', enseigne: 'Carrefour Market Tours', rs: 'CSF FRANCE', ville: 'Tours', cp: '37000', cls: 'B' },
  { code: 'DEMO0010', enseigne: 'E.Leclerc Pau', rs: 'PAUDIS SAS', ville: 'Pau', cp: '64000', cls: 'C' },
  { code: 'DEMO0011', enseigne: 'Supermarché Match Metz', rs: 'SUPERMARCHES MATCH EST', ville: 'Metz', cp: '57000', cls: 'D' },
  { code: 'DEMO0012', enseigne: 'Auchan Bordeaux-Lac', rs: 'AUCHAN HYPERMARCHE SA', ville: 'Bordeaux', cp: '33300', cls: 'B' },
];

const MOTIFS = ['Visite planifiée', 'Appel client', 'Passage opportunité', 'Urgence rupture'];
const ARTICLES = [
  'Brosse démêlante Stitch', 'Kit pinceaux teint x5', 'Éponge konjac naturelle', 'Limes à ongles x10',
  'Chouchous satin x3', 'Trousse maquillage nylon', 'Miroir de poche pliable', 'Pince à épiler expert',
  'Bandeau spa éponge', 'Houppettes poudre x6', 'Taille-crayon cosmétique', 'Gant exfoliant kessa',
];

// --- Catalogue (marques → gammes → familles → articles) -------------------
const MARQUES = [
  { code: 'MABC', nom: 'ABC Beauté' },
  { code: 'MLIC', nom: 'Licences & Co' },
  { code: 'MNAT', nom: 'Naturelia' },
];
const GAMMES = [
  { code: 'GCHE', nom: 'Accessoires cheveux', marque: 'MABC' },
  { code: 'GTEI', nom: 'Pinceaux & teint', marque: 'MABC' },
  { code: 'GMAN', nom: 'Manucure', marque: 'MABC' },
  { code: 'GLIC', nom: 'Licences enfants', marque: 'MLIC' },
  { code: 'GBAI', nom: 'Bain & éponges', marque: 'MNAT' },
];
const FAMILLES = [
  { code: 'FBRO', nom: 'Brosses & peignes', gamme: 'GCHE' },
  { code: 'FPIN', nom: 'Pinceaux', gamme: 'GTEI' },
  { code: 'FLIM', nom: 'Limes & pinces', gamme: 'GMAN' },
  { code: 'FEPO', nom: 'Éponges & gants', gamme: 'GBAI' },
];
const CATALOGUE = [
  { code: 'DEMOA001', libelle: 'Brosse démêlante Stitch', gamme: 'GLIC', famille: 'FBRO', rappel: false },
  { code: 'DEMOA002', libelle: 'Brosse démêlante La Reine des Neiges', gamme: 'GLIC', famille: 'FBRO', rappel: false },
  { code: 'DEMOA003', libelle: 'Brosse pneumatique poils sanglier', gamme: 'GCHE', famille: 'FBRO', rappel: false },
  { code: 'DEMOA004', libelle: 'Peigne démêloir carbone', gamme: 'GCHE', famille: 'FBRO', rappel: false },
  { code: 'DEMOA005', libelle: 'Chouchous satin x3 assortis', gamme: 'GCHE', famille: null, rappel: false },
  { code: 'DEMOA006', libelle: 'Élastiques bruns x30', gamme: 'GCHE', famille: null, rappel: false },
  { code: 'DEMOA007', libelle: 'Pinces crabe écaille x2', gamme: 'GCHE', famille: null, rappel: false },
  { code: 'DEMOA008', libelle: 'Serre-tête velours noir', gamme: 'GCHE', famille: null, rappel: false },
  { code: 'DEMOA009', libelle: 'Kit pinceaux teint x5', gamme: 'GTEI', famille: 'FPIN', rappel: false },
  { code: 'DEMOA010', libelle: 'Pinceau poudre XL', gamme: 'GTEI', famille: 'FPIN', rappel: false },
  { code: 'DEMOA011', libelle: 'Pinceau fond de teint biseauté', gamme: 'GTEI', famille: 'FPIN', rappel: false },
  { code: 'DEMOA012', libelle: 'Éponge blender duo', gamme: 'GTEI', famille: null, rappel: false },
  { code: 'DEMOA013', libelle: 'Houppettes poudre x6', gamme: 'GTEI', famille: null, rappel: false },
  { code: 'DEMOA014', libelle: 'Miroir de poche pliable', gamme: 'GTEI', famille: null, rappel: false },
  { code: 'DEMOA015', libelle: 'Limes à ongles x10', gamme: 'GMAN', famille: 'FLIM', rappel: false },
  { code: 'DEMOA016', libelle: 'Bloc polissoir 4 faces', gamme: 'GMAN', famille: 'FLIM', rappel: false },
  { code: 'DEMOA017', libelle: 'Pince à épiler expert mors biais', gamme: 'GMAN', famille: 'FLIM', rappel: false },
  { code: 'DEMOA018', libelle: 'Coupe-ongles inox', gamme: 'GMAN', famille: 'FLIM', rappel: true },
  { code: 'DEMOA019', libelle: 'Ciseaux à cuticules', gamme: 'GMAN', famille: 'FLIM', rappel: false },
  { code: 'DEMOA020', libelle: 'Séparateurs d’orteils mousse x2', gamme: 'GMAN', famille: null, rappel: false },
  { code: 'DEMOA021', libelle: 'Éponge konjac naturelle', gamme: 'GBAI', famille: 'FEPO', rappel: false },
  { code: 'DEMOA022', libelle: 'Gant exfoliant kessa', gamme: 'GBAI', famille: 'FEPO', rappel: false },
  { code: 'DEMOA023', libelle: 'Fleur de douche XL', gamme: 'GBAI', famille: 'FEPO', rappel: true },
  { code: 'DEMOA024', libelle: 'Bandeau spa éponge', gamme: 'GBAI', famille: 'FEPO', rappel: false },
  { code: 'DEMOA025', libelle: 'Brosse de bain manche bois', gamme: 'GBAI', famille: 'FEPO', rappel: false },
  { code: 'DEMOA026', libelle: 'Pierre ponce naturelle', gamme: 'GBAI', famille: null, rappel: false },
  { code: 'DEMOA027', libelle: 'Trousse maquillage nylon', gamme: 'GTEI', famille: null, rappel: false },
  { code: 'DEMOA028', libelle: 'Taille-crayon cosmétique duo', gamme: 'GTEI', famille: null, rappel: false },
  { code: 'DEMOA029', libelle: 'Barrettes clic-clac Stitch x4', gamme: 'GLIC', famille: null, rappel: true },
  { code: 'DEMOA030', libelle: 'Miroir grossissant x10 ventouse', gamme: 'GTEI', famille: null, rappel: false },
];
const PROMOS_DEMO = [
  { article: 'DEMOA001', libelle: '-20 % quinzaine licences', finDansJours: 12 },
  { article: 'DEMOA005', libelle: 'Lot de 3 prix choc', finDansJours: 20 },
  { article: 'DEMOA009', libelle: '2ᵉ à -50 %', finDansJours: 8 },
  { article: 'DEMOA015', libelle: 'Format familial x10', finDansJours: 25 },
  { article: 'DEMOA021', libelle: 'Offre découverte konjac', finDansJours: 15 },
  { article: 'DEMOA027', libelle: '-30 % rentrée beauté', finDansJours: 5 },
  // Échues — n'apparaissent pas dans « promos actives » mais existent en base.
  { article: 'DEMOA012', libelle: 'Duo été', finDansJours: -10 },
  { article: 'DEMOA024', libelle: 'Spa d’été', finDansJours: -30 },
];
const PEM_DEMO = ['DEMOA001', 'DEMOA009', 'DEMOA021', 'DEMOA005', 'DEMOA030'];
const TRANSPORTEURS = ['GLS', 'DPD', 'Geodis', 'Heppner'];

async function main() {
  const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });

  // --- Référentiels -------------------------------------------------------
  const region = await prisma.region.upsert({
    where: { code: 'R01' },
    update: {},
    create: { code: 'R01', nom: 'Région Nord-Ouest' },
  });

  const secteurs = {};
  for (const s of [{ code: 'S01', nom: 'Secteur Paris / Nord' }, { code: 'S02', nom: 'Secteur Ouest' }]) {
    secteurs[s.code] = await prisma.secteur.upsert({
      where: { code: s.code },
      update: {},
      create: { ...s, regionId: region.id },
    });
  }

  const periodicites = {};
  for (const p of PERIODICITES) {
    periodicites[p.code] = await prisma.periodicite.upsert({
      where: { code: p.code },
      update: { libelle: p.libelle },
      create: p,
    });
  }

  // --- Promoteurs de démo -------------------------------------------------
  const users = {};
  for (const u of PROMOTEURS) {
    users[u.idRepr] = await prisma.user.upsert({
      where: { username: u.username },
      update: {},
      create: {
        username: u.username,
        displayName: u.displayName,
        role: 'COMMERCIAL',
        idRepr: u.idRepr,
        poste: 'Promoteur des ventes',
        secteurId: secteurs[u.secteur].id,
        regionId: region.id,
      },
    });
  }

  // --- Magasins -----------------------------------------------------------
  const clients = [];
  for (let i = 0; i < CLIENTS.length; i++) {
    const c = CLIENTS[i];
    const promoteur = PROMOTEURS[i % 2];
    const client = await prisma.client.upsert({
      where: { codeAs400: c.code },
      update: {},
      create: {
        codeAs400: c.code,
        enseigne: c.enseigne,
        raisonSociale: c.rs,
        ville: c.ville,
        codePostal: c.cp,
        adresse1: `${entre(1, 120)} avenue de la Distribution`,
        tel1: `0${entre(1, 5)} ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)}`,
        contact1: pick(['Mme Lefèvre', 'M. Garnier', 'Mme Rossi', 'M. Petit', 'Mme Nguyen']),
        niveauClass: c.cls,
        actif: true,
        idCommercial1: promoteur.idRepr,
        secteurId: secteurs[promoteur.secteur].id,
        commerciaux: { connect: { id: users[promoteur.idRepr].id } },
      },
    });
    clients.push({ ...client, promoteur });

    // Périodicité de visite (une seule, la plus récente fait foi côté API).
    const dejaPeriodicite = await prisma.clientPeriodicite.findFirst({ where: { clientId: client.id, deletedAt: null } });
    if (!dejaPeriodicite) {
      await prisma.clientPeriodicite.create({
        data: { clientId: client.id, periodiciteId: periodicites[entre(2, 5)].id },
      });
    }
  }

  // --- Visites (45 derniers jours) ---------------------------------------
  const dejaVisites = await prisma.visite.count({
    where: { promoteurId: { in: Object.values(users).map((u) => u.id) } },
  });
  let visites = 0;
  if (dejaVisites === 0) {
    for (let i = 0; i < 30; i++) {
      const client = pick(clients);
      const dnAbc = entre(4, 28);
      await prisma.visite.create({
        data: {
          promoteurId: users[client.promoteur.idRepr].id,
          clientId: client.id,
          motif: pick(MOTIFS),
          dnAbc,
          dnConcurrence: entre(6, 40),
          dnGondoleHaute: rand() < 0.5 ? entre(2, Math.max(2, dnAbc)) : null,
          dnGondoleBasse: rand() < 0.5 ? entre(0, 6) : null,
          pem: rand() < 0.25,
          pmcCommentaire: rand() < 0.3 ? pick([
            'Rayon bien tenu, réassort fait en linéaire.',
            'Rupture sur la brosse Stitch — switch appliqué.',
            'Négociation tête de gondole pour la quinzaine promo.',
            'Concurrent en mise en avant, à surveiller.',
          ]) : null,
          createdAt: ilYA(entre(0, 45), entre(8, 18)),
        },
      });
      visites++;
    }
  }

  // --- Commandes (60 derniers jours + N-1 pour le comparatif CA) ----------
  let commandes = 0;
  const creerCommande = async (numero, client, joursAgo, annee1 = false) => {
    const date = annee1 ? new Date(ilYA(joursAgo).getTime() - 365 * 86_400_000) : ilYA(joursAgo);
    const annulee = !annee1 && rand() < 0.08;
    const statut = annulee
      ? 'EN_PREPARATION'
      : joursAgo > 20 ? 'LIVREE' : pick(['EN_PREPARATION', 'EXPEDIEE', 'LIVREE_PARTIELLE', 'LIVREE']);
    const commande = await prisma.commande.upsert({
      where: { numero },
      update: {},
      create: {
        numero,
        clientId: client.id,
        raisonSocialeCmd: client.raisonSociale,
        idRepr: client.promoteur.idRepr,
        typeCmd: pick(['STD', 'PROMO', 'REASSORT']),
        dateCommande: date,
        dateAnnulation: annulee ? new Date(date.getTime() + 2 * 86_400_000) : null,
        statutLivraison: statut,
        dateExpedition: ['EXPEDIEE', 'LIVREE', 'LIVREE_PARTIELLE'].includes(statut) ? new Date(date.getTime() + 3 * 86_400_000) : null,
        dateLivraison: statut === 'LIVREE' ? new Date(date.getTime() + 6 * 86_400_000) : null,
        transporteur: ['EXPEDIEE', 'LIVREE', 'LIVREE_PARTIELLE'].includes(statut) ? pick(TRANSPORTEURS) : null,
        noSuivi: ['EXPEDIEE', 'LIVREE', 'LIVREE_PARTIELLE'].includes(statut) ? `TRK${entre(100000, 999999)}` : null,
        lignes: {
          create: Array.from({ length: entre(2, 4) }, (_, l) => ({
            noLigne: String(l + 1).padStart(3, '0'),
            libelleArticle: pick(ARTICLES),
            quantite: entre(6, 72),
            montant: entre(40, 600) + 0.9,
          })),
        },
      },
    });
    commandes++;
    return commande;
  };

  for (let i = 0; i < 24; i++) {
    await creerCommande(`DEMO-2026-${String(i + 1).padStart(4, '0')}`, pick(clients), entre(0, 60));
  }
  // Quelques commandes N-1 (même mois l'an dernier) pour alimenter le Δ CA des magasins.
  for (let i = 0; i < 8; i++) {
    await creerCommande(`DEMO-2025-${String(i + 1).padStart(4, '0')}`, pick(clients), entre(0, 25), true);
  }

  // --- Catalogue : marques, gammes, familles, articles, tarifs ------------
  const marques = {};
  for (const m of MARQUES) {
    marques[m.code] = await prisma.marque.upsert({ where: { code: m.code }, update: {}, create: m });
  }
  const gammes = {};
  for (const g of GAMMES) {
    gammes[g.code] = await prisma.gamme.upsert({
      where: { code: g.code },
      update: {},
      create: { code: g.code, nom: g.nom, marqueId: marques[g.marque].id },
    });
  }
  const familles = {};
  for (const f of FAMILLES) {
    familles[f.code] = await prisma.famille.upsert({
      where: { code: f.code },
      update: {},
      create: { code: f.code, nom: f.nom, gammeId: gammes[f.gamme].id },
    });
  }

  const articles = {};
  for (const a of CATALOGUE) {
    const gamme = gammes[a.gamme];
    const marqueId = GAMMES.find((g) => g.code === a.gamme).marque;
    articles[a.code] = await prisma.article.upsert({
      where: { codeAs400: a.code },
      update: {},
      create: {
        codeAs400: a.code,
        libelle: a.libelle,
        gencode: `377000${entre(1000000, 9999999)}`,
        typeArticle: 'PF',
        marqueId: marques[marqueId].id,
        gammeId: gamme.id,
        familleId: a.famille ? familles[a.famille].id : null,
        codeTva: '20',
        pcb: pick([6, 12, 24]),
        statut: a.rappel ? 'Rappel qualité' : 'Actif',
        sousStatut: a.rappel ? 'RAPPE' : null,
        retourAutorise: a.rappel,
        stock: a.rappel ? 0 : entre(50, 2500),
        actif: !a.rappel,
        details: null,
        avantages: null,
      },
    });
    await prisma.tarif.upsert({
      where: { articleId_codeTarif: { articleId: articles[a.code].id, codeTarif: '80' } },
      update: {},
      create: { articleId: articles[a.code].id, codeTarif: '80', montant: entre(150, 1800) / 100 },
    });
  }

  // --- Promos & mises en avant (créées seulement si absentes) -------------
  let promosCreees = 0;
  for (const p of PROMOS_DEMO) {
    const articleId = articles[p.article].id;
    const deja = await prisma.promo.findFirst({ where: { articleId, libelle: p.libelle } });
    if (deja) continue;
    await prisma.promo.create({
      data: {
        articleId,
        libelle: p.libelle,
        dateDebut: ilYA(30),
        dateFin: new Date(Date.now() + p.finDansJours * 86_400_000),
        actif: true,
      },
    });
    promosCreees++;
  }
  let pemCrees = 0;
  for (const code of PEM_DEMO) {
    const articleId = articles[code].id;
    const deja = await prisma.pemArticle.findFirst({ where: { articleId } });
    if (deja) continue;
    await prisma.pemArticle.create({ data: { articleId, actif: true } });
    pemCrees++;
  }

  // Les lignes de commandes déjà seedées portent un libellé : on les raccroche
  // aux articles du catalogue quand le libellé correspond (pour les fiches).
  for (const a of Object.values(articles)) {
    await prisma.commandeLigne.updateMany({
      where: { libelleArticle: a.libelle, articleId: null },
      data: { articleId: a.id },
    });
  }

  // --- Objectifs annuels par magasin (le taux d'atteinte en découle) -------
  const annee = new Date().getFullYear();
  for (const client of clients) {
    await prisma.objectif.upsert({
      where: { clientId_annee: { clientId: client.id, annee } },
      update: {},
      create: { clientId: client.id, annee, cibleCa: entre(30, 90) * 1000 },
    });
  }

  // --- Activité des CHEFS DE SECTEUR réels (Mon équipe / dashboard) --------
  // Chaque CS actif porteur d'un code reçoit : des magasins (idCommercial2),
  // des commandes du mois (CA + objectif), des visites récentes et des prospects.
  const chefs = await prisma.user.findMany({
    where: { role: 'CHEF_SECTEUR', isActive: true, idRepr: { not: null } },
    orderBy: { displayName: 'asc' },
    take: 3,
  });
  const PROSPECTS_CS = [
    { enseigne: 'Biocoop Centre-Ville', rs: 'BIOCOOP DISTRIBUTION', statut: 'NOUVEAU', prob: 10, classe: 'C' },
    { enseigne: 'Parapharmacie du Marché', rs: 'PARA SANTE SARL', statut: 'CONTACTE', prob: 25, classe: 'D' },
    { enseigne: 'Beauty Success Local', rs: 'BS FRANCHISE SAS', statut: 'VISITE', prob: 65, classe: 'B' },
    { enseigne: 'Grand Frais Zone Nord', rs: 'GF EXPLOITATION', statut: 'GAGNE', prob: 100, classe: 'A' },
  ];
  for (let i = 0; i < chefs.length; i++) {
    const cs = chefs[i];
    const siens = clients.slice(i * 4, i * 4 + 4);
    for (const client of siens) {
      await prisma.client.update({
        where: { id: client.id },
        data: { idCommercial2: cs.idRepr, commerciaux: { connect: { id: cs.id } } },
      });
    }
    // Commandes du mois au code du CS (CA + taux d'objectif visibles).
    for (let n = 0; n < 5; n++) {
      const client = siens[n % siens.length];
      await prisma.commande.upsert({
        where: { numero: `DEMO-CS-${cs.idRepr}-${String(n + 1).padStart(3, '0')}` },
        update: {},
        create: {
          numero: `DEMO-CS-${cs.idRepr}-${String(n + 1).padStart(3, '0')}`,
          clientId: client.id,
          raisonSocialeCmd: client.raisonSociale,
          idRepr: cs.idRepr,
          typeCmd: 'STD',
          dateCommande: ilYA(entre(1, 12)),
          statutLivraison: pick(['EN_PREPARATION', 'EXPEDIEE', 'LIVREE']),
          lignes: {
            create: Array.from({ length: entre(2, 4) }, (_, l) => ({
              noLigne: String(l + 1).padStart(3, '0'),
              libelleArticle: pick(ARTICLES),
              quantite: entre(6, 72),
              montant: entre(120, 900) + 0.5,
            })),
          },
        },
      });
    }
    // Visites de suivi client sur 30 jours (colonne « Suivi clients »).
    const dejaVisitesCs = await prisma.visite.count({ where: { promoteurId: cs.id } });
    if (dejaVisitesCs === 0) {
      for (let n = 0; n < entre(4, 8); n++) {
        await prisma.visite.create({
          data: {
            promoteurId: cs.id,
            clientId: pick(siens).id,
            motif: pick(MOTIFS),
            dnAbc: entre(6, 24),
            dnConcurrence: entre(8, 32),
            createdAt: ilYA(entre(0, 28), entre(8, 18)),
          },
        });
      }
    }
    // Prospection assignée au CS (idempotent via idApk).
    for (let n = 0; n < PROSPECTS_CS.length; n++) {
      const p = PROSPECTS_CS[n];
      await prisma.prospect.upsert({
        where: { idApk: `DEMO-P-${cs.idRepr}-${n + 1}` },
        update: {},
        create: {
          idApk: `DEMO-P-${cs.idRepr}-${n + 1}`,
          raisonSociale: p.rs,
          enseigne: `${p.enseigne} ${i + 1}`,
          ville: pick(['Rouen', 'Lille', 'Nantes', 'Reims', 'Tours', 'Metz']),
          statut: p.statut,
          probabilite: p.prob,
          niveauClass: p.classe,
          potentielCaAnnuel: entre(8, 45) * 1000,
          source: pick(['SALON', 'RECOMMANDATION', 'TERRAIN', 'WEB']),
          secteurId: cs.secteurId,
          assignedToId: cs.id,
          createdById: cs.id,
          lastActivityAt: ilYA(entre(0, 10)),
        },
      });
    }
  }

  // --- Visites planifiées des promoteurs (semaine courante + suivante) -----
  // Alimente « Mes visites » (promoteur), la planification (encadrement) et le
  // pilotage Exelys (effectuées / non effectuées). Créées seulement si absentes.
  const lundi = new Date();
  lundi.setHours(9, 0, 0, 0);
  lundi.setDate(lundi.getDate() - ((lundi.getDay() + 6) % 7));
  const jourSem = (semaine, jourIdx, heure = 9) => {
    const d = new Date(lundi);
    d.setDate(d.getDate() + semaine * 7 + jourIdx);
    d.setHours(heure, 0, 0, 0);
    return d;
  };
  const aujourdhuiMs = Date.now();
  let planningsCrees = 0;
  for (let i = 0; i < PROMOTEURS.length; i++) {
    const promoteur = users[PROMOTEURS[i].idRepr];
    const portefeuille = clients.filter((_, idx) => idx % 2 === i);
    const deja = await prisma.planning.count({
      where: { promoteurId: promoteur.id, datePassage: { gte: lundi }, deletedAt: null },
    });
    if (deja > 0) continue;
    // Semaine courante : 2 visites par jour Lun→Ven — passées majoritairement faites,
    // quelques manquées (alertes pilotage), à venir non faites.
    for (let jour = 0; jour < 5; jour++) {
      for (let n = 0; n < 2; n++) {
        const date = jourSem(0, jour, n === 0 ? 9 : 14);
        const passee = date.getTime() < aujourdhuiMs;
        await prisma.planning.create({
          data: {
            promoteurId: promoteur.id,
            clientId: portefeuille[(jour * 2 + n) % portefeuille.length].id,
            datePassage: date,
            fait: passee ? rand() < 0.75 : false,
          },
        });
        planningsCrees++;
      }
    }
    // Semaine suivante : 6 visites prévues.
    for (let n = 0; n < 6; n++) {
      await prisma.planning.create({
        data: {
          promoteurId: promoteur.id,
          clientId: portefeuille[n % portefeuille.length].id,
          datePassage: jourSem(1, n % 5, 10),
          fait: false,
        },
      });
      planningsCrees++;
    }
  }

  // --- Timeline prospection : appels + visites de prospection des CS -------
  const APPELS = [
    { n: 2, resultat: 'REPONDU', duree: 265, commentaire: 'Échange avec la responsable : intéressée par la gamme licences, rappel après réception du catalogue.' },
    { n: 2, resultat: 'SANS_REPONSE', duree: null, commentaire: null },
    { n: 3, resultat: 'RAPPEL_PREVU', duree: 140, commentaire: 'Proposition envoyée par mail — rappel prévu la semaine prochaine pour caler la visite.' },
    { n: 4, resultat: 'REPONDU', duree: 420, commentaire: 'Validation des conditions d’ouverture de compte.' },
  ];
  for (const cs of chefs) {
    for (let a = 0; a < APPELS.length; a++) {
      const app = APPELS[a];
      const prospect = await prisma.prospect.findUnique({ where: { idApk: `DEMO-P-${cs.idRepr}-${app.n}` } });
      if (!prospect) continue;
      await prisma.prospectAppel.upsert({
        where: { idApk: `DEMO-CALL-${cs.idRepr}-${a + 1}` },
        update: {},
        create: {
          idApk: `DEMO-CALL-${cs.idRepr}-${a + 1}`,
          prospectId: prospect.id,
          auteurId: cs.id,
          dateAppel: ilYA(entre(1, 14), entre(9, 17)),
          dureeSec: app.duree,
          resultat: app.resultat,
          commentaire: app.commentaire,
        },
      });
    }
    // Une visite de prospection sur le prospect à l'étape VISITE.
    const enVisite = await prisma.prospect.findUnique({ where: { idApk: `DEMO-P-${cs.idRepr}-3` } });
    if (enVisite) {
      const dejaVisiteProspect = await prisma.visite.count({ where: { prospectId: enVisite.id } });
      if (dejaVisiteProspect === 0) {
        await prisma.visite.create({
          data: {
            promoteurId: cs.id,
            prospectId: enVisite.id,
            motif: 'Visite de prospection',
            pmcCommentaire: 'Premier passage en magasin : linéaire concurrent daté, bonne ouverture du gérant.',
            createdAt: ilYA(entre(2, 9), entre(9, 17)),
          },
        });
      }
    }
  }

  // --- Ma tournée (Helios) : étapes perso des CS + de l'admin --------------
  // Mélange prospection / suivi magasin sur la semaine courante.
  const lundiTournee = new Date();
  lundiTournee.setHours(0, 0, 0, 0);
  lundiTournee.setDate(lundiTournee.getDate() - ((lundiTournee.getDay() + 6) % 7));
  const jourTournee = (idx, heure = 9) => {
    const d = new Date(lundiTournee);
    d.setDate(d.getDate() + idx);
    d.setHours(heure, 0, 0, 0);
    return d;
  };
  const admin = await prisma.user.findFirst({ where: { role: 'ADMIN' }, orderBy: { createdAt: 'asc' } });
  const porteursTournee = [...chefs, ...(admin ? [admin] : [])];
  for (const porteur of porteursTournee) {
    const deja = await prisma.tourneeEtape.count({
      where: { userId: porteur.id, datePassage: { gte: lundiTournee }, deletedAt: null },
    });
    if (deja > 0) continue;
    const mesProspects = await prisma.prospect.findMany({
      where: { assignedToId: porteur.id, deletedAt: null, statut: { notIn: ['GAGNE', 'PERDU'] } },
      take: 3,
    });
    // 2 suivis magasin + jusqu'à 3 prospections répartis sur la semaine.
    const etapes = [
      { clientId: clients[0].id, jour: 0, fait: true },
      { clientId: clients[4].id, jour: 2, fait: false },
      ...mesProspects.map((pr, i) => ({ prospectId: pr.id, jour: (i * 2 + 1) % 5, fait: i === 0 })),
    ];
    for (const e of etapes) {
      await prisma.tourneeEtape.create({
        data: {
          userId: porteur.id,
          clientId: e.clientId ?? null,
          prospectId: e.prospectId ?? null,
          datePassage: jourTournee(e.jour, entre(9, 16)),
          fait: e.fait && jourTournee(e.jour).getTime() < Date.now(),
        },
      });
    }
  }

  // Les promoteurs réels (AD) reçoivent aussi une semaine de visites, pour que le
  // pilotage Exelys (prévues / effectuées / non effectuées) soit rempli partout.
  const promoteursAd = await prisma.user.findMany({
    where: { role: 'COMMERCIAL', isActive: true, username: { not: { startsWith: 'demo.' } } },
    orderBy: { displayName: 'asc' },
    take: 10,
  });
  for (const promoteur of promoteursAd) {
    const deja = await prisma.planning.count({
      where: { promoteurId: promoteur.id, datePassage: { gte: lundi }, deletedAt: null },
    });
    if (deja > 0) continue;
    const nb = entre(4, 8);
    for (let n = 0; n < nb; n++) {
      const date = jourSem(0, n % 5, n % 2 ? 14 : 9);
      const passee = date.getTime() < aujourdhuiMs;
      await prisma.planning.create({
        data: {
          promoteurId: promoteur.id,
          clientId: clients[(n * 3 + promoteur.id.charCodeAt(0)) % clients.length].id,
          datePassage: date,
          fait: passee ? rand() < 0.7 : false,
        },
      });
      planningsCrees++;
    }
  }

  console.log(
    `Seed démo OK — ${clients.length} magasins, ${visites} visites créées (${dejaVisites} existantes), ` +
    `${commandes} commandes traitées, ${CATALOGUE.length} articles, ${promosCreees} promos et ${pemCrees} PEM créées, ` +
    `${CATALOGUE.filter((a) => a.rappel).length} produits en rappel, ${clients.length} objectifs ${annee}, ` +
    `${chefs.length} chefs de secteur enrichis (CA, visites, prospects), ${planningsCrees} visites planifiées.`,
  );
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
