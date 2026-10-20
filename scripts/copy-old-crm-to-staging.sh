#!/usr/bin/env bash
# Copie exacte de l'ancien CRM (MySQL "gescom", PROD, lecture seule) vers le MySQL de staging.
# - Source : OLD_CRM_MYSQL_* (compte crm_ro, SELECT uniquement : aucune écriture côté prod).
# - Cible  : service db-mysql-staging (127.0.0.1:3307), base MYSQL_STAGING_DATABASE (RECRÉÉE à chaque run).
# - Table `user` : colonnes token / token_expires non lisibles par crm_ro -> structure complète,
#   données copiées sans ces deux colonnes (elles restent NULL).
# Exclue : la table de sauvegarde `TABLE 129_sauvegarde_20261016` (inutile en staging).
# Planifié chaque jour à 19h (cron de admininfo) ; un verrou empêche deux copies simultanées.
# Usage : ./scripts/copy-old-crm-to-staging.sh
set -euo pipefail
cd "$(dirname "$0")/.."
exec 9>/tmp/copy-old-crm.lock
flock -n 9 || { echo "copie déjà en cours, abandon"; exit 0; }
set -a; . ./.env; set +a

export SRC_HOST=$OLD_CRM_MYSQL_HOST SRC_PORT=$OLD_CRM_MYSQL_PORT SRC_DB=$OLD_CRM_MYSQL_DATABASE
export DST_DB=$MYSQL_STAGING_DATABASE
[ "$DST_DB" != "$SRC_DB" ] || { echo "cible = source, abandon"; exit 1; }

docker compose up -d --wait db-mysql-staging

docker run --rm --network host \
  -e SRC_PWD="$OLD_CRM_MYSQL_PASSWORD" -e DST_PWD="$MYSQL_STAGING_ROOT_PASSWORD" \
  -e SRC_HOST -e SRC_PORT -e SRC_USER="$OLD_CRM_MYSQL_USER" -e SRC_DB -e DST_DB \
  mysql:8 bash -euo pipefail -c '
src() { MYSQL_PWD=$SRC_PWD "$@" -h "$SRC_HOST" -P "$SRC_PORT" -u "$SRC_USER"; }
dst() { MYSQL_PWD=$DST_PWD "$@" -h 127.0.0.1 -P 3307 -u root; }

echo "== recréation de $DST_DB"
dst mysql -e "DROP DATABASE IF EXISTS \`$DST_DB\`; CREATE DATABASE \`$DST_DB\` CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci"

echo "== copie des tables (hors données de user)"
src mysqldump --single-transaction --no-tablespaces --skip-lock-tables --set-gtid-purged=OFF \
  --column-statistics=0 --ignore-table="$SRC_DB.user" --ignore-table="$SRC_DB.TABLE 129_sauvegarde_20261016" "$SRC_DB" \
  | dst mysql "$DST_DB"

echo "== table user (structure + données sans token)"
src mysqldump --no-data --no-tablespaces --skip-lock-tables --column-statistics=0 "$SRC_DB" user | dst mysql "$DST_DB"
COLS=$(src mysql -N -B information_schema -e "SELECT GROUP_CONCAT(CONCAT(\"\`\",column_name,\"\`\") ORDER BY ordinal_position) FROM columns WHERE table_schema=\"$SRC_DB\" AND table_name=\"user\" AND column_name NOT IN (\"token\",\"token_expires\")")
src mysql --default-character-set=utf8mb3 -N -B "$SRC_DB" -e "SELECT $COLS FROM user" > /tmp/user.tsv
dst mysql -e "SET GLOBAL local_infile=1"
dst mysql --local-infile=1 "$DST_DB" -e "LOAD DATA LOCAL INFILE \"/tmp/user.tsv\" INTO TABLE user CHARACTER SET utf8mb3 ($COLS)"

echo "== terminé"
'
