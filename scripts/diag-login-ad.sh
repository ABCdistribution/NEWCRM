#!/usr/bin/env bash
# Diagnostic de connexion AD : rejoue exactement ce que fait l'API (recherche du compte puis bind avec le mot de passe)
# et affiche la cause précise du refus. Le mot de passe est saisi au clavier (non affiché), jamais écrit ni journalisé.
# Usage : ./scripts/diag-login-ad.sh <identifiant tel que tapé sur la page de connexion>
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# -eq 1 ] || { echo "usage: $0 <identifiant>"; exit 1; }
read -rsp "Mot de passe AD (non affiché) : " PW; echo
docker compose exec -T -e DIAG_USER="$1" -e DIAG_PW="$PW" api sh -c 'cd /app/crm-api && node -e "
const { Client } = require(\"ldapts\");
const esc = (s) => s.replace(/[\\\\*()\\0]/g, (c) => \"\\\\\" + c.charCodeAt(0).toString(16).padStart(2, \"0\"));
(async () => {
  const user = process.env.DIAG_USER, pw = process.env.DIAG_PW;
  const s = new Client({ url: process.env.LDAP_URL, timeout: 8000, connectTimeout: 8000 });
  await s.bind(process.env.LDAP_BIND_DN, process.env.LDAP_BIND_PASSWORD);
  const { searchEntries } = await s.search(process.env.LDAP_SEARCH_BASE, { scope: \"sub\", filter: \"(sAMAccountName=\" + esc(user) + \")\", attributes: [\"sAMAccountName\"] });
  await s.unbind();
  if (!searchEntries.length) { console.log(\"1) Recherche : AUCUN compte avec sAMAccountName =\", JSON.stringify(user), \"-> l identifiant tape n est pas le bon format\"); return; }
  console.log(\"1) Recherche : compte trouve ->\", searchEntries[0].dn);
  const u = new Client({ url: process.env.LDAP_URL, timeout: 8000, connectTimeout: 8000 });
  try { await u.bind(searchEntries[0].dn, pw); console.log(\"2) Bind avec ce mot de passe : OK -> les identifiants sont valides pour l AD\"); }
  catch (e) { console.log(\"2) Bind avec ce mot de passe : ECHEC ->\", e.name, \"|\", String(e.message).slice(0, 200)); }
  finally { await u.unbind().catch(() => {}); }
  // 3) Appel réel de la route de connexion de l API (ce que fait la page de connexion).
  const r = await fetch(\"http://localhost:\" + (process.env.PORT || 4000) + \"/auth/login\", { method: \"POST\", headers: { \"Content-Type\": \"application/json\" }, body: JSON.stringify({ username: user, password: pw }) });
  const t = await r.text(); let b; try { b = JSON.parse(t); } catch { b = t.slice(0, 200); }
  if (b && b.accessToken) { b = { accessToken: \"(jeton recu, masque)\", user: b.user && { username: b.user.username, role: b.user.role } }; }
  console.log(\"3) Route /auth/login de l API : HTTP\", r.status, \"->\", JSON.stringify(b));
})().catch((e) => console.log(\"ERREUR\", e.message))"'
unset PW
