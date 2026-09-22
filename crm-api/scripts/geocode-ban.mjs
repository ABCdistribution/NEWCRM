// Géocodage BAN des magasins (et prospects) sans coordonnées — lots de 3000 en CSV.
import { PrismaClient } from '@crm/database';
import { PrismaPg } from '@prisma/adapter-pg';

const p = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) });
const BAN = 'https://api-adresse.data.gouv.fr/search/csv/';
const LOT = 3000;
const SCORE_MIN = 0.4;

const csvCell = (v) => `"${String(v ?? '').replaceAll('"', '""').replaceAll('\n', ' ').trim()}"`;

/** Mini-parseur CSV (champs entre guillemets, séparateur virgule). */
function parseCsv(text) {
  const rows = [];
  let row = [], cell = '', inQ = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQ) {
      if (c === '"') {
        if (text[i + 1] === '"') { cell += '"'; i++; } else inQ = false;
      } else cell += c;
    } else if (c === '"') inQ = true;
    else if (c === ',') { row.push(cell); cell = ''; }
    else if (c === '\n') { row.push(cell); rows.push(row); row = []; cell = ''; }
    else if (c !== '\r') cell += c;
  }
  if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
  return rows;
}

async function geocodeLot(rows) {
  const entete = 'id,adresse,postcode,city';
  const corps = rows
    .map((r) => [csvCell(r.id), csvCell(r.adresse1 ?? ''), csvCell((r.codePostal ?? '').slice(0, 5)), csvCell(r.ville ?? '')].join(','))
    .join('\n');
  const fd = new FormData();
  fd.append('data', new Blob([entete + '\n' + corps], { type: 'text/csv' }), 'lot.csv');
  fd.append('columns', 'adresse');
  fd.append('postcode', 'postcode');
  fd.append('city', 'city');
  fd.append('result_columns', 'result_score');
  fd.append('result_columns', 'latitude');
  fd.append('result_columns', 'longitude');
  const res = await fetch(BAN, { method: 'POST', body: fd });
  if (!res.ok) throw new Error(`BAN ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const [header, ...lignes] = parseCsv(await res.text());
  const idx = Object.fromEntries(header.map((h, i) => [h, i]));
  const resultats = [];
  for (const l of lignes) {
    if (l.length < header.length) continue;
    const score = Number(l[idx.result_score]);
    const lat = Number(l[idx.latitude]);
    const lng = Number(l[idx.longitude]);
    if (Number.isFinite(lat) && Number.isFinite(lng) && score >= SCORE_MIN) {
      resultats.push({ id: l[idx.id], lat, lng });
    }
  }
  return resultats;
}

async function table(nom, modele) {
  const aFaire = await modele.findMany({
    where: { deletedAt: null, codePostal: { not: null }, latitude: null },
    select: { id: true, adresse1: true, codePostal: true, ville: true },
  });
  console.log(`${nom} : ${aFaire.length} à géocoder`);
  let ok = 0;
  for (let i = 0; i < aFaire.length; i += LOT) {
    const lot = aFaire.slice(i, i + LOT);
    const resultats = await geocodeLot(lot);
    for (let j = 0; j < resultats.length; j += 500) {
      const tranche = resultats.slice(j, j + 500);
      await p.$transaction(
        tranche.map((r) => modele.update({ where: { id: r.id }, data: { latitude: r.lat, longitude: r.lng } })),
      );
    }
    ok += resultats.length;
    console.log(`  lot ${i / LOT + 1} : ${resultats.length}/${lot.length} géocodés (score ≥ ${SCORE_MIN})`);
  }
  console.log(`${nom} : ${ok} géocodés au total`);
}

await table('magasins', p.client);
await table('prospects', p.prospect);
await p.$disconnect();
