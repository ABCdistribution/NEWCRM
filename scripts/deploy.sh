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
OLD=$(git rev-parse HEAD)
NEW=$(git rev-parse origin/main)
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || { log "branche courante != main, abandon"; exit 1; }
if [ "$OLD" = "$NEW" ] && [ -z "${FORCE:-}" ]; then exit 0; fi
git diff --quiet HEAD -- || { log "modifications locales non commitées sur des fichiers suivis, abandon"; exit 1; }

log "Déploiement ${OLD:0:7} -> ${NEW:0:7}"
FICHIERS=$(git diff --name-only "$OLD" "$NEW")
RANGE_CHANGED() { [ -n "${FORCE:-}" ] || grep -qE "$1" <<< "$FICHIERS"; }
git merge --ff-only -q origin/main

set -a; . ./.env; set +a
DEPLOY_API=0; DEPLOY_PILOT=0; DEPLOY_SALES=0
RANGE_CHANGED '^(crm-api/|packages/|pnpm-lock.yaml|docker-compose.yml)' && DEPLOY_API=1
RANGE_CHANGED '^(crm-helios/|packages/)' && DEPLOY_PILOT=1
RANGE_CHANGED '^(crm-promoteur/|packages/)' && DEPLOY_SALES=1

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
  local dir=$1 port=$2 pid
  log "Build $dir"
  (cd "$dir" && pnpm install --frozen-lockfile --ignore-workspace --silent && pnpm exec next build)
  pid=$(port_pid "$port" || true)
  [ -n "$pid" ] && { kill "$pid" 2>/dev/null || true; sleep 2; }
  # pnpm parent éventuel
  (cd "$dir" && RUNNER_TRACKING_ID= setsid nohup pnpm exec next start -p "$port" >> "$LOGS/$(basename "$dir").log" 2>&1 < /dev/null 9>&- &)
  for _ in $(seq 1 30); do curl -s -o /dev/null "http://localhost:$port/" && { log "$dir OK (:$port)"; return; }; sleep 1; done
  log "$dir ne répond pas sur :$port"; return 1
}

if [ $DEPLOY_API = 1 ]; then
  log "Build + redémarrage API"
  pnpm install --frozen-lockfile --silent
  docker compose up -d --build api
  for _ in $(seq 1 40); do curl -sf -o /dev/null http://localhost:4000/health && { log "API OK"; break; }; sleep 2; done
  curl -sf -o /dev/null http://localhost:4000/health || { log "API ne répond pas sur /health"; exit 1; }
fi
[ $DEPLOY_PILOT = 1 ] && restart_next /var/www/crm-helios 3001
[ $DEPLOY_SALES = 1 ] && restart_next /var/www/crm-promoteur 3002
log "Déploiement terminé (${NEW:0:7})"
