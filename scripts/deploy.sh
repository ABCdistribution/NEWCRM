#!/usr/bin/env bash
# Déploiement automatique : si origin/main a avancé, met à jour et redémarre ce qui a changé.
#   cron : */3 * * * * /var/www/scripts/deploy.sh >> /home/admininfo/logs/deploy.log 2>&1
#   FORCE=1 ./scripts/deploy.sh   → redéploie tout même sans nouveau commit
set -Eeuo pipefail
cd /var/www
LOGS=/home/admininfo/logs
mkdir -p "$LOGS"
exec 9>"${LOCK:-/tmp/crm-deploy.lock}"
flock -n 9 || { log_busy=1; exit 0; }   # un déploiement à la fois

log() { echo "[$(date '+%F %T')] $*"; }
trap 'log "ÉCHEC du déploiement (ligne $LINENO) — services non redémarrés au-delà de cette étape"' ERR

git fetch -q origin main
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || { log "branche courante != main, abandon"; exit 1; }
git diff --quiet HEAD -- || { log "modifications locales non commitées sur des fichiers suivis, abandon"; exit 1; }
git merge --ff-only -q origin/main 2>/dev/null || true   # tolère un HEAD local en avance sur origin
NEW=$(git rev-parse HEAD)
# Dernier commit réellement DÉPLOYÉ (et non le HEAD local : un `git pull` manuel ne doit pas masquer un déploiement).
MARQUEUR=/var/www/.deployed-sha
OLD=$(cat "$MARQUEUR" 2>/dev/null || true)
if [ -z "$OLD" ] || ! git cat-file -e "$OLD^{commit}" 2>/dev/null; then OLD=$NEW; FORCE=${FORCE:-1}; fi   # historique inconnu/réécrit → tout redéployer
if [ "$OLD" = "$NEW" ] && [ -z "${FORCE:-}" ]; then exit 0; fi

log "Déploiement ${OLD:0:7} -> ${NEW:0:7}"
FICHIERS=$(git diff --name-only "$OLD" "$NEW")
RANGE_CHANGED() { [ -n "${FORCE:-}" ] || grep -qE "$1" <<< "$FICHIERS"; }

set -a; . ./.env; set +a
DEPLOY_API=0; DEPLOY_WEB=0
RANGE_CHANGED '^(crm-api/|packages/|pnpm-lock.yaml|docker-compose.yml)' && DEPLOY_API=1
# crm-web = front unique, qui remplace ABC Pilot (ex-crm-helios) et ABC Sales (ex-crm-promoteur), supprimés le 2026-11-10.
RANGE_CHANGED '^(crm-web/|packages/)' && DEPLOY_WEB=1

# --- Migrations : on refuse les migrations destructrices non validées ---
if RANGE_CHANGED '^packages/database/prisma/migrations/'; then
  NOUVELLES=$(git diff --name-only --diff-filter=A "$OLD" "$NEW" -- 'packages/database/prisma/migrations/*/migration.sql' || true)
  if [ -n "$NOUVELLES" ] && [ ! -f /var/www/.deploy-allow-destructive ] \
     && grep -HniE 'DROP (TABLE|COLUMN|SCHEMA)|TRUNCATE|DELETE FROM' $NOUVELLES; then
    log "Migration destructrice détectée (ci-dessus). Relire puis: touch /var/www/.deploy-allow-destructive"
    exit 1
  fi
  log "Migrations (prisma migrate deploy)"
  (cd packages/database && DATABASE_URL="postgresql://crm:${POSTGRES_PASSWORD}@127.0.0.1:5432/crm?schema=public" npx --yes prisma migrate deploy)
fi

port_pid() { ss -tlnpH "sport = :$1" | grep -oP 'pid=\K[0-9]+' | head -1; }
restart_next() { # dossier port
  local dir=$1 port=$2 pid cs
  log "Build $dir"
  (cd "$dir" && pnpm install --frozen-lockfile --ignore-workspace --silent && pnpm exec next build)
  pid=$(port_pid "$port" || true)
  if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null || true
    # Attend (15 s max) que l'ancien processus libère le port : sinon le nouveau échoue en EADDRINUSE.
    for _ in $(seq 1 15); do [ -n "$(port_pid "$port" || true)" ] || break; sleep 1; done
  fi
  # pnpm parent éventuel
  # Prod servie en HTTP interne : sans COOKIE_SECURE=false, crm-web (cookie « secure » par défaut en production) perd la session.
  # crm-web ne reconnaît que true/false ; les anciens fronts traitaient toute autre valeur comme « non sécurisé » : on normalise
  # (casse et espaces ignorés) et toute autre valeur donne false, avec une ligne de journal. À passer à true dans /var/www/.env
  # dès que HTTPS est en place (docs/BACKLOG.md, 1.11). TZ : requis en production (CLAUDE.md).
  cs=$(printf '%s' "${COOKIE_SECURE:-}" | tr -d '[:space:]' | tr 'A-Z' 'a-z')
  case "$cs" in
    true|false) ;;
    '') log "COOKIE_SECURE non défini : false (prod en HTTP interne) ; définir true dans /var/www/.env dès que HTTPS est en place"; cs=false ;;
    *) log "COOKIE_SECURE « ${COOKIE_SECURE} » non reconnu (attendu true ou false) : false appliqué"; cs=false ;;
  esac
  (exec 9>&-; cd "$dir" && RUNNER_TRACKING_ID= TZ=Europe/Paris COOKIE_SECURE="$cs" setsid nohup pnpm exec next start -p "$port" >> "$LOGS/$(basename "$dir").log" 2>&1 < /dev/null &)
  # OK seulement si ça répond ET si le port n'est plus tenu par l'ancien processus (sinon faux « OK » sur l'ancien front).
  for _ in $(seq 1 30); do
    curl -sf -o /dev/null "http://localhost:$port/" && { [ -z "$pid" ] || [ "$(port_pid "$port" || true)" != "$pid" ]; } && { log "$dir OK (:$port)"; return; }
    sleep 1
  done
  log "$dir ne répond pas sur :$port"; return 1
}

if [ $DEPLOY_API = 1 ]; then
  log "Build + redémarrage API"
  pnpm install --frozen-lockfile --silent
  docker compose up -d --build api
  for _ in $(seq 1 40); do curl -sf -o /dev/null http://localhost:4000/health && { log "API OK"; break; }; sleep 2; done
  curl -sf -o /dev/null http://localhost:4000/health || { log "API ne répond pas sur /health"; exit 1; }
fi
# crm-web reprend le port 3001 (ex-ABC Pilot) : restart_next tue l'ancien processus qui l'occupe.
# L'ancien ABC Sales (3002) n'est PAS arrêté ici : à faire à la main au basculement du reverse proxy (docs/BACKLOG.md).
[ $DEPLOY_WEB = 1 ] && restart_next /var/www/crm-web 3001
echo "$NEW" > "$MARQUEUR"
log "Déploiement terminé (${NEW:0:7})"
