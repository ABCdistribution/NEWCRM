# CRM ABC Cosmétique — conventions du projet

Monorepo CRM : une API NestJS, une base Postgres (Prisma) et deux fronts Next.js.

## Architecture
| Dossier | Rôle |
|---|---|
| `crm-api` | API NestJS 11 (port 4000), Swagger sur `/docs`. Auth LDAP/AD puis JWT. |
| `packages/database` | Schéma Prisma 7 (`prisma/schema.prisma`, ~46 modèles), migrations, seed. Package `@crm/database`. |
| `crm-promoteur` | **Selios** — espace terrain (Next 15, React 19, Tailwind 4, port 3000). |
| `crm-helios` | **Helios** — pilotage/encadrement (même stack, port 3001). |
| `scripts/` | Imports AS400, copie de l'ancien CRM, diagnostic AD. |

Les deux fronts ne sont **pas** dans le workspace pnpm (`pnpm-workspace.yaml` = `crm-api` + `packages/*`) : chacun a son propre `node_modules` et son `pnpm-lock.yaml`. Ils appellent l'API côté serveur uniquement (`serverFetch`, Server Actions), avec le JWT dans le cookie httpOnly `crm_session`.

## Commandes
- Installer : `pnpm install` à la racine (API + database), puis `pnpm install --ignore-workspace` dans chaque front.
- Base locale : `docker compose up -d db`, puis `set -a; . crm-api/.env; set +a; pnpm --filter @crm/database exec prisma migrate deploy` et `pnpm --filter @crm/database run db:generate` (à refaire après un changement de schéma).
- API : `cd crm-api && pnpm start:dev`. Fronts : `pnpm dev` dans `crm-promoteur` / `crm-helios`.
- Typage : `npx tsc --noEmit` dans chacun des trois projets (passe aujourd'hui).
- Lint : **non configuré** (`next lint` est cassé). Tests : **aucun** pour l'instant.

## Environnement local
- `.env` (racine, lu par docker compose) et `crm-api/.env` (lu par l'API) : jamais versionnés, jamais recopiés dans le chat ou le code.
- La connexion passe **toujours** par l'Active Directory, y compris en local : il n'existe volontairement aucun login de contournement. Il faut un accès réseau/VPN à l'AD et les variables `LDAP_*` dans `crm-api/.env`.
- Sans `crm-api/.env`, l'API ne démarre pas. Variables lues : `DATABASE_URL`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `PORT`, `LDAP_*`, `ADMIN_USERNAMES`, `IMPORT_DIR`, `REDIS_*`.
- Les fronts lisent `API_URL` (défaut `http://localhost:4000`), `HELIOS_PORT` / `SELIOS_PORT` pour la bascule d'univers.

## Conventions
- Code et commentaires en français, messages d'erreur utilisateur en français.
- API : un module par domaine ; `JwtAuthGuard` puis `RolesGuard` + `@Roles()` posés par contrôleur (pas de guard global) ; DTO class-validator ; `ParseUUIDPipe` sur les `:id`. Toute route de données doit porter un rôle ET un filtrage de périmètre (utilisateur / secteur / région).
- Idempotence mobile par `idApk`, suppression logique par `deletedAt`.
- Fronts : jetons de couleur dans `globals.css` (`brand`, `accent`, `navy-*`) ; les menus latéraux sont en `dark` local. Une modification d'UI partagée se fait dans les DEUX apps (12 fichiers sont dupliqués à l'identique).
- Ne jamais lancer d'import ou de seed contre la production.

## Règles de travail
- Branche dédiée, commits petits ; pas de déploiement ni d'action sur la production sans accord explicite.
- **Fin de tâche** : quand une tâche est terminée ET validée (typage, build, tests disponibles, relecture par `audit-architecture` si elle touche permissions, auth ou migrations), l'orchestrateur appelle l'agent `git-manager` avec la liste des fichiers de la tâche. Il vérifie, commite et pousse sur la branche distante `dev` uniquement (jamais `main`, jamais de `--force`), puis il rend un résumé. Il ne déploie jamais ; le déploiement reste soumis à l'accord de l'utilisateur.
- Une tâche n'est validée que si typage + build + tests pertinents ont été exécutés ; sinon le signaler.
- Backlog et décisions en attente : `docs/BACKLOG.md`.
