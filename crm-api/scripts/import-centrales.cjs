/*
 * Script CLI d'import Minos (centrales / hiérarchie d'achat).
 * Construit l'arbre centrale → sous-centrale → sous-sous-centrale (auto-référencé)
 * et rattache chaque client à sa feuille (sous-sous-centrale).
 *
 * Usage :  node scripts/import-centrales.cjs <chemin_fichier>
 */
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');

const { parseFixedWidth } = require('../dist/import/fixed-width-parser');
const { centraleFieldSpec } = require('../dist/import/mappings/centrale.mapping');
const { centraleRowSchema } = require('../dist/import/mappings/centrale.schema');
const { PrismaClient } = require('@crm/database');
const { PrismaPg } = require('@prisma/adapter-pg');

const BATCH = 500;

function loadDatabaseUrl() {
  const env = fs.readFileSync(path.join(__dirname, '..', '.env'), 'utf8');
  const m = env.match(/^DATABASE_URL="?(.*?)"?\s*$/m);
  if (!m) throw new Error('DATABASE_URL introuvable dans apps/api/.env');
  return m[1];
}

const cleanCode = (v) => {
  if (!v) return null;
  const t = String(v).trim();
  return t === '' || /^0+$/.test(t) || /^\*+$/.test(t) ? null : t;
};

async function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: node scripts/import-centrales.cjs <chemin_fichier>');
    process.exit(1);
  }

  const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: loadDatabaseUrl() }) });
  const t0 = Date.now();
  const log = await prisma.erpImportLog.create({
    data: { fileName: path.basename(file), source: 'MINOS', status: 'PROCESSING', startedAt: new Date() },
  });

  const cache = new Map(); // code -> id
  const ensureCentrale = async (code, nom, parentId) => {
    const c = cleanCode(code);
    if (!c) return null;
    if (cache.has(c)) return cache.get(c);
    const rec = await prisma.centrale.upsert({
      where: { code: c },
      create: { code: c, nom: nom && nom.trim() ? nom.trim() : c, parentId: parentId ?? null },
      update: { nom: nom && nom.trim() ? nom.trim() : c }, // on ne réécrit pas le parent (garde le 1er vu)
    });
    cache.set(c, rec.id);
    return rec.id;
  };

  let total = 0;
  let ok = 0;
  let failed = 0;
  let linked = 0;
  let notFound = 0;
  const errors = [];
  let batch = []; // { codeAs400, centraleId }

  const flush = async () => {
    if (batch.length === 0) return;
    const rows = batch;
    batch = [];
    const results = await prisma.$transaction(
      rows.map((r) =>
        prisma.client.updateMany({ where: { codeAs400: r.codeAs400 }, data: { centraleId: r.centraleId } }),
      ),
    );
    for (const res of results) {
      if (res.count > 0) linked++;
      else notFound++;
    }
  };

  const rl = readline.createInterface({
    input: fs.createReadStream(file, { encoding: 'latin1' }),
    crlfDelay: Infinity,
  });

  for await (const line of rl) {
    if (line.trim().length === 0) continue;
    total++;
    const raw = parseFixedWidth(line, centraleFieldSpec);
    const parsed = centraleRowSchema.safeParse(raw);
    if (!parsed.success) {
      failed++;
      if (errors.length < 30) errors.push(`L${total}: ${parsed.error.issues[0]?.message ?? 'invalide'}`);
      continue;
    }
    const row = parsed.data;
    // Arbre : centrale (haut) -> sous-centrale -> sous-sous-centrale (feuille)
    const centraleId = await ensureCentrale(row.codeCentrale, row.nomCentrale, null);
    const sCentraleId = await ensureCentrale(row.codeSCentrale, row.nomSCentrale, centraleId);
    const ssCentraleId = await ensureCentrale(row.codeSsCentrale, row.nomSsCentrale, sCentraleId);
    ok++;

    const leafId = ssCentraleId ?? sCentraleId ?? centraleId;
    if (leafId) {
      batch.push({ codeAs400: row.codeClient, centraleId: leafId });
      if (batch.length >= BATCH) await flush();
    }
    if (total % 2000 === 0) process.stdout.write(`  ${total} lignes…\r`);
  }
  await flush();

  const status = ok === 0 && failed > 0 ? 'FAILED' : 'SUCCESS';
  await prisma.erpImportLog.update({
    where: { id: log.id },
    data: {
      status,
      rowsTotal: total,
      rowsOk: ok,
      rowsFailed: failed,
      finishedAt: new Date(),
      errorMessage: errors.length ? errors.join('\n') : null,
    },
  });

  const secs = ((Date.now() - t0) / 1000).toFixed(1);
  console.log(
    `\nImport ${status} en ${secs}s — total=${total} ok=${ok} failed=${failed} | ` +
      `centrales=${cache.size} clients_rattachés=${linked} clients_introuvables=${notFound} (log ${log.id})`,
  );
  if (errors.length) console.log('Premières erreurs:\n' + errors.slice(0, 10).join('\n'));
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
