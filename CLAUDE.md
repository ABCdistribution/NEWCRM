# CRM ABC Cosmétique — conventions du projet

Monorepo CRM : une API NestJS, une base Postgres (Prisma) et un front Next.js (`crm-web`).

## Architecture
| Dossier | Rôle |
|---|---|
| `crm-api` | API NestJS 11 (port 4000), Swagger sur `/docs`. Auth LDAP/AD puis JWT. |
| `packages/database` | Schéma Prisma 7 (`prisma/schema.prisma`, ~46 modèles), migrations, seed. Package `@crm/database`. |
| `crm-web` | **Front unique** (Next 15, React 19, Tailwind 4, port 3001) : remplace `crm-promoteur` et `crm-helios`. Deux groupes de routes `(promoteurs)` / `(direction)`, thème bleu/violet posé par `data-espace` selon le rôle, une page = une URL (sans préfixe `/pilotage`), garde de rôle dans chaque page et chaque Server Action (`src/lib/roles.ts`, table `src/lib/routes.ts`). Fiche de recette : `docs/RECETTE-CRM-WEB.md`. |
| `scripts/` | Imports AS400, copie de l'ancien CRM, diagnostic AD. |

**Noms** : ABC Sales (ancien `crm-promoteur`) = espace Promoteurs et ABC Pilot (ancien `crm-helios`) = espace Direction de `crm-web` (plateforme « SalesPilot ABC »). Les anciens fronts ont été supprimés le 2026-11-10 ; leur code reste lisible dans l'historique git (ex. `git show 4c5e7b6:crm-helios/src/lib/api.ts`). Certains identifiants gardent les anciens noms (UID iCal `@crm-helios.abc` ; sur le serveur, les anciens dossiers `/var/www/crm-helios` et `/var/www/crm-promoteur` subsistent par leurs fichiers non versionnés, voir `docs/BACKLOG.md`) : ne pas les renommer sans coordonner la prod.

Le front n'est **pas** dans le workspace pnpm (`pnpm-workspace.yaml` = `crm-api` + `packages/*`) : `crm-web` a son propre `node_modules` et son `pnpm-lock.yaml`. Il appelle l'API côté serveur uniquement (`serverFetch`, Server Actions), avec le JWT dans le cookie httpOnly `crm_session`. Aucune route `/api` du front ne relaie l'API au navigateur.

## Commandes
- Installer : `pnpm install` à la racine (API + database), puis `pnpm install --ignore-workspace` dans `crm-web`.
- Base locale : `docker compose up -d db`, puis `set -a; . crm-api/.env; set +a; pnpm --filter @crm/database exec prisma migrate deploy` et `pnpm --filter @crm/database run db:generate` (à refaire après un changement de schéma).
- Données de démo (base LOCALE uniquement, les scripts refusent toute autre base), depuis `packages/database` : `node --env-file=../../crm-api/.env prisma/seed-dev-users.cjs` (comptes fictifs `[DÉMO]`), puis `prisma/seed.cjs` (clients, catalogue, commandes, visites…), puis `prisma/seed-prospection.cjs` (prospects et commandes du mois pour les graphiques de pilotage). Les trois sont ré-exécutables.
- API : `cd crm-api && pnpm start:dev`. Front : `pnpm dev` dans `crm-web` (port 3001).
- Typage : `npx tsc --noEmit` dans `crm-web` et dans `crm-api` (passe aujourd'hui). Build : `pnpm build` dans `crm-web` (ne pas builder pendant qu'un `pnpm dev` ou un autre build tourne dans le même dossier : ils partagent `.next`).
- Tests : `pnpm test` dans `crm-web` (Vitest, ~720 tests sur chemins sûrs, rôles, table des routes, redirections, validation d'ids, gardes des pages). Aucun test dans `crm-api`. Lint : **non configuré** (`next lint` est cassé).

## Environnement local
- `.env` (racine, lu par docker compose) et `crm-api/.env` (lu par l'API) : jamais versionnés, jamais recopiés dans le chat ou le code.
- La connexion passe **toujours** par l'Active Directory, y compris en local : il n'existe volontairement aucun login de contournement. Il faut un accès réseau/VPN à l'AD et les variables `LDAP_*` dans `crm-api/.env`.
- Sans `crm-api/.env`, l'API ne démarre pas. Variables lues : `DATABASE_URL`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `PORT`, `LDAP_*`, `ADMIN_USERNAMES`, `IMPORT_DIR`, `REDIS_*`, `RAPPORT_CLOTURE_DEPUIS` (lundi `yyyy-mm-dd` à partir duquel la clôture automatique des rapports d'activité s'applique ; absente = clôture désactivée, aucune semaine n'est verrouillée).
- `crm-web` lit `API_URL` (défaut `http://localhost:4000`) et `COOKIE_SECURE` ; en production, définir aussi `TZ=Europe/Paris`.

## Conventions
- Code et commentaires en français, messages d'erreur utilisateur en français.
- API : un module par domaine ; `JwtAuthGuard` puis `RolesGuard` + `@Roles()` posés par contrôleur (pas de guard global) ; DTO class-validator ; `ParseUUIDPipe` sur les `:id`. Toute route de données doit porter un rôle ET un filtrage de périmètre (utilisateur / secteur / région).
- Administration : une seule console, `/admin` dans `crm-web` (ADMIN seul), onglets portés par `?onglet=` ; API `crm-api/src/admin` en lecture seule. Ne pas recréer de page admin ailleurs.
- Idempotence mobile par `idApk`, suppression logique par `deletedAt`.
- Front (`crm-web`) : une page = une URL, affichage selon `me.role` ; l'encadrement (ADMIN, DIRECTION, DIRECTEUR_REGIONAL, CHEF_SECTEUR) garde l'accès aux écrans terrain ; MARKETING et ADV : à définir. Un layout ne protège pas les pages ni les Server Actions : chaque page appelle `requireRole`, chaque action `exigerRole` (même liste de rôles que le `@Roles` de l'API visée). Les données sont filtrées par rôle ET périmètre par l'API, jamais côté front. Tout id placé dans un chemin d'API passe par `idSur` ou une validation UUID + `encodeURIComponent`. Toute nouvelle route s'ajoute dans `src/lib/routes.ts` (un test vérifie qu'elle a une page).
- Jetons de couleur dans `globals.css` (`brand`, `accent`, `navy-*`), portés par `[data-espace]` ; pas de couleur en dur ni de dégradé, sauf couleurs sémantiques de statut. Palettes par espace (voir le commentaire de `globals.css`) : fond du contenu `#f3f8ff` en Promoteurs / ADV, `#f6f8fa` en Direction ; menu latéral et cartes en blanc ; les surfaces sombres éventuelles passent par `dark` en local (ex. panneau de notifications).
- Décisions reportées : abonnement Outlook (flux iCal du planning) et choix de l'environnement de production de `crm-web` (voir `docs/BACKLOG.md`). **Avant de fusionner `dev` dans `main`** : `scripts/deploy.sh` déploie maintenant `crm-web` (port 3001) mais n'a jamais été exécuté sur le serveur, et la fusion doit se faire **en deux temps** (le premier passage après un `git merge` exécute encore l'ancien script) ; lire d'abord le point « Déploiement de crm-web » de `docs/BACKLOG.md` (ancien ABC Sales sur 3002, reverse proxy, `COOKIE_SECURE`).
- Ne jamais lancer d'import ou de seed contre la production.

## Règles de travail
- Branche dédiée, commits petits ; pas de déploiement ni d'action sur la production sans accord explicite.
- **Fin de tâche** : quand une tâche est terminée ET validée (typage, build, tests disponibles, relecture par `audit-architecture` si elle touche permissions, auth ou migrations), l'orchestrateur appelle l'agent `git-manager` avec la liste des fichiers de la tâche. Il vérifie, commite et pousse sur la branche distante `dev` uniquement (jamais `main`, jamais de `--force`), puis il rend un résumé. Il ne déploie jamais ; le déploiement reste soumis à l'accord de l'utilisateur.
- Une tâche n'est validée que si typage + build + tests pertinents ont été exécutés ; sinon le signaler.
- Backlog et décisions en attente : `docs/BACKLOG.md`.
