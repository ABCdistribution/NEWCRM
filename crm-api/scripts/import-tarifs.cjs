/*
 * Script CLI d'import Minos (tarifs).
 * Rattache chaque tarif à son article (par codeAs400) ; prix à 4 décimales.
 *
 * Usage :  node scripts/import-tarifs.cjs <chemin_fichier>
 */
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');

const { parseFixedWidth } = require('../dist/import/fixed-width-parser');
const { tarifFieldSpec } = require('../dist/import/mappings/tarif.mapping');
const { tarifRowSchema, parsePrix } = require('../dist/import/mappings/tarif.schema');
const { PrismaClient } = require('@crm/database');
const { PrismaPg } = require('@prisma/adapter-pg');

const BATCH = 500;

function loadDatabaseUrl() {
  const env = fs.readFileSync(path.join(__dirname, '..', '.env'), 'utf8');
  const m = env.match(/^DATABASE_URL="?(.*?)"?\s*$/m);
  if (!m) throw new Error('DATABASE_URL introuvable dans apps/api/.env');
  return m[1];
}

async function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: node scripts/import-tarifs.cjs <chemin_fichier>');
    process.exit(1);
  }

  const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: loadDatabaseUrl() }) });
  const t0 = Date.now();
  const log = await prisma.erpImportLog.create({
    data: { fileName: path.basename(file), source: 'MINOS', status: 'PROCESSING', startedAt: new Date() },
  });

  // Préchargement des articles (codeAs400 -> id) pour des résolutions en mémoire.
  const articleCache = new Map();
  const arts = await prisma.article.findMany({ select: { id: true, codeAs400: true } });
  for (const a of arts) articleCache.set(a.codeAs400, a.id);

  let total = 0;
  let ok = 0;
  let failed = 0;
  let articleIntrouvable = 0;
  const errors = [];
  let batch = [];

  const flush = async () => {
    if (batch.length === 0) return;
    const rows = batch;
    batch = [];
    await prisma.$transaction(
      rows.map((t) =>
        prisma.tarif.upsert({
          where: { articleId_codeTarif: { articleId: t.articleId, codeTarif: t.codeTarif } },
          create: t,
          update: { montant: t.montant },
        }),
      ),
    );
  };

  const rl = readline.createInterface({
    input: fs.createReadStream(file, { encoding: 'latin1' }),
    crlfDelay: Infinity,
  });

  for await (const line of rl) {
    if (line.trim().length === 0) continue;
    total++;
    const raw = parseFixedWidth(line, tarifFieldSpec);
    const parsed = tarifRowSchema.safeParse(raw);
    if (!parsed.success) {
      failed++;
      if (errors.length < 30) errors.push(`L${total}: ${parsed.error.issues[0]?.message ?? 'invalide'}`);
      continue;
    }
    const row = parsed.data;
    const articleId = articleCache.get(row.codeArticle.trim());
    const montant = parsePrix(row.prix);
    if (!articleId || !montant) {
      if (!articleId) articleIntrouvable++;
      failed++;
      continue;
    }
    const codeTarif = row.codeTarif && row.codeTarif.trim() ? row.codeTarif.trim() : '80';
    batch.push({ articleId, codeTarif, montant });
    ok++;
    if (batch.length >= BATCH) await flush();
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
    `\nImport ${status} en ${secs}s — total=${total} ok=${ok} failed=${failed} ` +
      `(dont articles introuvables=${articleIntrouvable}) (log ${log.id})`,
  );
  if (errors.length) console.log('Premières erreurs:\n' + errors.slice(0, 10).join('\n'));
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
