/*
 * Script CLI d'import Minos (articles) — sans HTTP ni auth.
 * Résout marque / gamme / famille en vraies relations (upsert par code, avec cache).
 *
 * Usage :  node scripts/import-articles.cjs <chemin_fichier>
 *   (ou)   pnpm --filter @crm/api import:articles <chemin_fichier>
 */
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');

const { parseFixedWidth } = require('../dist/import/fixed-width-parser');
const { articleFieldSpec } = require('../dist/import/mappings/article.mapping');
const { articleRowSchema, toMinosArticleData } = require('../dist/import/mappings/article.schema');
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
  return t === '' || /^\*+$/.test(t) ? null : t;
};

async function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: node scripts/import-articles.cjs <chemin_fichier>');
    process.exit(1);
  }

  const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: loadDatabaseUrl() }) });
  const t0 = Date.now();
  const log = await prisma.erpImportLog.create({
    data: { fileName: path.basename(file), source: 'MINOS', status: 'PROCESSING', startedAt: new Date() },
  });

  const marqueCache = new Map();
  const gammeCache = new Map();
  const familleCache = new Map();

  const ensureRef = async (delegate, cache, code) => {
    const c = cleanCode(code);
    if (!c) return null;
    if (cache.has(c)) return cache.get(c);
    const rec = await delegate.upsert({ where: { code: c }, create: { code: c, nom: c }, update: {} });
    cache.set(c, rec.id);
    return rec.id;
  };

  let total = 0;
  let ok = 0;
  let failed = 0;
  const errors = [];
  let batch = [];

  const flush = async () => {
    if (batch.length === 0) return;
    const rows = batch;
    batch = [];
    await prisma.$transaction(
      rows.map((d) => prisma.article.upsert({ where: { codeAs400: d.codeAs400 }, create: d, update: d })),
    );
  };

  const rl = readline.createInterface({
    input: fs.createReadStream(file, { encoding: 'latin1' }),
    crlfDelay: Infinity,
  });

  for await (const line of rl) {
    if (line.trim().length === 0) continue;
    total++;
    const raw = parseFixedWidth(line, articleFieldSpec);
    const parsed = articleRowSchema.safeParse(raw);
    if (!parsed.success) {
      failed++;
      if (errors.length < 30) errors.push(`L${total}: ${parsed.error.issues[0]?.message ?? 'invalide'}`);
      continue;
    }
    const row = parsed.data;
    const marqueId = await ensureRef(prisma.marque, marqueCache, row.codeMarque);
    const gammeId = await ensureRef(prisma.gamme, gammeCache, row.gamme);
    const familleId = await ensureRef(prisma.famille, familleCache, row.codeFamille);
    batch.push({ ...toMinosArticleData(row), marqueId, gammeId, familleId });
    ok++;
    if (batch.length >= BATCH) await flush();
    if (total % 1000 === 0) process.stdout.write(`  ${total} lignes…\r`);
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
      `marques=${marqueCache.size} gammes=${gammeCache.size} familles=${familleCache.size} (log ${log.id})`,
  );
  if (errors.length) console.log('Premières erreurs:\n' + errors.slice(0, 10).join('\n'));
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
