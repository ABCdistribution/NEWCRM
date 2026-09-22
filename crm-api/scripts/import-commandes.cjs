/*
 * Script CLI d'import Minos (commandes ERP).
 * En-tête (une par numéro) + lignes ; client & article résolus en FK.
 * Annulation datée (checky/m/d) au lieu de suppression → historique préservé.
 *
 * Usage :  node scripts/import-commandes.cjs <chemin_fichier>
 */
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');

const { parseFixedWidth } = require('../dist/import/fixed-width-parser');
const { commandeFieldSpec } = require('../dist/import/mappings/commande.mapping');
const { commandeRowSchema, parseDecimal4, parseDate } = require('../dist/import/mappings/commande.schema');
const { PrismaClient } = require('@crm/database');
const { PrismaPg } = require('@prisma/adapter-pg');

const BATCH = 500;

function loadDatabaseUrl() {
  const env = fs.readFileSync(path.join(__dirname, '..', '.env'), 'utf8');
  const m = env.match(/^DATABASE_URL="?(.*?)"?\s*$/m);
  if (!m) throw new Error('DATABASE_URL introuvable dans apps/api/.env');
  return m[1];
}

const clean = (v) => {
  if (!v) return null;
  const t = String(v).trim();
  return t === '' || /^0+$/.test(t) || /^\*+$/.test(t) ? null : t;
};

async function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: node scripts/import-commandes.cjs <chemin_fichier>');
    process.exit(1);
  }

  const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: loadDatabaseUrl() }) });
  const t0 = Date.now();
  const log = await prisma.erpImportLog.create({
    data: { fileName: path.basename(file), source: 'MINOS', status: 'PROCESSING', startedAt: new Date() },
  });

  // Préchargement clients + articles (codeAs400 -> id).
  const clientCache = new Map();
  const articleCache = new Map();
  for (const c of await prisma.client.findMany({ select: { id: true, codeAs400: true } })) clientCache.set(c.codeAs400, c.id);
  for (const a of await prisma.article.findMany({ select: { id: true, codeAs400: true } })) articleCache.set(a.codeAs400, a.id);

  const commandeCache = new Map(); // numero -> id
  const ensureCommande = async (numero, header) => {
    if (commandeCache.has(numero)) return commandeCache.get(numero);
    const rec = await prisma.commande.upsert({
      where: { numero },
      create: { numero, ...header },
      update: header, // rafraîchit l'en-tête (client, rep, annulation…)
    });
    commandeCache.set(numero, rec.id);
    return rec.id;
  };

  let total = 0;
  let ok = 0;
  let failed = 0;
  let annulees = 0;
  const errors = [];
  let batch = [];

  const flush = async () => {
    if (batch.length === 0) return;
    const rows = batch;
    batch = [];
    await prisma.$transaction(
      rows.map((l) =>
        prisma.commandeLigne.upsert({
          where: { commandeId_noLigne: { commandeId: l.commandeId, noLigne: l.noLigne } },
          create: l,
          update: { articleId: l.articleId, libelleArticle: l.libelleArticle, quantite: l.quantite, montant: l.montant },
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
    const raw = parseFixedWidth(line, commandeFieldSpec);
    const parsed = commandeRowSchema.safeParse(raw);
    if (!parsed.success) {
      failed++;
      if (errors.length < 30) errors.push(`L${total}: ${parsed.error.issues[0]?.message ?? 'invalide'}`);
      continue;
    }
    const row = parsed.data;
    const dateCommande = parseDate(row.anneeCmd, row.moisCmd, row.jourCmd);
    const dateAnnulation = parseDate(row.checkAnnee, row.checkMois, row.checkJour);
    if (dateAnnulation) annulees++;

    const commandeId = await ensureCommande(row.numero.trim(), {
      clientId: row.codeClient ? clientCache.get(row.codeClient.trim()) ?? null : null,
      raisonSocialeCmd: clean(row.raisonSocialeCmd),
      idRepr: clean(row.idRepr),
      typeCmd: clean(row.typeCmd),
      idCommandeApk: clean(row.idCommandeApk),
      dateCommande,
      dateAnnulation,
    });

    batch.push({
      commandeId,
      noLigne: row.noLigne && row.noLigne.trim() ? row.noLigne.trim() : '0',
      articleId: row.codeArticle ? articleCache.get(row.codeArticle.trim()) ?? null : null,
      libelleArticle: clean(row.libelleArticle),
      quantite: parseDecimal4(row.quantite),
      montant: parseDecimal4(row.montant),
    });
    ok++;
    if (batch.length >= BATCH) await flush();
    if (total % 5000 === 0) process.stdout.write(`  ${total} lignes…\r`);
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
      `commandes=${commandeCache.size} lignes_annulées=${annulees} (log ${log.id})`,
  );
  if (errors.length) console.log('Premières erreurs:\n' + errors.slice(0, 10).join('\n'));
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
