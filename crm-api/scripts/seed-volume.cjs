/*
 * Seed de VOLUME pour la démo (17/09/2026) : génère une activité conséquente et
 * réaliste sur les magasins réellement importés de Minos, rattachée aux VRAIS
 * utilisateurs AD (chefs de secteur, promoteurs, directeurs) + promoteurs démo :
 * commandes 3 mois + N-1 (lignes articles), visites 45 jours avec relevés,
 * visites planifiées ±2 semaines, prospects par CS/DR avec journal, objectifs,
 * contacts/notes/journal des magasins, notifications, tournées perso, promos,
 * PEM et produits en rappel.
 *
 * Idempotent : chaque section porte un marqueur (préfixe DV-) ou un seuil.
 *
 * Usage :
 *   docker cp crm-api/scripts/seed-volume.cjs www-api-1:/app/crm-api/scripts/
 *   docker exec www-api-1 node crm-api/scripts/seed-volume.cjs
 */
const { randomUUID } = require('node:crypto');
const { PrismaClient } = require('@crm/database');
const { PrismaPg } = require('@prisma/adapter-pg');

const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL absent de l’environnement.');
  process.exit(1);
}
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });

function mulberry32(a) {
  return function () {
    let t = (a += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(424242);
const entre = (min, max) => Math.floor(rand() * (max - min + 1)) + min;
const pick = (arr) => arr[Math.floor(rand() * arr.length)];
const jourA = (delta, h = 9) => {
  const d = new Date();
  d.setDate(d.getDate() + delta);
  d.setHours(h, entre(0, 59), 0, 0);
  return d;
};
const variantes = (code) => {
  const v = new Set([code]);
  if (/^\d+$/.test(code)) {
    v.add(code.padStart(3, '0'));
    v.add(String(Number(code)));
  }
  return [...v];
};

async function main() {
  // --- Porteurs : tous les vrais porteurs de code + promoteurs démo ---------
  const porteurs = await prisma.user.findMany({
    where: {
      isActive: true,
      idRepr: { not: null },
      role: { in: ['COMMERCIAL', 'CHEF_SECTEUR', 'DIRECTEUR_REGIONAL'] },
    },
    select: { id: true, displayName: true, idRepr: true, role: true },
  });
  const chefs = porteurs.filter((p) => p.role === 'CHEF_SECTEUR');
  const directeurs = await prisma.user.findMany({
    where: { role: 'DIRECTEUR_REGIONAL', isActive: true },
    select: { id: true, displayName: true, idRepr: true },
  });
  const admin = await prisma.user.findFirst({ where: { role: 'ADMIN' }, select: { id: true } });
  const articles = await prisma.article.findMany({
    where: { actif: true },
    take: 60,
    orderBy: { codeAs400: 'asc' },
    select: { id: true, libelle: true },
  });

  // Magasins de chaque porteur (10 max) — pool global ~600 magasins.
  const parPorteur = new Map();
  for (const p of porteurs) {
    const codes = variantes(p.idRepr);
    const siens = await prisma.client.findMany({
      where: {
        deletedAt: null,
        actif: true,
        OR: [{ idCommercial1: { in: codes } }, { idCommercial2: { in: codes } }],
      },
      take: 10,
      select: { id: true, enseigne: true, email: true },
    });
    if (siens.length) parPorteur.set(p.id, { user: p, magasins: siens });
  }
  const totalMagasins = [...parPorteur.values()].reduce((s, x) => s + x.magasins.length, 0);
  console.log(`Porteurs avec magasins : ${parPorteur.size} — pool de ${totalMagasins} magasins`);

  // --- 1. Commandes 3 mois + N-1, avec lignes articles ----------------------
  const dejaVol = await prisma.commande.findFirst({ where: { numero: { startsWith: 'DV-' } } });
  if (!dejaVol) {
    const commandes = [];
    const lignes = [];
    let num = 1;
    const ajouterCommande = (clientId, idRepr, date) => {
      const id = randomUUID();
      const statut = date < jourA(-6) ? pick(['LIVREE', 'LIVREE', 'LIVREE_PARTIELLE', 'EXPEDIEE']) : pick(['EN_PREPARATION', 'EXPEDIEE']);
      commandes.push({
        id,
        numero: `DV-${String(num++).padStart(6, '0')}`,
        clientId,
        idRepr,
        typeCmd: 'STANDARD',
        dateCommande: date,
        statutLivraison: statut,
        dateExpedition: statut !== 'EN_PREPARATION' ? new Date(date.getTime() + 2 * 864e5) : null,
        dateLivraison: statut.startsWith('LIVREE') ? new Date(date.getTime() + 4 * 864e5) : null,
        transporteur: statut !== 'EN_PREPARATION' ? pick(['GLS', 'DPD', 'Geodis']) : null,
      });
      const nb = entre(2, 5);
      for (let l = 1; l <= nb; l++) {
        const art = pick(articles);
        commandesDernierMontant = entre(60, 900);
        lignes.push({
          commandeId: id,
          noLigne: String(l),
          articleId: art.id,
          libelleArticle: art.libelle,
          quantite: entre(2, 24),
          montant: commandesDernierMontant,
        });
      }
    };
    let commandesDernierMontant = 0;
    for (const { user, magasins } of parPorteur.values()) {
      for (const m of magasins) {
        // Mois courant : 1 à 3 commandes — la démo doit montrer du CA partout.
        for (let i = 0; i < entre(1, 3); i++) ajouterCommande(m.id, user.idRepr, jourA(-entre(0, 27), entre(8, 18)));
        // 2 mois précédents.
        for (let i = 0; i < entre(1, 3); i++) ajouterCommande(m.id, user.idRepr, jourA(-entre(28, 85), entre(8, 18)));
        // Même mois N-1 (comparatif Δ vs N-1).
        if (rand() < 0.8) {
          for (let i = 0; i < entre(1, 2); i++) {
            const d = jourA(-entre(0, 27), entre(8, 18));
            d.setFullYear(d.getFullYear() - 1);
            ajouterCommande(m.id, user.idRepr, d);
          }
        }
      }
    }
    await prisma.commande.createMany({ data: commandes, skipDuplicates: true });
    // Lignes par paquets (éviter une requête géante unique).
    for (let i = 0; i < lignes.length; i += 2000) {
      await prisma.commandeLigne.createMany({ data: lignes.slice(i, i + 2000), skipDuplicates: true });
    }
    console.log(`✔ Commandes : ${commandes.length} (+ ${lignes.length} lignes)`);
  } else console.log('· Commandes de volume déjà présentes');

  // --- 2. Objectifs annuels des magasins actifs -----------------------------
  {
    const annee = new Date().getFullYear();
    let n = 0;
    for (const { magasins } of parPorteur.values()) {
      for (const m of magasins) {
        await prisma.objectif.upsert({
          where: { clientId_annee: { clientId: m.id, annee } },
          update: {},
          create: { clientId: m.id, annee, cibleCa: entre(8, 60) * 1000, creeParId: admin?.id ?? null },
        });
        n++;
      }
    }
    console.log(`✔ Objectifs ${annee} : ${n} magasins couverts`);
  }

  // --- 3. Visites 45 jours avec relevés -------------------------------------
  if (!(await prisma.visite.findFirst({ where: { idApk: { startsWith: 'DV-V-' } } }))) {
    const visites = [];
    const dns = [];
    const steps = [];
    let n = 1;
    for (const { user, magasins } of parPorteur.values()) {
      for (const m of magasins) {
        for (let i = 0; i < entre(1, 3); i++) {
          const id = randomUUID();
          const date = jourA(-entre(0, 45), entre(8, 17));
          visites.push({
            id,
            idApk: `DV-V-${n++}`,
            promoteurId: user.id,
            clientId: m.id,
            motif: pick(['Visite planifiée', 'Relevé rayon', 'Pose PLV', 'Suivi commande']),
            dnAbc: entre(4, 30),
            dnConcurrence: entre(6, 40),
            dnGondoleHaute: entre(0, 6),
            dnGondoleBasse: entre(0, 6),
            pem: rand() < 0.35,
            createdAt: date,
            updatedAt: date,
          });
          dns.push(
            { visiteId: id, type: 'ABC', marque: 'ABC', metrage: entre(2, 8) },
            { visiteId: id, type: 'CONCURRENCE', marque: pick(["L'Oréal", 'Gilbert', 'MDD']), metrage: entre(3, 10) },
          );
          steps.push(
            { visiteId: id, etape: 'ARRIVEE', horodatage: date },
            { visiteId: id, etape: 'DEPART', horodatage: new Date(date.getTime() + entre(20, 60) * 6e4) },
          );
        }
      }
    }
    await prisma.visite.createMany({ data: visites, skipDuplicates: true });
    for (let i = 0; i < dns.length; i += 2000) await prisma.visiteDN.createMany({ data: dns.slice(i, i + 2000) });
    for (let i = 0; i < steps.length; i += 2000) await prisma.visiteStep.createMany({ data: steps.slice(i, i + 2000) });
    console.log(`✔ Visites : ${visites.length} (relevés DN + étapes)`);
  } else console.log('· Visites de volume déjà présentes');

  // --- 4. Visites planifiées ±2 semaines (Selios) ---------------------------
  if ((await prisma.planning.count({ where: { raison: 'DV' } })) === 0) {
    const plannings = [];
    for (const { user, magasins } of parPorteur.values()) {
      if (user.role !== 'COMMERCIAL') continue;
      for (const m of magasins.slice(0, 6)) {
        // Passé : majoritairement faites ; futur : à faire.
        plannings.push({
          promoteurId: user.id, clientId: m.id, datePassage: jourA(-entre(1, 13), entre(8, 17)),
          fait: rand() < 0.75, raison: 'DV',
        });
        plannings.push({
          promoteurId: user.id, clientId: m.id, datePassage: jourA(entre(1, 13), entre(8, 17)),
          fait: false, raison: 'DV',
        });
      }
    }
    await prisma.planning.createMany({ data: plannings });
    console.log(`✔ Visites planifiées : ${plannings.length}`);
  } else console.log('· Visites planifiées de volume déjà présentes');

  // --- 5. Prospects par CS & DR, avec journal et opportunités ---------------
  if ((await prisma.prospect.count({ where: { idApk: { startsWith: 'DV-P-' } } })) < 20) {
    const ENSEIGNES = [
      ['Biocoop', 'BIOCOOP DISTRIBUTION'], ['Naturalia', 'NATURALIA FRANCE'], ['Grand Frais', 'GF EXPLOITATION'],
      ['Beauty Success', 'BS FRANCHISE'], ['Parapharmacie Lafayette', 'PARA LAFAYETTE'], ['Monoprix', 'MONOPRIX EXPLOITATION'],
      ['Cora', 'CORA SAS'], ['Colruyt', 'COLRUYT RETAIL'], ['Bio c Bon', 'BIO C BON SAS'], ['Marché Frais', 'MF DISTRIBUTION'],
    ];
    const VILLES = [['Lyon', '69003'], ['Marseille', '13008'], ['Lille', '59000'], ['Nantes', '44000'], ['Rouen', '76000'], ['Nice', '06000'], ['Rennes', '35000'], ['Grenoble', '38000']];
    const ETAPES = ['NOUVEAU', 'CONTACTE', 'PROPOSITION', 'VISITE', 'NEGOCIATION', 'GAGNE', 'PERDU'];
    const PROB = { NOUVEAU: 10, CONTACTE: 25, PROPOSITION: 50, VISITE: 65, NEGOCIATION: 80, GAGNE: 100, PERDU: 0 };
    const MOTIFS_PERTE = ['PRIX', 'CONCURRENCE', 'PAS_DE_BESOIN', 'SANS_REPONSE', 'AUTRE'];
    let n = 0;
    for (const cs of [...chefs, ...directeurs]) {
      for (let i = 0; i < entre(3, 5); i++) {
        const [enseigne, rs] = pick(ENSEIGNES);
        const [ville, cp] = pick(VILLES);
        const statut = pick(ETAPES);
        const p = await prisma.prospect.create({
          data: {
            raisonSociale: rs, enseigne: `${enseigne} ${ville}`, ville, codePostal: cp,
            adresse1: `${entre(1, 150)} rue du Commerce`,
            telephone: `0${entre(1, 5)} ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)}`,
            email: `contact@${enseigne.toLowerCase().replace(/[^a-z]/g, '')}-${ville.toLowerCase().replace(/[^a-z]/g, '')}.fr`,
            statut, probabilite: PROB[statut], niveauClass: pick(['A', 'B', 'B', 'C', 'C', 'D']),
            potentielCaAnnuel: entre(5, 80) * 1000, source: pick(['TERRAIN', 'SALON', 'RECOMMANDATION', 'WEB']), idApk: `DV-P-${n + 1}-${cs.id.slice(0, 8)}-${i}`,
            motifPerte: statut === 'PERDU' ? pick(MOTIFS_PERTE) : null,
            assignedToId: cs.id, createdById: cs.id,
            lastActivityAt: jourA(-entre(0, 20)),
            createdAt: jourA(-entre(10, 90)),
          },
        });
        n++;
        for (let a = 0; a < entre(1, 3); a++) {
          await prisma.prospectAppel.create({
            data: {
              prospectId: p.id, auteurId: cs.id, dateAppel: jourA(-entre(0, 20), entre(9, 18)),
              dureeSec: entre(60, 600), resultat: pick(['REPONDU', 'REPONDU', 'MESSAGERIE', 'SANS_REPONSE', 'RAPPEL_PREVU']),
              commentaire: pick([null, 'Premier contact, bon accueil.', 'Rappeler la semaine prochaine.', 'Attente retour du directeur.']),
            },
          });
        }
        if (rand() < 0.6) {
          await prisma.prospectEmail.create({
            data: {
              prospectId: p.id, auteurId: cs.id, dateEmail: jourA(-entre(0, 15)),
              destinataire: p.email, sujet: pick(['Présentation ABC Distribution', 'Proposition commerciale', 'Suite à notre visite']),
            },
          });
        }
        if (['PROPOSITION', 'VISITE', 'NEGOCIATION', 'GAGNE'].includes(statut) && rand() < 0.7) {
          await prisma.opportunite.create({
            data: {
              type: 'REFERENCEMENT', prospectId: p.id, libelle: `Référencement — ${p.enseigne}`,
              valeurEstimee: entre(4, 40) * 1000,
              statut: statut === 'GAGNE' ? 'GAGNEE' : 'OUVERTE',
              assignedToId: cs.id,
              articles: articles.length ? { connect: [{ id: pick(articles).id }] } : undefined,
            },
          });
        }
      }
    }
    console.log(`✔ Prospects : ${n} (+ appels, emails, opportunités)`);
  } else console.log('· Prospects de volume déjà présents');

  // --- 6. Contacts, notes & journal des magasins ----------------------------
  if ((await prisma.clientContact.count()) < 100) {
    const PRENOMS = ['Claire', 'Marc', 'Sophie', 'Julien', 'Nadia', 'Paul', 'Emma', 'Karim', 'Léa', 'Hugo'];
    const NOMS = ['Lefèvre', 'Garnier', 'Rossi', 'Petit', 'Nguyen', 'Moreau', 'Blanc', 'Dupas', 'Marchand', 'Coste'];
    let n = 0;
    for (const { user, magasins } of parPorteur.values()) {
      for (const m of magasins.slice(0, 5)) {
        const deja = await prisma.clientContact.findFirst({ where: { clientId: m.id } });
        if (deja) continue;
        await prisma.clientContact.createMany({
          data: [
            { clientId: m.id, prenom: pick(PRENOMS), nom: pick(NOMS), typePoste: 'Chef de rayon', poste: 'Rayon hygiène-beauté', portable: `06 ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)}`, creeParId: user.id },
            { clientId: m.id, prenom: pick(PRENOMS), nom: pick(NOMS), typePoste: 'Directeur', fixe: `04 ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)} ${entre(10, 99)}`, creeParId: user.id },
          ],
        });
        await prisma.clientNote.create({
          data: {
            clientId: m.id, auteurId: user.id, createdAt: jourA(-entre(1, 25)),
            remarque: pick([
              'Réagencement du rayon prévu — repasser poser la PLV.',
              'Le directeur souhaite une OP sur les accessoires cheveux.',
              'Concurrent très présent en tête de gondole.',
              'Réassort rapide demandé sur la gamme manucure.',
              'Bonne rotation sur les pinceaux — élargir la gamme ?',
            ]),
          },
        });
        await prisma.clientAppel.create({
          data: {
            clientId: m.id, auteurId: user.id, dateAppel: jourA(-entre(0, 12), entre(9, 18)),
            dureeSec: entre(60, 480), resultat: pick(['REPONDU', 'REPONDU', 'MESSAGERIE']),
            commentaire: pick([null, 'Point commandes du mois.', 'Prise de RDV.']),
          },
        });
        if (rand() < 0.6) {
          await prisma.clientEmail.create({
            data: { clientId: m.id, auteurId: user.id, dateEmail: jourA(-entre(0, 15)), destinataire: m.email ?? 'contact@magasin.fr', sujet: pick(['Confirmation de passage', 'Catalogue promos', 'Suivi de commande']) },
          });
        }
        n++;
      }
    }
    console.log(`✔ Contacts/notes/journal : ${n} magasins supplémentaires`);
  } else console.log('· Contacts déjà nombreux');

  // --- 7. Notifications supplémentaires -------------------------------------
  if ((await prisma.notification.count()) < 150) {
    const users = await prisma.user.findMany({
      where: { isActive: true, role: { in: ['COMMERCIAL', 'CHEF_SECTEUR', 'DIRECTEUR_REGIONAL', 'ADMIN'] } },
      select: { id: true },
    });
    const MODELES = [
      { type: 'RELANCE_VISITE', titre: 'Magasin à revisiter', message: 'CARREFOUR MARKET n’a pas été visité depuis 35 jours.', lien: '/clients' },
      { type: 'COMMANDE_LIVREE', titre: 'Commande livrée', message: 'La commande DV-000112 a été livrée chez INTERMARCHE.', lien: '/commandes' },
      { type: 'OBJECTIF', titre: 'Objectif du mois : 82 %', message: 'Encore un petit effort, la barre des 100 % est à portée.', lien: '/' },
      { type: 'PROMO_FIN', titre: 'Promo bientôt terminée', message: 'L’OP « rentrée beauté » se termine vendredi.', lien: '/promos' },
      { type: 'RAPPEL_QUALITE', titre: 'Rappel produit', message: 'Un article de la gamme soin fait l’objet d’un rappel.', lien: '/qualite' },
    ];
    const data = [];
    for (const u of users) {
      for (const mo of MODELES) {
        if (rand() < 0.3) continue;
        data.push({ userId: u.id, ...mo, luAt: rand() < 0.4 ? jourA(-1) : null, createdAt: jourA(-entre(0, 6), entre(7, 19)) });
      }
    }
    await prisma.notification.createMany({ data });
    console.log(`✔ Notifications : +${data.length}`);
  } else console.log('· Notifications déjà nombreuses');

  // --- 8. Ma tournée (Helios) : étapes perso des CS/DR/admin ----------------
  {
    const planificateurs = [...chefs, ...directeurs, ...(admin ? [{ id: admin.id }] : [])];
    let n = 0;
    for (const u of planificateurs) {
      const deja = await prisma.tourneeEtape.count({ where: { userId: u.id, deletedAt: null } });
      if (deja >= 5) continue;
      const pool = parPorteur.get(u.id)?.magasins
        ?? [...parPorteur.values()][entre(0, parPorteur.size - 1)]?.magasins ?? [];
      const prospectsDeLui = await prisma.prospect.findMany({
        where: { assignedToId: u.id, deletedAt: null, statut: { notIn: ['GAGNE', 'PERDU'] } },
        take: 3,
        select: { id: true },
      });
      // Semaine courante + suivante, lundi→vendredi.
      for (let j = 0; j < 8 && pool.length; j++) {
        const delta = ((j % 5) + 1) - new Date().getDay() + (j >= 5 ? 7 : 0);
        // Contrainte SQL : exactement UNE cible (client OU prospect).
        const surProspect = prospectsDeLui.length > 0 && rand() < 0.3;
        await prisma.tourneeEtape.create({
          data: {
            userId: u.id,
            clientId: surProspect ? null : pick(pool).id,
            prospectId: surProspect ? pick(prospectsDeLui).id : null,
            datePassage: jourA(delta, entre(9, 16)),
            fait: delta < 0,
            note: pick([null, 'Prévoir catalogue', 'Point OP avec le directeur', null]),
          },
        });
        n++;
      }
    }
    console.log(`✔ Ma tournée : ${n} étapes ajoutées`);
  }

  // --- 9. Promos, PEM & rappels qualité --------------------------------------
  if ((await prisma.promo.count()) < 20 && articles.length >= 30) {
    const data = [];
    for (let i = 0; i < 12; i++) {
      const debut = jourA(-entre(0, 20));
      data.push({
        articleId: articles[10 + i].id,
        libelle: pick(['OP rentrée beauté', 'Promo fêtes', 'Prix choc', 'Lot découverte']),
        dateDebut: debut,
        dateFin: new Date(debut.getTime() + entre(10, 30) * 864e5),
        actif: true,
      });
    }
    await prisma.promo.createMany({ data });
    console.log('✔ Promos : +12');
  } else console.log('· Promos déjà nombreuses');

  if ((await prisma.pemArticle.count()) < 12 && articles.length >= 40) {
    await prisma.pemArticle.createMany({
      data: articles.slice(30, 40).map((a) => ({ articleId: a.id, actif: true })),
    });
    console.log('✔ PEM : +10');
  } else console.log('· PEM déjà nombreux');

  {
    const enRappel = await prisma.article.count({ where: { retourAutorise: true } });
    if (enRappel < 6) {
      const cibles = articles.slice(50, 56);
      for (const a of cibles) {
        await prisma.article.update({ where: { id: a.id }, data: { retourAutorise: true } });
      }
      console.log(`✔ Rappels qualité : ${cibles.length} articles passés en rappel`);
    } else console.log('· Rappels qualité déjà présents');
  }

  console.log('Seed de volume terminé.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
