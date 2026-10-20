#!/usr/bin/env bash
# Récupère les fichiers CLI_* / ART_* / ARB_* déposés par l'AS400 (10.3) dans un dossier local.
# - Copie seulement (aucune suppression, aucune écriture sur l'AS400).
# - Pas de montage permanent : une connexion SMB 1.0 courte, puis déconnexion.
# - Un fichier n'apparaît dans le dossier de dépôt qu'une fois entièrement copié (.part puis renommage).
# - Ne recopie pas un fichier déjà présent dans le dépôt ou dans traites/.
#
# Config (variables d'environnement, valeurs par défaut = TEST) :
#   AS400_SMB_HOST   192.168.10.3
#   AS400_SMB_SHARE  TESTMINACRM          (prod : MINACRM — à ne brancher qu'après validation)
#   AS400_SMB_CRED   ~/.crm-as400.cred    (username= / password= / domain=, droits 600)
#   AS400_DEPOT      /var/www/imports/depot-test
#   AS400_TRAITES    /var/www/imports/traites
# Planifié par cron (toutes les 5 minutes). Journal : ~/logs/sync-as400.log
set -euo pipefail

HOST=${AS400_SMB_HOST:-192.168.10.3}
SHARE=${AS400_SMB_SHARE:-TESTMINACRM}
CRED=${AS400_SMB_CRED:-$HOME/.crm-as400.cred}
DEPOT=${AS400_DEPOT:-/var/www/imports/depot-test}
TRAITES=${AS400_TRAITES:-/var/www/imports/traites}

exec 9>/tmp/sync-as400.lock
flock -n 9 || exit 0

[ -r "$CRED" ] || { echo "$(date '+%F %T') ERREUR fichier d'identifiants introuvable : $CRED" >&2; exit 1; }
[ "$(stat -c %a "$CRED")" = "600" ] || { echo "$(date '+%F %T') ERREUR droits de $CRED : 600 attendu" >&2; exit 1; }
mkdir -p "$DEPOT" "$TRAITES"

# L'AS400 ne parle que SMB 1.0 avec l'ancienne authentification (comme le montage historique).
SMB=(smbclient "//$HOST/$SHARE" -A "$CRED" -m NT1
  --option='client min protocol=NT1' --option='client use spnego=no'
  --option='client ntlmv2 auth=no' --option='client lanman auth=yes')

LISTE=$(timeout 120 "${SMB[@]}" -c 'ls' 2>&1 | grep -v deprecated) || true
if ! grep -qE '^  \.  ' <<<"$LISTE"; then
  echo "$(date '+%F %T') ERREUR liste du partage $SHARE impossible : $(head -2 <<<"$LISTE" | tr '\n' ' ')" >&2
  exit 1
fi

nouveaux=0
while read -r nom; do
  [ -n "$nom" ] || continue
  case "$nom" in CLI_*|ART_*|ARB_*) ;; *) continue ;; esac
  [ -e "$DEPOT/$nom" ] || [ -e "$TRAITES/$nom" ] && continue
  # -n : pas d'écrasement ; copie sous nom temporaire puis renommage atomique.
  if timeout 300 "${SMB[@]}" -c "get \"$nom\" \"$DEPOT/.$nom.part\"" >/dev/null 2>&1; then
    mv "$DEPOT/.$nom.part" "$DEPOT/$nom"
    echo "$(date '+%F %T') reçu $nom ($(stat -c %s "$DEPOT/$nom") octets)"
    nouveaux=$((nouveaux + 1))
  else
    rm -f "$DEPOT/.$nom.part"
    echo "$(date '+%F %T') ECHEC copie $nom" >&2
  fi
done < <(awk '/^  [A-Za-z0-9]/ && $2 == "A" {print $1}' <<<"$LISTE")

[ "$nouveaux" -gt 0 ] || true
