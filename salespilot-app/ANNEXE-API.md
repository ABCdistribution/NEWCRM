# Annexe technique — API utilisée par l'application mobile

Version 0.2 — 26/10/2026 — complète le [cahier des charges](CDC.md).

> **À lire avant usage.** Ce relevé a été fait par lecture du code de `crm-api` (branche `dev`, commit `df74bcf`). Il n'a pas été confronté à un appareil réel ni exécuté route par route. Il faut le **revérifier** avant de s'y fier pour un développement : la référence reste le Swagger de l'API (`/docs`) et le code.

Conventions : toutes les routes sont derrière une authentification par jeton, sauf mention. « Rôles : tous » = aucune restriction de rôle. Pagination par défaut : `page` / `limit` (20 par défaut, 100 au maximum).

---

## 1. Authentification

| Élément | Constat |
|---|---|
| Connexion | `POST /auth/login` (public). Corps : `{ username, password }` (identifiant et mot de passe AD). Réponse : `{ accessToken, user: { id, username, displayName, email, role } }`. |
| Jeton | JWT, charge `{ sub, username, role }`, **8 h** par défaut (configurable). Pas de jeton de rafraîchissement, pas de révocation, pas de déconnexion côté serveur. |
| Contrôle à chaque appel | L'utilisateur est rechargé en base ; compte absent ou désactivé → refus. Le **rôle effectif est celui de la base**, pas celui du jeton. |
| Profil | `GET /auth/me` renvoie l'**entité utilisateur complète** (dont la photo en binaire, le code représentant, la région, le secteur, le directeur). À alléger pour le mobile. |
| Provisionnement | À chaque connexion, l'utilisateur est créé ou mis à jour depuis l'AD (nom, e-mail, photo, région, directeur, code représentant). |
| Rôles | `COMMERCIAL`, `CHEF_SECTEUR`, `ADMIN`, `DIRECTEUR_REGIONAL`, `DIRECTION`, `ADV`, `MARKETING` |
| Absent | Limitation des tentatives, verrouillage, déconnexion, rafraîchissement du jeton. |

---

## 2. Routes par domaine

### 2.1 Clients / magasins — rôles : tous
| Route | Rôle | Remarques |
|---|---|---|
| `GET /clients` | Liste du portefeuille | Paramètres : `search`, `repr`, `enrich=1`, `tous=1`, `actif=true\|false`, `avecAdresse=1`. Un promoteur avec code représentant est **limité à ses magasins** (sauf `tous=1`). `enrich=1` ajoute CA du mois et N-1, évolution, jours depuis la dernière visite, périodicité, CS, retard, baisse, alertes, état. |
| `GET /clients/geo` | Magasins géolocalisés | Non paginé. Champs : id, enseigne, ville, code postal, classe, latitude, longitude. Périmètre selon le rôle. |
| `GET /clients/fiches` | Contacts et 20 dernières notes de chaque magasin, en un appel | Prévu pour la réplication hors ligne. Non paginé. **Seul le promoteur est limité à son portefeuille.** |
| `GET /clients/:id` | Fiche | Contacts, notes, périodicités, secteur. **Aucun contrôle de périmètre.** |
| `GET /clients/:id/historique` | Commandes, visites, CA mensuel N / N-1 | Même remarque de périmètre. |
| `GET /clients/:id/journal-contacts` | 10 derniers appels et e-mails | |
| `POST /clients/:id/contacts`, `PATCH …/:contactId`, `DELETE …/:contactId` | Contacts | Nom obligatoire (≤ 60), poste, téléphones, e-mail. **Pas d'`idApk`** : un rejeu crée un doublon. Suppression logique. |
| `POST /clients/:id/visites-commerciales` | Visite commerciale | Voir §2.2. |
| `POST /clients/:id/appels` | Appel | `dateAppel`, `dureeSec`, `resultat` ∈ {REPONDU, SANS_REPONSE, MESSAGERIE, RAPPEL_PREVU}, `commentaire` ≤ 2000, `idApk` ≤ 64. Doublon → `{ id, idApk, dejaSynchronise: true }`, sans contrôle du propriétaire. |
| `POST /clients/:id/emails` | E-mail | `dateEmail`, `destinataire` ≤ 320, `sujet` ≤ 500, `commentaire` ≤ 2000, `idApk`. |
| `POST /clients/:id/notes`, `DELETE …/notes/:noteId` | Notes | `remarque` ≤ 2000, `idApk`. Doublon → renvoie la note existante. **`idApk` non unique en base** (déduplication applicative, non atomique). |
| `PATCH /clients/:id/periodicite` | Périodicité | `{ periodiciteId }` ou `null`. |
| `GET /periodicites` | Référentiel | Actives uniquement. |
| `POST /clients`, `PATCH /clients/:id`, `DELETE /clients/:id` | Création / modification / suppression | **Ouvertes à tous les rôles, promoteur compris** — à restreindre. |

Absent : photo de magasin, enregistrement de la position GPS d'une visite.

### 2.2 Visites — rôles : tous
| Route | Remarques |
|---|---|
| `GET /visites` | `page`, `search`. Taille de page fixe : 30. Promoteur → les siennes ; **tous les autres rôles → toutes les visites**. Pas de filtre de dates. |
| `POST /visites` | **`idApk` obligatoire** (≤ 64). Cible : `clientId` **ou** `prospectId`. Champs : `planningId` (doit appartenir au promoteur ; la visite planifiée est soldée), `motif` ≤ 60, `dnAbc`, `dnConcurrence`, `dnGondoleHaute`, `dnGondoleBasse` (entiers ≥ 0), `commentaire` ≤ 2000, `reponses[{ questionId, valeur }]` (questions inconnues ignorées en silence). Doublon → `{ id, idApk, dejaSynchronisee: true }` si même promoteur, sinon **403**. Transaction unique. |
| `POST /clients/:id/visites-commerciales` | Visite commerciale : `avecRdv`, `objets[]`, `remplissage` ≤ 40, `compteRendu` ≤ 4000, `prochaineVisite` (date), `reponses[{ libelle, ok, remarque }]`, `idApk`, `debut`, `fin`. Crée la visite et ses jalons début / fin. Doublon : même logique, 403 si autre promoteur. |
| `POST /visites/:id/photos` | Multipart, champ `photo`, **10 Mo maximum**, type `image/*` obligatoire. Seul l'auteur (ou un administrateur) peut ajouter. `idApk` optionnel pour rejouer. Aucune limite de nombre, aucune compression ni miniature côté serveur. Stockage en base. |
| `GET /visites/:id/photos` et `…/:photoId` | Liste et binaire (cache privé 1 h). |
| `GET /questionnaire` | Questions actives, ordonnées. Types : `CASE_A_COCHER`, `TEXTE`, `NOMBRE`, `NOTE_1_5`. L'édition est réservée à ADMIN et DIRECTION. |

Absent : détail d'une visite (`GET /visites/:id`), routes pour la distribution numérique détaillée, les PEM et les promotions vues en visite (les tables existent mais restent vides).

### 2.3 Commandes
| Route | Remarques |
|---|---|
| `POST /commandes/apk` | Rôles : tous. Corps : `idCommandeApk` (4 à 10 caractères alphanumériques — **clé anti-doublon et lien avec l'ERP**), `clientId`, `dateCommande`, `commentaire` ≤ 2000, `lignes[≥ 1]{ articleId, quantite ≥ 1, prixIndicatif ≥ 0 }`. Doublon → `{ id, idCommandeApk, dejaSynchronisee: true }`, 403 si autre promoteur. Client ou article inconnu → 404. **Aucun contrôle que le magasin est dans le portefeuille.** |
| `GET /commandes/apk`, `GET /commandes/apk/:id` | Promoteur → les siennes ; **autres rôles → toutes**. Détail : lignes, article, `integree`, `numeroErp`. |
| `GET /commandes` | Commandes ERP. Promoteur → ses commandes ; autres → global. Filtres : `search`, `annulees`, `livraison`. |
| `GET /commandes/:id` | Lignes, expédition, livraison, transporteur, n° de suivi. **Aucun contrôle de périmètre.** |
| `PATCH /commandes/:id/livraison` | ADV, DIRECTION, ADMIN uniquement. |

### 2.4 Prospection — contrôle par rôle
Le promoteur est **exclu** de la plupart des routes de prospection.

| Route | Rôles | Remarques |
|---|---|---|
| `GET /prospects`, `/pipeline`, `/:id`, `/:id/historique` | CS, DR, DIRECTION, ADMIN | Hors périmètre → 404. |
| `POST /prospects`, `POST /prospects/apk` | CS, DR, ADMIN | `/apk` : `idApk` obligatoire. Doublon → `{ id, idApk, dejaSynchronise: true }`, **sans contrôle du propriétaire**. |
| `PATCH /prospects/:id` | CS, DR, ADMIN | Passer à PERDU exige `motifPerte`. Un changement d'étape est historisé. |
| `DELETE /prospects/:id` | DR, ADMIN | Suppression logique. |
| `POST /prospects/:id/convert` | CS, DR, ADMIN | Idempotente. Crée un magasin au code provisoire `PRSP-xxxxxxxx`. |
| Contacts de prospect | CS, DR, ADMIN | |
| `POST /prospects/:id/notes`, `/appels`, `/emails` | CS, DR, DIRECTION, ADMIN, **COMMERCIAL** | `idApk` ≤ 64. |
| Pièces jointes (`GET`, `POST /prospects/:id/pieces-jointes`) | dont COMMERCIAL | Champ `fichier`. **Aucune limite à la réception** (le contrôle de 10 Mo se fait après chargement en mémoire), **aucun filtre de type**, pas d'`idApk`. |
| `GET /opportunites`, `POST`, `PATCH` | Lecture : CS, DR, DIRECTION, ADMIN ; écriture : CS, DR, ADMIN | Pas d'`idApk`. |

### 2.5 Planning, plannifications, tournées
| Route | Rôles | Remarques |
|---|---|---|
| `GET /plannings` | Tous | `promoteurId` obligatoire, `debut`, `fin` (intervalle semi-ouvert). Un promoteur ne lit que le sien (403 sinon). Génère les occurrences des récurrences avant lecture. |
| `POST`, `PATCH`, `DELETE /plannings` ; `POST`, `DELETE /plannifications` | ADMIN, DIRECTION, DR, CS | Un promoteur ne planifie pas. La création ne vérifie pas que le promoteur est dans le périmètre du planificateur. |
| `GET /plannifications` | Tous | Mêmes règles de lecture. |
| `GET /tournees/me` | CS, DR, DIRECTION, ADMIN (**pas le promoteur**) | Sans dates : toutes les étapes, non paginé. |
| `GET /tournees/user/:userId` | idem | Limité à l'équipe directe (`directeurId`). |
| `POST /tournees` | idem | `adm` **ou** (`clientId` ou `prospectId`), `datePassage`, `note` ≤ 500, `visiteSimple`, `accompagnement`, `rdv`, `soireeEtape`, `soireeLieu`, `soireeAdresse`, `idApk`. Doublon du même utilisateur → étape existante. **Un `idApk` déjà pris par un autre utilisateur provoque une erreur serveur.** |
| `PATCH /tournees/:id`, `DELETE /tournees/:id` | idem | Uniquement ses propres étapes. |
| `GET /tournees/semaine`, `POST /tournees/semaine/prevision`, `POST /tournees/semaine/validation` | idem | Semaine ramenée au lundi. 400 s'il n'y a aucune étape, 409 si déjà validée. Les étapes restent modifiables après validation. |
| `GET /tournees/ical-token`, `GET /tournees/ical/:userId/:token` | — | Flux calendrier (28 jours passés, 84 futurs). **La seconde route est publique** ; le jeton n'est ni révocable ni renouvelable. |

### 2.6 Notifications
| Route | Remarques |
|---|---|
| `GET /notifications/me` | 20 dernières + compteur de non lues. Pas de pagination ni de filtre depuis une date. |
| `PATCH /notifications/:id/lu`, `POST /notifications/lu-tout` | |
| `POST /notifications/relance` | `{ planningId }`. **Aucune restriction de rôle** : tout utilisateur connecté peut relancer. |
| `POST /notifications/relance-membre` | `{ userId, message ≤ 500 }`. DR (ses collaborateurs directs), DIRECTION, ADMIN. Pas le CS. |
| Type | Chaîne libre (`RELANCE_VISITE`, `RELANCE_MEMBRE`), pas d'énumération. |

### 2.7 Catalogue, promotions
| Route | Remarques |
|---|---|
| `GET /articles` | `search` (code, libellé, code-barres, **marque**), `actif`, `rappel=true`, pages de 100. Champs : marque, gamme, famille, colisage, stock, prix indicatif, `enPromo`, `misEnAvant`, `substitutionId`. |
| `GET /articles/:id` | |
| `GET /promos`, `GET /promos/pem` | Listes complètes, non paginées. Édition : ADMIN, DIRECTION, MARKETING. |
| Rappels qualité | Représentés par le filtre `retourAutorise` ; **pas de modèle ni de route dédiés**. |

Absent : photo d'article, export complet, filtre « modifié depuis ».

### 2.8 Tableaux de bord
| Route | Remarques |
|---|---|
| `GET /performances/me` | Tous rôles. Sans code représentant : `{ noRepr: true }`. |
| `GET /dashboard/me` | Scopé au code représentant ; **global si le compte n'en a pas**. Contient la tournée du jour et les produits en rappel. |
| `GET /dashboard/evolution`, `GET /dashboard/visites-regions` | CA / commandes sur 6 mois ; visites par région. |
| `GET /dashboard/direction` | ADMIN, DIRECTION, DR, CS. Le CS est limité à ses secteurs ; **le DR voit toute la force de vente**. |

### 2.9 Divers
- `GET /users/:id/photo` : JPEG, cache privé 1 h, sans ETag. Photo issue de l'AD.
- `GET /users` : ADMIN, DIRECTION, DR, CS (le CS voit les membres de ses secteurs).
- Aucune route pour modifier son propre profil.
- Console d'administration (`/admin/*`), imports ERP : ADMIN uniquement, hors périmètre mobile.

---

## 3. Règles de synchronisation déjà codées

- **Idempotence par `idApk`** (≤ 64 caractères ; commandes : 4 à 10 alphanumériques).
  - Unique en base : visites, photos de visite, prospects, appels et e-mails (clients et prospects), étapes de tournée, commandes mobiles.
  - **Non unique** : notes (clients et prospects).
  - **Absent** : contacts, pièces jointes, opportunités.
- **Réponse en cas de doublon** : indicateur `dejaSynchronisee` (visites, commandes) **ou** `dejaSynchronise` (appels, e-mails, photos, prospects) — deux orthographes à gérer côté application, ou à homogénéiser.
- **Contrôle du propriétaire** : refus 403 pour visites, visites commerciales et commandes ; **aucun** pour appels, e-mails, notes, prospects.
- **Suppression logique** (`deletedAt`) : les lectures excluent les éléments supprimés ; **aucune route n'expose les suppressions** — l'application ne peut pas les apprendre autrement qu'en rechargeant.
- **Conflits** : aucun mécanisme (pas de version, pas d'ETag) ; dernière écriture gagnante.
- **Ordre d'envoi** non imposé par le serveur. Dépendances à respecter côté application : prospect → visite ou étape qui le référence ; visite → ses photos ; questions créées à la volée avant leurs réponses.
- **Dates** : intervalles `[début, fin)` en ISO ; semaine ramenée au lundi (UTC) ; les calculs « mois en cours » utilisent le fuseau du serveur.
- **Pagination** : voir en tête ; non paginés : `/clients/geo`, `/clients/fiches`, `/promos`, `/tournees/me`, `/plannings`.
- **Aucun** paramètre « modifié depuis », aucune synchronisation en lot.

---

## 4. Énumérations (valeurs exactes)

| Énumération | Valeurs |
|---|---|
| Rôle | `COMMERCIAL`, `CHEF_SECTEUR`, `ADMIN`, `DIRECTEUR_REGIONAL`, `DIRECTION`, `ADV`, `MARKETING` |
| Classe de magasin | `A`, `B`, `C`, `D`, `E`, `F`, `G` |
| Statut de livraison | `EN_PREPARATION`, `EXPEDIEE`, `LIVREE_PARTIELLE`, `LIVREE` |
| Étape du pipeline | `NOUVEAU`, `CONTACTE`, `PROPOSITION`, `VISITE`, `NEGOCIATION`, `GAGNE`, `PERDU` — probabilités par défaut 10, 25, 50, 65, 80, 100, 0 (à valider) |
| Source de prospect | `SALON`, `RECOMMANDATION`, `TERRAIN`, `WEB` (à valider) |
| Motif de perte | `PRIX`, `CONCURRENCE`, `PAS_DE_BESOIN`, `SANS_REPONSE`, `AUTRE` (à valider) |
| Résultat d'appel | `REPONDU`, `SANS_REPONSE`, `MESSAGERIE`, `RAPPEL_PREVU` |
| Type d'opportunité | `REFERENCEMENT`, `OP`, `MISE_EN_AVANT` |
| Statut d'opportunité | `OUVERTE`, `GAGNEE`, `PERDUE`, `ANNULEE` |
| Type de question | `CASE_A_COCHER`, `TEXTE`, `NOMBRE`, `NOTE_1_5` |
| Notification | chaîne libre : `RELANCE_VISITE`, `RELANCE_MEMBRE` |
| Périodicités | référentiel en base (codes 1 à 6 hérités) ; intervalle en jours déduit du libellé |

---

## 5. Ce qui manque pour le mobile (constaté dans le code)

**Bloquant ou à traiter avant ouverture à des promoteurs**
1. **Identification et télémétrie des appareils** : aucune table, aucune route ; le seul indice est un nom d'application écrit en dur sur les photos. La console admin renvoie `mobile: null`.
2. **Version minimale de l'application** et numéro de version de l'API : pas de préfixe de version, pas de contrôle (aucune réponse « mise à jour requise »).
3. **Sécurité du jeton** : pas de déconnexion ni de révocation, pas de limitation des tentatives de connexion, profil complet renvoyé.
4. **Périmètres** : plusieurs routes de lecture sans contrôle (fiche magasin, historique, commandes, visites, commandes mobiles des autres rôles, tableau de bord pour un compte sans code représentant, tableau de bord de direction pour un DR) ; création / modification / suppression de magasins ouvertes à tous.
5. **Idempotence incomplète** : contacts, pièces jointes, opportunités ; notes non uniques ; collision d'`idApk` de tournée entre utilisateurs → erreur 500.

**À prévoir**
6. Synchronisation différentielle (« modifié depuis », suppressions), éventuellement en lot.
7. Notifications **push** : jetons d'appareil, envoi.
8. Routes manquantes : détail d'une visite, distribution numérique détaillée, PEM et promotions vues en visite, GPS de visite.
9. Pièces jointes de prospect : limite de taille et filtre de type à la réception.
10. Homogénéiser l'indicateur de doublon (`dejaSynchronisee` / `dejaSynchronise`) et le contrôle du propriétaire.
11. Rappels qualité : modèle et route dédiés plutôt qu'un filtre.
12. Valeurs métier marquées « à valider » (sources, motifs, probabilités).
13. Un promoteur ne peut ni créer de prospect, ni accéder aux tournées ni au pipeline, **ni même lister les prospects**, alors que l'API lui permet d'ajouter notes, appels, e-mails et pièces jointes à un prospect : incohérence à lever (le cahier des charges retire la prospection aux promoteurs).
14. **Une commande mobile envoyée n'est plus modifiable ni annulable** : l'API n'a aucune route de modification ou d'annulation (seulement création et lecture).
15. **Révocation** : il n'existe pas de révocation de jeton ; l'API recharge l'utilisateur à chaque appel et refuse un compte désactivé, ce qui joue ce rôle tant que le compte est désactivé côté CRM.

Le suivi de ces points est à rapprocher de `docs/BACKLOG.md` à la racine du dépôt.
