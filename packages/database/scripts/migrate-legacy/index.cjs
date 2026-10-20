#!/usr/bin/env node
/**
 * Migration de l'ancien CRM (MySQL « gescom », copie de staging) vers le nouveau schéma Prisma (Postgres).
 *
 *   node scripts/migrate-legacy/index.cjs [étape ...]      (depuis packages/database)
 *   node scripts/migrate-legacy/index.cjs --list
 *
 * - Source : MySQL de staging (db-mysql-staging, 127.0.0.1:3307) — jamais la prod.
 * - Cible  : Postgres `db` (127.0.0.1:5432).
 * - Relançable : ids = UUID v5 déterministes dérivés des clés legacy + ON CONFLICT DO UPDATE.
 *   Les entités à clé métier (users.username, clients.codeAs400, articles.codeAs400, secteurs/regions.code)
 *   sont rattachées à l'existant (import AS400, AD) au lieu d'être dupliquées.
 * - Les lignes dont une référence est introuvable (client/user/article absent) sont ignorées et comptées
 *   dans le rapport final.
 */
const crypto = require('node:crypto');
const path = require('node:path');
const mysql = require('mysql2/promise');
const { Client: PgClient } = require('pg');
require('dotenv').config({ path: path.resolve(__dirname, '../../../../.env'), quiet: true });

const env = process.env;
const NS = Buffer.from('6f1d2c1e9a4b4c7e8d3a5b7c9e0f1a2b', 'hex');

// ---------------------------------------------------------------- utilitaires
const uuid5 = (name) => {
  const h = crypto.createHash('sha1').update(NS).update(String(name)).digest();
  h[6] = (h[6] & 0x0f) | 0x50;
  h[8] = (h[8] & 0x3f) | 0x80;
  const x = h.subarray(0, 16).toString('hex');
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20)}`;
};
const s = (v) => (v === null || v === undefined ? null : String(v).trim() || null);
const ts = (v) => (!v || String(v).startsWith('0000') ? null : String(v));
const int = (v) => {
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : null;
};
const report = {}; // étape -> { lus, ecrits, ignores: { motif: n } }
const stat = (step) => (report[step] ??= { lus: 0, ecrits: 0, ignores: {} });
const skip = (step, why) => {
  const r = stat(step);
  r.ignores[why] = (r.ignores[why] || 0) + 1;
};

let my; // mysql source
let pg; // postgres cible

const q = async (sql, params) => (await my.query(sql, params))[0];

/** Parcourt une table legacy par paquets (clé primaire croissante). */
async function* batches(table, { size = 20000, where = '1=1', cols = '*' } = {}) {
  let last = 0;
  for (;;) {
    const rows = await q(`SELECT ${cols} FROM \`${table}\` WHERE id > ? AND ${where} ORDER BY id LIMIT ${size}`, [last]);
    if (!rows.length) return;
    last = rows[rows.length - 1].id;
    yield rows;
  }
}

/** INSERT multi-lignes ... ON CONFLICT (conflict) DO UPDATE. */
async function upsert(table, cols, rows, conflict = ['id'], { returning } = {}) {
  if (!rows.length) return [];
  const q2 = (c) => `"${c}"`;
  const upd = cols.filter((c) => !conflict.includes(c));
  const per = Math.max(1, Math.floor(60000 / cols.length));
  const out = [];
  for (let i = 0; i < rows.length; i += per) {
    const chunk = rows.slice(i, i + per);
    const params = [];
    const values = chunk
      .map((r) => `(${cols.map((c) => { params.push(r[c] ?? null); return `$${params.length}`; }).join(',')})`)
      .join(',');
    const sql =
      `INSERT INTO "${table}" (${cols.map(q2).join(',')}) VALUES ${values} ` +
      `ON CONFLICT (${conflict.map(q2).join(',')}) ` +
      (upd.length ? `DO UPDATE SET ${upd.map((c) => `${q2(c)}=EXCLUDED.${q2(c)}`).join(',')}` : 'DO NOTHING') +
      (returning ? ` RETURNING ${returning}` : '');
    const res = await pg.query(sql, params);
    if (returning) out.push(...res.rows);
  }
  return out;
}

// ---------------------------------------------------------------- contexte partagé (maps legacy -> uuid)
const ctx = { userById: new Map(), userByRepr: new Map(), client: new Map(), article: new Map(), secteur: new Map(), region: new Map() };

const ROLE_BY_PROFILE = { 1: 'COMMERCIAL', 2: 'ADMIN', 4: 'CHEF_SECTEUR', 5: 'DIRECTION', 6: 'DIRECTEUR_REGIONAL', 7: 'ADV', 8: 'MARKETING', 9: 'CHEF_SECTEUR', 10: 'COMMERCIAL', 11: 'ADV' };
const NIVEAU = { A: 'A', 'A+': 'A', 'A++': 'A', B: 'B', C: 'C', D: 'D', E: 'E', F: 'F', G: 'G' };

async function loadMaps() {
  for (const r of (await pg.query('SELECT id, "codeAs400" c FROM clients')).rows) ctx.client.set(r.c, r.id);
  for (const r of (await pg.query('SELECT id, "codeAs400" c FROM articles')).rows) ctx.article.set(r.c, r.id);
  for (const r of (await pg.query('SELECT id, code FROM secteurs')).rows) ctx.secteur.set(r.code, r.id);
  for (const r of (await pg.query('SELECT id, code FROM regions')).rows) ctx.region.set(r.code, r.id);
  // users : table legacy -> uuid via le login (clé de rapprochement) ; id_repr par le code représentant.
  const pgUsers = new Map((await pg.query('SELECT id, lower(username) u FROM users')).rows.map((r) => [r.u, r.id]));
  for (const u of await q('SELECT id, login, id_repr FROM `user`')) {
    const id = pgUsers.get(String(u.login).toLowerCase());
    if (!id) continue;
    ctx.userById.set(u.id, id);
    if (s(u.id_repr)) ctx.userByRepr.set(s(u.id_repr), id);
  }
}

// ---------------------------------------------------------------- étapes
const steps = {};

/** Régions, secteurs (rattachement par code). */
steps.structure = async () => {
  const st = stat('structure');
  const regions = await q('SELECT * FROM ref_region WHERE deleted = 0');
  st.lus += regions.length;
  await upsert(
    'regions',
    ['id', 'code', 'nom', 'createdAt', 'updatedAt'],
    regions.map((r) => ({ id: uuid5(`region:${r.id_as400}`), code: s(r.id_as400), nom: s(r.libelle) ?? s(r.id_as400), createdAt: ts(r.date_creation) ?? new Date(), updatedAt: ts(r.date_modification) ?? new Date() })),
    ['code'],
  );
  ctx.region.clear();
  for (const r of (await pg.query('SELECT id, code FROM regions')).rows) ctx.region.set(r.code, r.id);
  const regionByLegacyId = new Map(regions.map((r) => [r.id, ctx.region.get(s(r.id_as400))]));

  const secteurs = await q('SELECT * FROM ref_secteur WHERE deleted = 0');
  st.lus += secteurs.length;
  await upsert(
    'secteurs',
    ['id', 'code', 'nom', 'regionId', 'createdAt', 'updatedAt'],
    secteurs.map((r) => ({ id: uuid5(`secteur:${r.id_as400}`), code: s(r.id_as400), nom: s(r.libelle) ?? s(r.id_as400), regionId: regionByLegacyId.get(r.id_region) ?? null, createdAt: ts(r.date_creation) ?? new Date(), updatedAt: ts(r.date_modification) ?? new Date() })),
    ['code'],
  );
  ctx.secteur.clear();
  for (const r of (await pg.query('SELECT id, code FROM secteurs')).rows) ctx.secteur.set(r.code, r.id);
  st.ecrits += regions.length + secteurs.length;
};

/** Utilisateurs : rapprochés par login (AD) ; créés s'ils n'existent pas. */
steps.users = async () => {
  const st = stat('users');
  const legacy = await q('SELECT id, id_profile, login, mail, displayname, name, givenname, poste, secteur, id_repr, actif, deleted, sync FROM `user`');
  st.lus = legacy.length;
  const existing = (await pg.query('SELECT id, lower(username) u, lower(email) e, "idRepr" r FROM users')).rows;
  const byLogin = new Map(existing.map((r) => [r.u, r]));
  const usedEmail = new Set(existing.map((r) => r.e).filter(Boolean));
  const usedRepr = new Set(existing.map((r) => r.r).filter(Boolean));

  const toInsert = [];
  const toFill = [];
  for (const u of legacy) {
    const login = s(u.login)?.toLowerCase();
    if (!login) { skip('users', 'login vide'); continue; }
    const repr = s(u.id_repr);
    const found = byLogin.get(login);
    if (found) {
      if (repr && !found.r && !usedRepr.has(repr)) { usedRepr.add(repr); toFill.push({ id: found.id, repr, poste: s(u.poste) }); }
      continue;
    }
    const mail = s(u.mail)?.toLowerCase();
    const row = {
      id: uuid5(`user:${u.id}`),
      username: login,
      email: mail && !usedEmail.has(mail) ? mail : null,
      displayName: s(u.displayname) || [s(u.givenname), s(u.name)].filter(Boolean).join(' ') || login,
      role: ROLE_BY_PROFILE[u.id_profile] ?? 'COMMERCIAL',
      isActive: !!u.actif && !u.deleted,
      idRepr: repr && !usedRepr.has(repr) ? repr : null,
      poste: s(u.poste),
      secteurId: ctx.secteur.get(s(u.secteur)) ?? null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    if (row.email) usedEmail.add(row.email);
    if (row.idRepr) usedRepr.add(row.idRepr);
    toInsert.push(row);
  }
  await upsert('users', ['id', 'username', 'email', 'displayName', 'role', 'isActive', 'idRepr', 'poste', 'secteurId', 'createdAt', 'updatedAt'], toInsert, ['username']);
  for (const f of toFill) await pg.query('UPDATE users SET "idRepr"=$2, poste=COALESCE(poste,$3) WHERE id=$1', [f.id, f.repr, f.poste]);
  st.ecrits = toInsert.length + toFill.length;
  await loadMaps();

  // Hiérarchie DR -> équipe (ex-table `hierarchie`).
  let h = 0;
  for (const r of await q('SELECT id_dr, id_repr FROM hierarchie')) {
    const dr = ctx.userByRepr.get(s(r.id_dr));
    const m = ctx.userByRepr.get(s(r.id_repr));
    if (dr && m && dr !== m) { await pg.query('UPDATE users SET "directeurId"=$1 WHERE id=$2 AND "directeurId" IS NULL', [dr, m]); h++; } else skip('users', 'hiérarchie non résolue');
  }
  // Secteur géré par un chef de secteur (ex-user_secteur).
  for (const r of await q('SELECT s.id_as400 code, us.id_as400_user uid FROM user_secteur us JOIN ref_secteur s ON s.id = us.id_as400_secteur')) {
    const u = ctx.userById.get(r.uid);
    const sec = ctx.secteur.get(s(r.code));
    if (u && sec) await pg.query('UPDATE secteurs SET "managerId"=$1 WHERE id=$2 AND "managerId" IS NULL', [u, sec]); else skip('users', 'secteur géré non résolu');
  }
  st.hierarchie = h;
};

/** Clients absents du Postgres (l'import AS400 les alimente normalement) + centrales. */
steps.clients = async () => {
  const st = stat('clients');
  await loadMaps();
  const miss = [];
  for await (const rows of batches('ref_client', { where: 'deleted = 0' })) {
    st.lus += rows.length;
    for (const c of rows) {
      const code = s(c.id_as400);
      if (!code) { skip('clients', 'id_as400 vide'); continue; }
      if (ctx.client.has(code)) continue;
      miss.push({
        id: uuid5(`client:${code}`), codeAs400: code, enseigne: s(c.enseigne) ?? '', raisonSociale: s(c.raison_sociale) ?? '',
        adresse1: s(c.adresse1), adresse2: s(c.adresse2), adresse3: s(c.adresse3), codePostal: s(c.code_postal), codePostal2: s(c.code_postal_2),
        ville: s(c.ville), pays: s(c.pays), langue: s(c.langue), devise: s(c.devise), siret: s(c.siret), formeEntreprise: s(c.forme_entreprise),
        eanClient: s(c.ean_client), tel1: s(c.tel1), tel2: s(c.tel2), contact1: s(c.contact_1), contact2: s(c.contact_2), contact3: s(c.contact_3),
        idCommercial1: s(c.id_commercial_1), idCommercial2: s(c.id_commercial_2), actif: !!c.actif, niveauClass: NIVEAU[c.niveau_class] ?? null,
        statutCommande: s(c.statut_commande_par), statutLivre: s(c.statut_livre), statutFacture: s(c.statut_facture),
        creeParId: c.id_createur ? ctx.userById.get(c.id_createur) ?? null : null,
        createdAt: ts(c.date_creation) ?? new Date(), updatedAt: ts(c.date_modification) ?? new Date(),
      });
    }
  }
  await upsert('clients', Object.keys(miss[0] ?? { id: 1 }), miss, ['codeAs400']);
  st.ecrits = miss.length;
  await loadMaps();
};

/** Périodicités, contacts, notes terrain. */
steps.satellites = async () => {
  await loadMaps();
  // nomenclature
  const per = await q('SELECT * FROM periodicite WHERE deleted = 0');
  const perMap = new Map();
  await upsert('periodicites', ['id', 'code', 'libelle', 'actif'], per.map((p) => { const id = uuid5(`periodicite:${p.id}`); perMap.set(p.id, id); return { id, code: p.id, libelle: s(p.libelle) ?? String(p.id), actif: true }; }), ['code']);
  for (const r of (await pg.query('SELECT id, code FROM periodicites')).rows) perMap.set(r.code, r.id);

  let st = stat('periodicites');
  const cp = [];
  for (const r of await q('SELECT * FROM ref_client_periodicite WHERE deleted = 0')) {
    st.lus++;
    const client = ctx.client.get(s(r.id_client_as400));
    const p = perMap.get(r.id_periodicite);
    if (!client || !p) { skip('periodicites', !client ? 'client introuvable' : 'périodicité introuvable'); continue; }
    cp.push({ id: uuid5(`clientper:${r.id}`), clientId: client, periodiciteId: p, affecteParId: ctx.userById.get(r.id_user) ?? null, createdAt: ts(r.date_creation) ?? new Date(), updatedAt: ts(r.date_modification) ?? new Date() });
  }
  await upsert('client_periodicites', ['id', 'clientId', 'periodiciteId', 'affecteParId', 'createdAt', 'updatedAt'], cp);
  st.ecrits = cp.length;

  st = stat('contacts');
  const ct = [];
  for (const r of await q('SELECT * FROM ref_client_contact WHERE deleted = 0')) {
    st.lus++;
    const client = ctx.client.get(s(r.id_ref_client));
    if (!client) { skip('contacts', 'client introuvable'); continue; }
    ct.push({ id: uuid5(`contact:${r.id}`), clientId: client, prenom: s(r.prenom), nom: s(r.nom) ?? '(sans nom)', poste: s(r.poste), typePoste: s(r.type_poste), fixe: s(r.fixe), portable: s(r.portable), mail: s(r.mail), creeParId: ctx.userById.get(r.id_user) ?? null, createdAt: new Date(), updatedAt: new Date() });
  }
  await upsert('client_contacts', ['id', 'clientId', 'prenom', 'nom', 'poste', 'typePoste', 'fixe', 'portable', 'mail', 'creeParId', 'createdAt', 'updatedAt'], ct);
  st.ecrits = ct.length;

  st = stat('notes');
  const nt = [];
  for (const r of await q('SELECT * FROM ref_client_remarque WHERE deleted = 0')) {
    st.lus++;
    const client = ctx.client.get(s(r.id_as400));
    if (!client || !s(r.remarque)) { skip('notes', !client ? 'client introuvable' : 'remarque vide'); continue; }
    nt.push({ id: uuid5(`note:${r.id}`), clientId: client, remarque: s(r.remarque), idApk: null, auteurId: ctx.userById.get(r.id_repr) ?? null, createdAt: ts(r.date_creation) ?? new Date(), updatedAt: ts(r.date_modification) ?? new Date() });
  }
  await upsert('client_notes', ['id', 'clientId', 'remarque', 'idApk', 'auteurId', 'createdAt', 'updatedAt'], nt);
  st.ecrits = nt.length;
};

/** Visites + DN, photos (métadonnées), étapes, promos vues. */
steps.visites = async () => {
  await loadMaps();
  const st = stat('visites');
  const visiteId = (id) => uuid5(`visite:${id}`);
  const seenApk = new Set();
  const linked = []; // [id legacy, id_visite_linked]
  const apkToId = new Map();
  for await (const rows of batches('visite')) {
    st.lus += rows.length;
    const out = [];
    for (const v of rows) {
      const promoteur = ctx.userById.get(v.id_user);
      const client = ctx.client.get(s(v.id_client));
      if (!promoteur || !client) { skip('visites', !promoteur ? 'promoteur introuvable' : 'client introuvable'); continue; }
      const apk = s(v.id_visite);
      const idApk = apk && !seenApk.has(apk) ? apk : null;
      if (idApk) { seenApk.add(idApk); apkToId.set(idApk, visiteId(v.id)); }
      if (s(v.id_visite_linked)) linked.push([visiteId(v.id), s(v.id_visite_linked)]);
      out.push({
        id: visiteId(v.id), promoteurId: promoteur, clientId: client, idApk, pmcEtat: v.pmc_state ? String(v.pmc_state) : null, pmcCommentaire: s(v.pmc_coms),
        dnAbc: int(v.dn_abc), dnConcurrence: int(v.dn_concurence), pem: !!v.pem, queueDate: ts(s(v.queue_date)), alerteRaison: s(v.alerte_raison), alerteObs: s(v.alerte_obs),
        createdAt: ts(v.date_creation) ?? new Date(), updatedAt: ts(v.date_modification) ?? ts(v.date_creation) ?? new Date(), deletedAt: v.deleted ? ts(v.date_modification) ?? new Date() : null,
      });
    }
    await upsert('visites', Object.keys(out[0] ?? { id: 1 }), out);
    st.ecrits += out.length;
  }
  for (const [id, apk] of linked) {
    const target = apkToId.get(apk);
    if (target) await pg.query('UPDATE visites SET "visiteLieeId"=$2 WHERE id=$1', [id, target]); else skip('visites', 'visite liée introuvable');
  }
  const ok = new Set((await pg.query('SELECT id FROM visites')).rows.map((r) => r.id));

  let c = stat('visite_dns');
  for await (const rows of batches('visite_dn', { where: 'deleted = 0' })) {
    c.lus += rows.length;
    const out = [];
    for (const r of rows) {
      const vid = visiteId(r.id_visite);
      if (!ok.has(vid)) { skip('visite_dns', 'visite introuvable'); continue; }
      out.push({ id: uuid5(`visitedn:${r.id}`), visiteId: vid, type: String(r.type).toUpperCase() === 'ABC' ? 'ABC' : 'CONCURRENCE', marque: s(r.marque), gamme: s(r.gamme), metrage: Number.isFinite(parseFloat(r.metrage)) ? parseFloat(r.metrage) : null, createdAt: ts(r.date_creation) ?? new Date() });
    }
    await upsert('visite_dns', ['id', 'visiteId', 'type', 'marque', 'gamme', 'metrage', 'createdAt'], out);
    c.ecrits += out.length;
  }
  // Règle de conservation : photos de visite gardées 3 ans maximum (les plus anciennes ne sont pas reprises).
  c = stat('visite_photos');
  for await (const rows of batches('visite_photo', { where: 'date_creation >= NOW() - INTERVAL 3 YEAR' })) {
    c.lus += rows.length;
    const out = [];
    for (const r of rows) {
      const vid = visiteId(r.id_visite);
      if (!ok.has(vid) || !s(r.file)) { skip('visite_photos', !ok.has(vid) ? 'visite introuvable' : 'fichier vide'); continue; }
      out.push({ id: uuid5(`visitephoto:${r.id}`), visiteId: vid, fichier: s(r.file), taille: r.size ?? null, idVisiteApk: s(r.id_visite_apk), appName: s(r.app_name), createdAt: ts(r.date_creation) ?? new Date() });
    }
    await upsert('visite_photos', ['id', 'visiteId', 'fichier', 'taille', 'idVisiteApk', 'appName', 'createdAt'], out);
    c.ecrits += out.length;
  }
  c = stat('visite_steps');
  for await (const rows of batches('visite_step')) {
    c.lus += rows.length;
    const out = [];
    for (const r of rows) {
      const vid = visiteId(r.id_visite);
      if (!ok.has(vid)) { skip('visite_steps', 'visite introuvable'); continue; }
      out.push({ id: uuid5(`visitestep:${r.id}`), visiteId: vid, etape: r.step_nb === null ? null : String(r.step_nb), horodatage: ts(s(r.date_step)), createdAt: new Date() });
    }
    await upsert('visite_steps', ['id', 'visiteId', 'etape', 'horodatage', 'createdAt'], out);
    c.ecrits += out.length;
  }
  c = stat('visite_promos');
  for await (const rows of batches('visite_promo')) {
    c.lus += rows.length;
    const out = [];
    for (const r of rows) {
      const vid = visiteId(r.id_visite);
      if (!ok.has(vid)) { skip('visite_promos', 'visite introuvable'); continue; }
      out.push({ id: uuid5(`visitepromo:${r.id}`), visiteId: vid, articleId: ctx.article.get(s(r.id_as400)) ?? null, createdAt: new Date() });
    }
    await upsert('visite_promos', ['id', 'visiteId', 'articleId', 'createdAt'], out);
    c.ecrits += out.length;
  }
};

/** Récurrences (plannification), occurrences (planning), tournées types. */
steps.planning = async () => {
  await loadMaps();
  const isoMonday = (annee, week) => {
    const d = new Date(Date.UTC(annee, 0, 4));
    d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7) + (week - 1) * 7);
    return d.toISOString().slice(0, 10);
  };
  let st = stat('plannifications');
  const planByUnique = new Map();
  const pl = [];
  for (const r of await q('SELECT * FROM plannification')) {
    st.lus++;
    const promoteur = ctx.userByRepr.get(s(r.id_repr));
    const client = ctx.client.get(s(r.id_client));
    if (!promoteur || !client) { skip('plannifications', !promoteur ? 'promoteur introuvable' : 'client introuvable'); continue; }
    const id = uuid5(`plannification:${r.unique_id || r.id}`);
    planByUnique.set(s(r.unique_id), id);
    const debut = r.annee && r.start ? isoMonday(r.annee, r.start) : String(r.date_creation).slice(0, 10);
    pl.push({ id, promoteurId: promoteur, clientId: client, jours: s(r.days) ?? '', recurrence: r.rec || 1, dateDebut: debut, dateFin: null, createdAt: ts(r.date_creation) ?? new Date(), updatedAt: ts(r.date_modification) ?? new Date(), deletedAt: r.deleted ? ts(r.date_modification) ?? new Date() : null });
  }
  await upsert('plannifications', ['id', 'promoteurId', 'clientId', 'jours', 'recurrence', 'dateDebut', 'dateFin', 'createdAt', 'updatedAt', 'deletedAt'], pl);
  st.ecrits = pl.length;

  st = stat('plannings');
  for await (const rows of batches('planning')) {
    st.lus += rows.length;
    const out = [];
    for (const r of rows) {
      // planning.id_repr = user.id (SCHEMA_BDD §2.3), mais certaines lignes portent le code représentant : repli.
      const promoteur = ctx.userById.get(r.id_repr) ?? ctx.userByRepr.get(String(r.id_repr));
      const client = ctx.client.get(s(r.id_magasin));
      if (!promoteur || !client) { skip('plannings', !promoteur ? 'promoteur introuvable' : 'client introuvable'); continue; }
      out.push({ id: uuid5(`planning:${r.id}`), promoteurId: promoteur, clientId: client, datePassage: ts(r.date_passage), fait: !!r.green, raison: s(r.raison), plannificationId: planByUnique.get(s(r.id_plannification)) ?? null, createdAt: ts(r.date_creation) ?? new Date(), updatedAt: ts(r.date_modification) ?? new Date(), deletedAt: r.deleted ? ts(r.date_modification) ?? new Date() : null });
    }
    await upsert('plannings', Object.keys(out[0] ?? { id: 1 }), out);
    st.ecrits += out.length;
  }

  st = stat('tournees');
  for await (const rows of batches('tournee')) {
    st.lus += rows.length;
    const out = [];
    for (const r of rows) {
      const promoteur = ctx.userById.get(r.id_repr) ?? ctx.userByRepr.get(String(r.id_repr));
      const client = ctx.client.get(s(r.id_as400));
      if (!promoteur || !client) { skip('tournees', !promoteur ? 'promoteur introuvable' : 'client introuvable'); continue; }
      out.push({ id: uuid5(`tournee:${r.id}`), promoteurId: promoteur, clientId: client, jours: s(r.days), semaines: r.weeks === null ? null : String(r.weeks), semaineDebut: r.start ?? null, annee: r.annee ?? null, createdAt: ts(r.date_creation) ?? new Date(), updatedAt: ts(r.date_modification) ?? new Date(), deletedAt: r.deleted ? ts(r.date_modification) ?? new Date() : null });
    }
    await upsert('tournees', Object.keys(out[0] ?? { id: 1 }), out);
    st.ecrits += out.length;
  }
};

/**
 * Commandes saisies sur l'app mobile (commande_apk + commande_apk_produits).
 * - idCommandeApk = commande_apk.id (≤ 10 car.) : c'est la valeur que commandes_as400.id_commande_apk
 *   référence (le vrai id_apk legacy fait jusqu'à 24 car. et ne rentre pas dans la colonne).
 * - Le champ legacy `user` est le login ; id_produit est le code article (id_as400).
 */
steps.commandes_apk = async () => {
  await loadMaps();
  const st = stat('commandes_apk');
  const byLogin = new Map((await pg.query('SELECT id, lower(username) u FROM users')).rows.map((r) => [r.u, r.id]));
  const cmdId = (id) => uuid5(`commandeapk:${id}`);
  const ok = new Set();
  for await (const rows of batches('commande_apk', { where: 'deleted = 0' })) {
    st.lus += rows.length;
    const out = [];
    for (const r of rows) {
      const promoteur = byLogin.get(String(r.user).toLowerCase());
      const client = ctx.client.get(s(r.id_magasin));
      if (!promoteur || !client) { skip('commandes_apk', !promoteur ? 'promoteur introuvable' : 'client introuvable'); continue; }
      ok.add(r.id);
      out.push({ id: cmdId(r.id), idCommandeApk: String(r.id), promoteurId: promoteur, clientId: client, commentaire: s(r.remarque), dateCommande: ts(s(r.date_creation_apk)) ?? ts(r.date_creation) ?? new Date(), createdAt: ts(r.date_creation) ?? new Date(), updatedAt: ts(r.date_modification) ?? ts(r.date_creation) ?? new Date() });
    }
    await upsert('commandes_apk', ['id', 'idCommandeApk', 'promoteurId', 'clientId', 'commentaire', 'dateCommande', 'createdAt', 'updatedAt'], out, ['idCommandeApk']);
    st.ecrits += out.length;
  }
  // l'upsert est sur idCommandeApk : relire les ids réellement en base pour les lignes
  const idByApk = new Map((await pg.query('SELECT "idCommandeApk" k, id FROM commandes_apk')).rows.map((r) => [r.k, r.id]));
  const c = stat('commande_apk_lignes');
  const ordre = new Map();
  for await (const rows of batches('commande_apk_produits')) {
    c.lus += rows.length;
    const out = [];
    for (const r of rows) {
      const cid = ok.has(r.id_commande_apk) ? idByApk.get(String(r.id_commande_apk)) : null;
      const article = ctx.article.get(s(r.id_produit));
      if (!cid || !article) { skip('commande_apk_lignes', !cid ? 'commande introuvable' : 'article introuvable'); continue; }
      const n = (ordre.get(r.id_commande_apk) ?? 0) + 1;
      ordre.set(r.id_commande_apk, n);
      out.push({ id: uuid5(`commandeapkligne:${r.id}`), commandeApkId: cid, ordre: n, articleId: article, quantite: r.quantite ?? 0, prixIndicatif: r.prix_unitaire ?? null });
    }
    await upsert('commande_apk_lignes', ['id', 'commandeApkId', 'ordre', 'articleId', 'quantite', 'prixIndicatif'], out);
    c.ecrits += out.length;
  }
};

/**
 * Historique des commandes ERP (commandes_as400 -> commandes + commande_lignes).
 * - En-tête = une par `numero` ; upsert sur numero SANS toucher au suivi de livraison (géré par l'ADV).
 * - Piège legacy : annee/mois/jour_annul = date de COMMANDE ; l'annulation est dans checky/m/d.
 * - Lien commande mobile : id_commande_apk legacy est zéro-complété ('000128752') -> '128752', comme
 *   commandes_apk.idCommandeApk. (À répercuter dans l'import CDJ pour rester cohérent.)
 * - Client / article introuvables : la commande/ligne est gardée (clientId/articleId null, snapshot ERP conservé).
 */
steps.commandes = async () => {
  await loadMaps();
  const st = stat('commandes');
  const date = (y, m, d) => {
    const yy = int(y), mm = int(m), dd = int(d);
    return yy && yy > 1900 && mm >= 1 && mm <= 12 && dd >= 1 && dd <= 31 ? `${String(yy).padStart(4, '0')}-${String(mm).padStart(2, '0')}-${String(dd).padStart(2, '0')}` : null;
  };
  const apk = (v) => { const t = s(v); return t && /^\d+$/.test(t) && int(t) > 0 ? String(int(t)) : null; };

  const heads = await q(`SELECT a.*, g.ck FROM commandes_as400 a
    JOIN (SELECT numero, MIN(id) mid, MAX(CONCAT(checky, checkm, checkd)) ck FROM commandes_as400 GROUP BY numero) g ON g.mid = a.id`);
  st.lus = heads.length;
  const rows = heads.map((h) => ({
    id: uuid5(`commande:${h.numero}`), numero: s(h.numero), clientId: ctx.client.get(s(h.code_client_cmd)) ?? null,
    raisonSocialeCmd: s(h.raison_sociale_cmd), idRepr: s(h.id_repr), typeCmd: s(h.type_cmd), idCommandeApk: apk(h.id_commande_apk),
    dateCommande: date(h.annee_annul, h.mois_annul, h.jour_annul) ?? ts(h.date_creation),
    dateAnnulation: h.ck && !/^0+$/.test(h.ck) ? date(h.ck.slice(0, 4), h.ck.slice(4, 6), h.ck.slice(6, 8)) : null,
    createdAt: ts(h.date_creation) ?? new Date(), updatedAt: ts(h.date_modification) ?? new Date(),
  }));
  // upsert sur numero : on ne met à jour que les champs ERP (pas statutLivraison & co).
  const cols = Object.keys(rows[0]);
  const idByNumero = new Map();
  const per = Math.floor(60000 / cols.length);
  for (let i = 0; i < rows.length; i += per) {
    const chunk = rows.slice(i, i + per);
    const params = [];
    const values = chunk.map((r) => `(${cols.map((c) => { params.push(r[c] ?? null); return `$${params.length}`; }).join(',')})`).join(',');
    const upd = cols.filter((c) => !['id', 'numero', 'createdAt'].includes(c)).map((c) => `"${c}"=EXCLUDED."${c}"`).join(',');
    const res = await pg.query(`INSERT INTO commandes (${cols.map((c) => `"${c}"`).join(',')}) VALUES ${values} ON CONFLICT (numero) DO UPDATE SET ${upd} RETURNING id, numero`, params);
    for (const r of res.rows) idByNumero.set(r.numero, r.id);
  }
  st.ecrits = rows.length;

  const c = stat('commande_lignes');
  for await (const batch of batches('commandes_as400', { size: 20000 })) {
    c.lus += batch.length;
    const out = [];
    for (const r of batch) {
      const cid = idByNumero.get(s(r.numero));
      if (!cid) { skip('commande_lignes', 'commande introuvable'); continue; }
      const no = String(int(r.no_ligne) ?? s(r.no_ligne) ?? '0');
      out.push({ id: uuid5(`commandeligne:${r.numero}:${no}`), commandeId: cid, noLigne: no, articleId: ctx.article.get(s(r.code_article)) ?? null, libelleArticle: s(r.libelle_article), quantite: r.quantite ?? 0, montant: r.montant ?? 0, createdAt: ts(r.date_creation) ?? new Date(), updatedAt: ts(r.date_modification) ?? new Date() });
    }
    await upsert('commande_lignes', ['id', 'commandeId', 'noLigne', 'articleId', 'libelleArticle', 'quantite', 'montant', 'createdAt', 'updatedAt'], out, ['commandeId', 'noLigne']);
    c.ecrits += out.length;
  }
};

// ---------------------------------------------------------------- main
async function main() {
  const wanted = process.argv.slice(2);
  if (wanted.includes('--list')) return console.log(Object.keys(steps).join('\n'));
  const run = wanted.length ? wanted : Object.keys(steps);
  for (const n of run) if (!steps[n]) throw new Error(`étape inconnue : ${n} (disponibles : ${Object.keys(steps).join(', ')})`);

  my = await mysql.createConnection({
    host: env.MIGRATION_SRC_HOST ?? '127.0.0.1', port: Number(env.MIGRATION_SRC_PORT ?? 3307), user: 'root',
    password: env.MYSQL_STAGING_ROOT_PASSWORD, database: env.MYSQL_STAGING_DATABASE, dateStrings: true, charset: 'UTF8MB4_GENERAL_CI',
  });
  pg = new PgClient({ host: env.MIGRATION_DST_HOST ?? '127.0.0.1', port: Number(env.MIGRATION_DST_PORT ?? 5432), user: 'crm', password: env.POSTGRES_PASSWORD, database: 'crm' });
  await pg.connect();
  await loadMaps();
  for (const n of run) {
    const t0 = Date.now();
    console.log(`== ${n}`);
    await steps[n]();
    console.log(`   ${((Date.now() - t0) / 1000).toFixed(1)} s`);
  }
  console.log('\n=== Rapport ===');
  console.log(JSON.stringify(report, null, 2));
  await my.end();
  await pg.end();
}
main().catch((e) => { console.error(e); process.exit(1); });
