#!/usr/bin/env bash
# Copie les photos de visite de l'ancien CRM (srvfr-gescom) vers ce serveur — LECTURE SEULE côté source.
#   /home/datas/gescom/visites/<magasin>/<année>/<fichier>.jpg  ->  $PHOTOS_DEST/<magasin>/<année>/...
# Reprenable (rsync --partial) : relancer le script reprend où il s'est arrêté.
# Usage : ./scripts/copy-photos-visites.sh 2026 [2025 ...]      (BWLIMIT en Ko/s, défaut 20000)
set -euo pipefail
cd "$(dirname "$0")/.."
[ $# -ge 1 ] || { echo "usage: $0 <année> [<année> ...]"; exit 1; }
exec 9>/tmp/copy-photos-visites.lock
flock -n 9 || { echo "copie déjà en cours"; exit 0; }
set -a; . ./.env; set +a

DEST=${PHOTOS_DEST:-/var/www/data/photos-visites}
mkdir -p "$DEST"
export SSH_ASKPASS="$PWD/scripts/ssh-askpass-old-crm.sh" SSH_ASKPASS_REQUIRE=force DISPLAY=none
HOTE=${OLD_CRM_SSH##*@}

for an in "$@"; do
  [[ "$an" =~ ^20[0-9]{2}$ ]] || { echo "année invalide : $an"; exit 1; }
  echo "== $(date '+%F %T') année $an"
  setsid -w rsync -a --partial --prune-empty-dirs --info=stats2,progress2 --bwlimit="${BWLIMIT:-20000}" \
    -e "ssh -o PubkeyAuthentication=no -o ConnectTimeout=20 -o ServerAliveInterval=30" \
    --include='*/' --include="*/$an/***" --exclude='*' \
    "$OLD_CRM_SSH_USER@$HOTE:/home/datas/gescom/visites/" "$DEST/" < /dev/null
done
echo "== $(date '+%F %T') terminé"
