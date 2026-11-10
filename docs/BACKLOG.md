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

## crm-web (front unique) — points relevés à la vérification finale, hors périmètre du front
Rien n'est compensé côté front : les données sont filtrées par rôle ET périmètre par l'API.

**API — nouveaux trous de périmètre** (à rattacher à la famille du point 1.1 : `GET /commandes`, `/commandes/:id`, `/clients/:id` et historique ; la mention « dashboard » y est trop générique)
- `GET /dashboard/direction` non borné pour DIRECTEUR_REGIONAL : `scopeSecteur` n'est vrai que pour CHEF_SECTEUR (`dashboard.service.ts`, ~l.227). Un DR reçoit CA, classement nominatif, CA par secteur, magasins sans commande, prospection et scatter de toute la force de vente. Le borner par le périmètre de `perimetreEquipe` (regionId / directeurId du DR).
- `blocProspection` (~l.689-715) et `scatterMagasins` (~l.556-563) n'ont aucun paramètre de périmètre : pour un CHEF_SECTEUR, le bloc prospection et « Objectif vs CA réalisé — par client » (jusqu'à 300 magasins) couvrent tout le réseau.
- COMMERCIAL sans `idRepr` : `GET /dashboard/me` (`dashboard.service.ts` ~l.45-48 et 191-193) et `GET /commandes` (`commandes.service.ts` ~l.17) basculent en vue globale ; ils doivent renvoyer un périmètre vide. Le périmètre d'un ADV (pas d'`idRepr`) est à décider avec l'utilisateur.
- Clients : `POST` / `PATCH` / `DELETE /clients` sans `@Roles` (ADMIN seul ou ADMIN + DIRECTION : décision métier) ; contacts, notes, périodicité, visites commerciales, appels et emails sans contrôle de périmètre ; `findAll` accepte n'importe quel `?repr=` pour tout rôle non COMMERCIAL.
- Prospects : `scope()` renvoie « global » pour tout rôle autre que CS / DR (un COMMERCIAL lit et écrit tout prospect : pièces jointes, notes, appels, emails) ; `secteurId` et `assignedToId` sont écrits sans vérifier le périmètre de l'appelant ; `FileInterceptor('fichier')` sans `limits` (voir 1.7).
- Un endpoint qui renvoie, par promoteur du périmètre, le nombre de clients et les visites prévues / faites de la semaine remplacerait les 2 appels par promoteur de `lignesPromoteurs` (crm-web).
- Pas de moteur d'alertes ni de flux de bordereaux de rappel côté API : les écrans Alertes et Qualité (bordereaux) de crm-web sont des maquettes, signalées par un bandeau « Données d'exemple ».

**Déploiement de crm-web**
- Définir `TZ=Europe/Paris` dans l'environnement du processus Next. Le code de planning ne dépend plus du fuseau du serveur (`aujourdhuiParis`, `FUSEAU`), mais des formats de date sans fuseau explicite en dépendent encore.
- Les redirections de `src/lib/redirections.ts` ne servent qu'une fois les anciens hôtes ou ports d'ABC Sales (3000) et d'ABC Pilot (3001) dirigés vers crm-web (3002). `PERMANENT` doit passer à `true` à la mise en production, une fois la table figée.
- Pour 1.11 : HSTS et `COOKIE_SECURE=true` au reverse proxy TLS, puis une CSP stricte avec nonce, à valider écran par écran.
- Pièces jointes : `serverActions.bodySizeLimit` est à 11 Mo (`next.config.ts`). À tester avec un fichier de 9 à 10 Mo derrière le middleware ; si le corps est tronqué, ajouter `experimental.middlewareClientMaxBodySize: '11mb'`.
- **`scripts/deploy.sh` à adapter avant toute fusion dans `main`** : il construit et redémarre `/var/www/crm-helios` (port 3001) et `/var/www/crm-promoteur` (port 3002), dossiers supprimés du dépôt le 2026-11-10, et ne déploie pas `crm-web`. Sans adaptation, le premier déploiement depuis `main` échouerait à l'étape des fronts (dossiers absents) et, le marqueur `.deployed-sha` n'étant pas mis à jour, le cron (toutes les 3 minutes) retenterait en boucle, API comprise. À décider : port de `crm-web` en production (3002 est aujourd'hui celui d'ABC Sales), dossier `/var/www/crm-web`, redirection des anciens hôtes/ports vers `crm-web`, arrêt des deux anciens processus `next start`. Le workflow `.github/workflows/deploy.yml` lance ce même script à chaque push sur `main`.
