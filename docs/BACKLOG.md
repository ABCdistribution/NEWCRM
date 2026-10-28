# Backlog priorisé — issu de l'audit du 21/10/2026

Légende : 🔴 critique · 🟠 important · 🟡 mineur. **[ACCORD]** = décision ou accord de l'utilisateur requis avant d'agir.
Rien de ce qui touche la production n'est fait sans accord explicite.

## Lot 0 — Socle de vérification (prérequis, faible risque)
| # | Tâche | Agent |
|---|---|---|
| 0.1 | Scripts racine `typecheck` / `build` / `lint` / `test` ; config ESLint des 3 projets (le `next lint` actuel est cassé) | tests-qualite |
| 0.2 | Jest dans `crm-api` + premiers tests : `RolesGuard`, `resolveRole`, échappement LDAP, jeton iCal | tests-qualite |
| 0.3 | `.env.example` racine et `crm-api` (variables requises, sans secret) | backend-db |
| 0.4 | CI GitHub Actions minimale (install, db:generate, tsc, build, tests) **[ACCORD : runner interne ou non]** | tests-qualite |

## Lot 1 — Sécurité des données (le plus urgent)
| # | Gravité | Tâche | Agent |
|---|---|---|---|
| 1.1 | 🔴 | **Périmètre et rôles sur `clients`** : tout utilisateur connecté peut lire/modifier/supprimer n'importe quel client (`/clients/:id/*`) ; `?tous=1` et `?repr=` contournent le filtre. Service central de périmètre (utilisateur/secteur/région) appliqué à clients, commandes, visites, plannings, dashboard, prospects. **[ACCORD : règles de visibilité par rôle]** | backend-db |
| 1.2 | 🔴 | Lien iCal public non révocable, dérivé de `JWT_SECRET` (repli sur chaîne vide) | backend-db |
| 1.3 | 🔴 | Redis (sans mot de passe) et Postgres exposés sur toutes les interfaces dans `docker-compose.yml` **[ACCORD : touche l'infra prod]** | backend-db |
| 1.4 | 🔴 | Aucune limitation des tentatives sur `POST /auth/login` (verrouillage de comptes AD possible) | backend-db |
| 1.6 | 🟠 | Swagger `/docs` exposé en prod ; ajouter helmet ; `forbidNonWhitelisted` | backend-db |
| 1.7 | 🟠 | Uploads : limites Multer et liste blanche MIME sur les pièces jointes prospect (DoS mémoire) | backend-db |
| 1.8 | 🟠 | `GET /commandes/:id`, `POST /notifications/relance`, `POST /commandes/apk`, `/visites` sans périmètre | backend-db |
| 1.9 | 🟠 | `/auth/me` renvoie l'entité User brute (photo BYTEA) → DTO de sortie | backend-db |
| 1.10 | 🟠 | Front : encoder/valider les identifiants insérés dans les chemins API ; remplacer les redirections basées sur l'en-tête `Host` par des URL configurées | frontend-ux |
| 1.11 | 🟠 | Cookie de session sans `Secure` (HTTP interne) → HTTPS via reverse proxy **[ACCORD : infra]** | — |

## Lot 2 — Bugs et fonctionnalités incomplètes
| # | Gravité | Tâche | Agent |
|---|---|---|---|
| 2.1 | 🟠 | Le rôle changé à la main est écrasé au login par l'OU AD (contredit le commentaire « jamais rétrogradé ») **[ACCORD : quelle source fait foi ?]** | backend-db |
| 2.2 | 🟠 | Prospect passable à `GAGNE` sans conversion ; la conversion crée un client sans commercial rattaché | backend-db |
| 2.3 | 🟠 | Front : mutations qui échouent en silence (`.catch(() => undefined)`, ~40 occurrences) ; pas de `error.tsx`/`not-found.tsx` ; pas de `loading.tsx` côté ABC Sales | frontend-ux |
| 2.4 | 🟠 | ~~Lien mort `/pilotage/imports`~~ — corrigé : l'entrée du menu est remplacée par la page Administration | frontend-ux |
| 2.5 | 🟠 | ABC Pilot : aucun menu mobile | frontend-ux |
| 2.6 | 🟠 | Validation des DTO imbriqués (visite commerciale, dates, `PATCH /plannings/:id`) → plus de 500 sur entrée invalide | backend-db |
| 2.7 | 🟡 | Pages « bientôt » (paramètres, agenda), règles d'alertes stockées en `localStorage` | frontend-ux |

## Lot 3 — Intégrité et performance de la base
| # | Gravité | Tâche | Agent |
|---|---|---|---|
| 3.1 | 🟠 | Index manquants : `Commande(idRepr, dateCommande)`, `Client.idCommercial1/2`, `Planning.datePassage`, `User.regionId` (migration additive) | backend-db |
| 3.2 | 🟠 | Contraintes et transactions : unicité planning `(promoteur, client, date)`, `idApk` (course → 500), prospect/étape/notes | backend-db |
| 3.3 | 🟠 | Trigger `commande_lignes_maj_total` et CHECK « client XOR prospect » absents du schéma Prisma (perdus au `db push`) | backend-db |
| 3.4 | 🟡 | N+1 (synchro AD, dashboard), `GET /clients/fiches` sans pagination, `GET /plannings` qui écrit en lecture | backend-db |

## Lot 4 — Dette technique (après les lots 1 à 3)
- Package partagé pour les 12 fichiers dupliqués et `api.ts` (ABC Pilot 1086 lignes) ; fronts ajoutés au workspace pnpm.
- Découper `clients.service.ts` (758 lignes), `dashboard.service.ts` (618 lignes), `tournees.controller.ts`.
- Dockerfile en multi-étapes, utilisateur non-root, healthcheck API ; Dependabot.

## Dépendances entre lots
Lot 0 avant tout → 1.1 s'appuie sur les tests du 0.2 → 3.1/3.2 après 1.1 (mêmes services) → Lot 4 en dernier.
Les agents `backend-db` et `frontend-ux` peuvent travailler en parallèle (fichiers disjoints) ; deux tâches `backend-db` ne tournent pas en parallèle sur le même module.

## Décisions attendues de l'utilisateur
1. Règles de visibilité par rôle (1.1) : qui voit quels clients, commandes, visites ?
2. Source de vérité du rôle : OU de l'AD ou rôle saisi dans le CRM (2.1) ?
3. OK pour toucher `docker-compose.yml` (1.3) et préparer HTTPS (1.11) ?
4. CI : runner GitHub interne ou pas de CI pour l'instant (0.4) ?

## Administration (console ADMIN dans ABC Pilot) — `/pilotage/admin`
- **Phase 1 faite** : page à onglets (Vue d'ensemble, Utilisateurs, Organisation, Synchronisations, Contenus) ; routes API `GET /admin/apercu` et `GET /admin/organisation` (ADMIN) ; page Utilisateurs d'ABC Sales supprimée. Indicateurs en lecture seule, sans état d'alerte.
- **À venir** : Mobile (nécessite que l'application remonte version, modèle, dernière synchro), Configuration (table de paramètres), Journal d'audit (enregistrement des opérations sensibles), « dernière connexion », diagnostic par utilisateur, relance des lignes d'import en erreur.
- **À trancher** : champs pilotés par l'AD vs modifiables dans le CRM (le rôle des comptes en OU force de vente est écrasé à chaque connexion).
