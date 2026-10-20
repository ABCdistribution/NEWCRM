#!/bin/sh
# Fournit à ssh/rsync le mot de passe de l'ancien serveur depuis l'environnement (jamais écrit sur disque).
printf '%s\n' "$OLD_CRM_SSH_PASSWORD"
