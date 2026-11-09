# Démo mobile hébergée à part (sans mot de passe)

La maquette `../demo-appli.html` est servie par un nginx isolé : ni les fronts (Promoteurs / Direction commerciale),
ni l'API ne sont concernés. Pas de mot de passe : la confidentialité repose sur le réseau.

## Mise en place (sur le serveur)
1. Copier `demo-appli.html` et ce dossier `serveur` sur le serveur (même arborescence : `demo/demo-appli.html`, `demo/serveur/`).
2. Dans ce dossier : `docker compose up -d`.
3. La démo écoute sur `127.0.0.1:8088` du serveur, donc invisible de l'extérieur. Pour la partager :
   - la publier via le reverse proxy existant sur une adresse dédiée (ex. `https://demo.<domaine>`), **accessible
     uniquement depuis le réseau interne / VPN** ;
   - décommenter et adapter les lignes `allow` / `deny` de `nginx.conf` avec les plages IP internes.
   Ne pas ouvrir le port 8088 directement sur Internet : sans mot de passe, toute personne ayant le lien verrait la démo.

## Mettre à jour
Remplacer `demo-appli.html` sur le serveur puis recharger la page.

## Retirer
`docker compose down`.
