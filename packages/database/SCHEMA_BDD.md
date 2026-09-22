# Schéma de la base `gescom` — document de référence (avant refonte)

> Généré le 2026-07-27 à partir de la base de production (`mysqldump --no-data`).
> **133 tables**, moteur InnoDB, majorité en charset `utf8mb3`.
> Le DDL brut complet est disponible dans `sql/schema_gescom_full.sql` (à committer si souhaité).

Ce document décrit l'état **actuel** de la base tel qu'il est, y compris ses défauts. Il sert de base de discussion pour la refonte : chaque section « ⚠️ Pièges » liste les points à corriger ou à ne pas reproduire.

---

## 1. Conventions générales

- **Clé primaire** : `id` auto-incrément sur presque toutes les tables.
- **Soft delete** : colonne `deleted tinyint(1) DEFAULT 0` quasi partout. Aucune ligne n'est réellement supprimée ; toutes les requêtes doivent filtrer `deleted = 0`.
- **Horodatage** : `date_creation` (DEFAULT CURRENT_TIMESTAMP) et `date_modification` (ON UPDATE CURRENT_TIMESTAMP) sur la majorité des tables.
- **Aucune contrainte de clé étrangère** dans toute la base. Les relations existent uniquement via des `KEY` (index) et sont assurées côté applicatif. Rien ne garantit l'intégrité référentielle au niveau SQL.
- **Charset** : la plupart des tables sont en `utf8mb3` (parfois avec colonnes en `utf8mb3_general_ci` explicites), quelques-unes en `utf8mb4`. Mélange à homogénéiser (cible : `utf8mb4`).

### ⚠️ Pièges transverses (prioritaires pour la refonte)

1. **Pas de FK** → données orphelines possibles partout.
2. **Clés métier hétérogènes** : les entités AS400 sont référencées tantôt par leur `id` interne (int), tantôt par leur code métier `id_as400` / `id_client` (varchar). Voir §2.
3. **Type de `id_repr` incohérent** selon les tables (voir §2.3) — source de bugs de jointure.
4. **`ref_client` est vidée et réinsérée entièrement chaque nuit** par l'import AS400 (voir §3) → toute donnée saisie directement dans `ref_client` est perdue au prochain import.
5. **Charset mixte utf8mb3 / utf8mb4** → risques d'encodage sur les accents.

---

## 2. Clés et identifiants (à lire avant tout)

### 2.1 Le client / magasin
Un magasin existe sous deux identifiants :
- `ref_client.id` (int auto-incrément) — **instable** : régénéré à chaque import (l'AUTO_INCREMENT est déjà à ~2,36 millions). **Ne jamais stocker cet `id` comme référence durable.**
- `ref_client.id_as400` (varchar) — **la vraie clé métier stable**, issue de l'AS400 (code client `CLI`).

La plupart des tables filles référencent le client par **`id_as400`** (en varchar), sous des noms variables :
`id_ref_client`, `id_client`, `id_magasin`, `id_client_as400`, `id_as400`, `code_magasin`, `code_client`…

### 2.2 L'article
Même principe : `ref_article.id` (int, instable, régénéré à l'import — AUTO_INCREMENT ~823k) vs `ref_article.id_as400` (varchar, clé métier `code_article`).

### 2.3 Le représentant / promoteur (`id_repr`) — ⚠️ zone à risque
Le code représentant se retrouve sous plusieurs formes et **plusieurs types** :

| Table | Colonne | Type |
|---|---|---|
| `user` | `id_repr` | varchar(10) |
| `ref_client` | `id_commercial_1`, `id_commercial_2` | varchar(10) |
| `plannification` | `id_repr` | varchar(10) |
| `objectifs` | `id_repr` | varchar(5) |
| `commandes_as400` | `id_repr` | varchar(5) |
| `planning` | `id_repr` | **int** |
| `stat_promoteur_ca` / `_visite` / `_cumul_ca` | `id_repr` | **int** |
| `kilometres` | `id_repr` | int |

**Piège confirmé** : dans la table `planning`, la colonne `id_repr` ne contient **pas** `user.id_repr` mais `user.id` (l'id interne de l'utilisateur). C'est documenté dans le code (`user::supprimerPlanningPromoteur`). À clarifier absolument lors de la refonte : choisir **un** identifiant de représentant, d'un seul type, avec un seul sens.

---

## 3. Import AS400 (cœur du système, à comprendre en priorité)

Le CRM est alimenté quotidiennement depuis l'AS400 par des fichiers à **largeur fixe** déposés sur un montage réseau, puis découpés selon un mapping stocké en base.

- **Tables de mapping** (`struc_*`) : décrivent la position des champs dans les fichiers plats (`len_from`, `len_to`, `length`, `mapping` = nom de colonne cible).
  - `struc_ref_client`, `struc_ref_article`, `struc_ref_facture`, `struc_ref_tarif`, `struc_ref_centrale`, `struc_commandes_as400`, `struc_referentiels`.
- **`importAS400`** : table de staging brute à **100 colonnes** portant les codes de champs AS400 (`HSTYPE`, `HSCLIC`, `REPR1`…). Zone tampon avant transformation.
- **`log_referentiel`** : journal des fichiers importés (déduplication par nom de fichier).
- **`referentiels`** / `referentiels_nature` / `ref_structure_commerciale` : nomenclatures diverses issues de l'AS400.

### ⚠️ Pièges de l'import (critiques pour la refonte)

1. **`ref_client` est `DELETE` puis réinsérée intégralement à chaque import.** Conséquences :
   - `ref_client.id` change à chaque nuit → jamais utilisable comme référence.
   - Tout champ géré côté CRM et **non présent dans le fichier AS400 est écrasé** : c'est le cas de `actif` (repart à 1) et de `niveau_class` (repart à NULL).
2. **`TABLE 129`** (nom littéral avec un espace, sans PK ni `id`) : table de **référence non vidée** par l'import. Colonnes `id_as400`, `id_periodicite`, `actif` ('A'/'I'), `niveau_class`. Elle sert désormais à **réappliquer le statut actif/inactif** après chaque import (méthode `importAS400::applyStatutActif`). Règle actuelle : un client est actif **uniquement** s'il est présent dans `TABLE 129` avec `actif = 'A'` ; tout le reste est passé inactif.
3. **`niveau_class` n'est pas encore re-persisté** après import de la même façon → à traiter (une table locale persistante type `TABLE 129` est la piste).
4. À renommer lors de la refonte : `TABLE 129` (nom non normalisé) et se doter d'un vrai mécanisme de « données CRM persistantes » distinct des données AS400 volatiles.

---

## 4. Catalogue des tables par domaine

Légende : 🔑 = clé métier de jointure ; (N) = nombre de colonnes.

### 4.1 Clients / magasins
| Table | Rôle | Points clés |
|---|---|---|
| `ref_client` (33) | Référentiel magasins (importé AS400) | 🔑 `id_as400`. `id_commercial_1/2` = représentant. `actif`, `niveau_class` (enum A→G). Vidée/réinsérée chaque nuit. |
| `ref_client_contact` (12) | Contacts d'un magasin | 🔑 `id_ref_client` (= id_as400). `type_poste` enum (PDG, Directeur, Chef de département, Chef de rayon + DPH/Textile/PEM/Accessoires Animaux, Employé de rayon). |
| `ref_client_infos` (11) | Infos complémentaires CRM | 🔑 `id_ref_client`. `id_user_dr` (directeur régional). |
| `ref_client_infos_backup` (10) | Sauvegarde de la précédente | — |
| `ref_client_periodicite` (7) | Périodicité de visite d'un client | 🔑 `id_client_as400`. `id_periodicite` → `periodicite.id`. ⚠️ peut valoir 0 (= aucune). |
| `ref_client_centrale` (6) | Rattachement client ↔ centrale | `code_client`, `code_centrale` (int). |
| `ref_client_remarque` (8) | Remarques terrain (via APK) | 🔑 `id_as400`, `id_repr`, `id_apk`. |
| `periodicite` (5) | Nomenclature périodicités | ids **1 à 6** (2×/sem, 1×/sem, /2 sem, /3 sem, /mois, +1 mois). |
| `ref_centrale` (10) | Centrales/sous-centrales d'achat | ~2M lignes. |
| `ref_region` (7) | Régions commerciales | 6 lignes. |
| `ref_secteur` (8) | Secteurs (rattachés à une région) | `id_region`. |
| `ref_structure_commerciale` (7) | Structure commerciale (nature/valeur) | — |

### 4.2 Articles / produits / tarifs
| Table | Rôle | Points clés |
|---|---|---|
| `ref_article` (26) | Référentiel articles (importé AS400) | 🔑 `id_as400`. ~823k lignes, réimporté. `actif`, `retour_autorise`. |
| `ref_article_infos` (4) | Détails/avantages produit (CRM) | 🔑 `id_as400`. |
| `ref_article_stock` (4) | Stock par article | 🔑 `id_as400`. |
| `ref_article_lot` (3) | Numéros de lot | `id_as400_article`. |
| `ref_article_comp` (5) | Articles composés | `id_as400` ↔ `id_as400_comp`. |
| `ref_article_switch` (6) | Règles de substitution (rupture) | `id_as400` ↔ `id_switch`, `seuil`. |
| `ref_famille` (7) / `ref_gamme` (7) / `ref_marque` (6) | Hiérarchie marque → gamme → famille | chaînés par `id_marque`, `id_gamme`. |
| `ref_tarif` (7) | Tarifs par article | `code_article`, `tarif`. ~424k lignes. |
| `ref_promo` (9) | Promotions | `id_as400`. |
| `pem_article` (5) | Articles PEM (mise en avant) | `id_as400`, `actif`. |
| `strats_pem` (6) / `strats_pem_line` (10) | Stratégies PEM et leurs lignes | `id_strat_pem`. |

### 4.3 Commandes
| Table | Rôle | Points clés |
|---|---|---|
| `commande_apk` (26) | Commandes saisies sur l'appli mobile (APK) | 🔑 `id_apk`, `id_magasin`, `user` (= login). `statut`, `externe`, `total`. ~121k lignes. |
| `commande_apk_produits` (7) | Lignes de commande APK | `id_commande_apk`. ~5,4M lignes. |
| `commandes_as400` (36) | Commandes/lignes remontées de l'AS400 | `numero`, `code_client_cmd`, `id_repr`, `code_article`. ~7,4M lignes. Lien vers CRM via `id_commande_apk`. |
| `commandes_as400_total` (6) | Totaux de commande AS400 | `numero`, `total`. |
| `commande_colis` (9) / `commande_colis_codes` (6) | Colisage et codes scannés | `id_commande_colis`. |

### 4.4 Facturation
| Table | Rôle | Points clés |
|---|---|---|
| `ref_facture` (38) | Lignes de facture (importées AS400) | 🔑 `id_client_cmd`/`id_client_livre`/`id_client_facture`, `id_rep`, `id_article`, `no_facture`, `no_crm` (lien commande CRM). **~6,5M lignes** — la plus grosse table métier. |

### 4.5 Visites / tournées / planning
| Table | Rôle | Points clés |
|---|---|---|
| `visite` (20) | Visite d'un magasin par un promoteur | 🔑 `id_client`, `id_commande`, `id_visite` (id APK), `id_user`. `pem`, `is_juva`. ~205k lignes. |
| `visite_dn` (10) | Distribution numérique relevée en visite | `id_visite`, `id_client`, `type` (ABC/concurrence). ~1,1M lignes. |
| `visite_photo` (7) | Photos de visite | `id_visite`. ~1,6M lignes. |
| `visite_step` (4) | Étapes/chronométrage de visite | `id_visite`. ~1,68M lignes. |
| `visite_promo` (3) | Promos vues en visite | `id_visite`, `id_as400`. |
| `visite_deballage` (5) | Déballage (timer début/fin) | `id_visite`. |
| `visite_questionnaire` (10) | Questionnaire de visite | `id_visite`. |
| `visite_no_pem` (4) | Motif d'absence de PEM | `id_visite`. |
| `planning` (10) | Visites planifiées (occurrences datées) | 🔑 `id_repr` (**= user.id**, cf. §2.3), `id_magasin`, `date_passage`, `id_plannification` (lien récurrence). |
| `plannification` (11) | Récurrences de planning | 🔑 `unique_id`, `id_repr` (varchar), `id_client`. `days`, `rec` (fréquence), `start` (semaine), `annee`. |
| `tournee` (10) | Tournées type d'un représentant | `id_repr`, `id_as400`, `days`, `weeks`, `start`, `annee`. ~65k lignes. |
| `tournee_a_valider` (7) | Tournées en attente de validation | `id_repr`, `tournee` (payload sérialisé). |
| `previsionnel` (7) / `previsionnel_ligne` (12) | Prévisionnel hebdo par utilisateur | `id_user`, `id_prevision`, `jour`. |
| `jours_off` (3) | Jours fériés / non travaillés | `date_off`. |
| `kilometres` (7) | Relevés kilométriques | `id_repr`. |

> Toutes les tables `*_juva` (`visite_juva`, `visite_dn_juva`, `visite_photo_juva`, `visite_step_juva`, `visite_promo_juva`, `visite_deballage_juva`, `visite_questionnaire_juva`, `visite_no_pem_juva`) sont une **réplique quasi identique** du circuit visite pour la filière Juva. Candidat n°1 à la mutualisation lors de la refonte (ajouter une colonne `filiere` plutôt que dupliquer les tables).

### 4.6 Prospection
| Table | Rôle | Points clés |
|---|---|---|
| `prospect` (33) | Prospects (futurs clients) | `appid`, `id_user`, `id_as400` (une fois converti en client), `code_client`. |
| `prospect_contact` (10) | Contacts prospect | `id_prospect`. |
| `prospect_horaires` (9) / `prospect_jours` (10) | Horaires/jours d'ouverture | `id_prospect`. |
| `prospection` (8) | Sessions de prospection | `id_user`, `id_prospect`, `appid`. |
| `prospection_dn` (12) / `prospection_step` (9) / `prospection_photo` (9) | Relevés DN, étapes, photos | `id_prospection`. |
| `objectifs` (8) / `objectifs_prospection` (8) | Objectifs mensuels de CA | `id_repr`, `annee`, `mois`. |

### 4.7 Utilisateurs / sécurité
| Table | Rôle | Points clés |
|---|---|---|
| `user` (20) | Utilisateurs CRM | 🔑 `login` (unique), `id_repr`, `id_profile`, `secteur`, `actif`. |
| `secu_profile` (9) | Profils/rôles | `admin`, `homepage`. (Promoteur=1, Admin=2, Chef secteur=4, Direction=5, DR=6, ADV=7…) |
| `secu_profile_droit` (3) | Association profil ↔ droit (N–N) | `id_profile`, `id_droit`. |
| `secu_droit` (6) | Droits d'accès | `id_categorie`. |
| `secu_droit_categorie` (2) | Catégories de droits | — |
| `hierarchie` (3) | Rattachement DR ↔ représentant | `id_dr`, `id_repr`. |
| `user_secteur` (3) | Association utilisateur ↔ secteur | — |
| `user_device` (11) | Appareils mobiles connectés | `id_user`, infos device. |
| `user_location` (7) | Géolocalisation des utilisateurs | `id_user`, `latitude`/`longitude`. |

### 4.8 Statistiques
| Table | Rôle | Points clés |
|---|---|---|
| `stat_ca_client` (5) | CA par client / mois | `id_as400`, `annee`, `mois`, `ca`. ~386k lignes. |
| `stat_delta_ca_client` (4) | Écart CA N / N-1 par client | `id_as400`. |
| `stat_promoteur_ca` (4) | CA facturé par promoteur / date | `id_repr` (int). **AUTO_INCREMENT ~15M**. |
| `stat_promoteur_cumul_ca` (10) | Cumuls + classement promoteur | `id_repr`, `position`, `perc_obj`. |
| `stat_promoteur_visite` (7) | Temps de visite/transport par visite | `id_repr`, `id_visite`. **AUTO_INCREMENT ~70M** — table la plus volumineuse : à auditer (rétention ?). |

### 4.9 Filière Juva (référentiels dédiés)
`juva_client` (17), `juva_commande` (19), `juva_commandeligne` (5), `juva_produit` (20), `juva_produit_backupimport` (20), `juva_enseigne` (4), `juva_ref` (4), `juva_statuterp` (4), `ref_gammes_juva` (5), `ref_marques_juva` (4), `ref_concurence_gamme_juva` (6), `ref_concurence_marque_juva` (6).
> ⚠️ Ces tables (majoritairement sans `id`/PK explicite sur `juva_client`, `juva_produit`…, en `utf8mb4`) forment un système parallèle. À rationaliser.

### 4.10 Divers / système
| Table | Rôle |
|---|---|
| `messagerie` (9) | Messagerie interne (`id_from`/`id_to`). |
| `news` (11) | Actualités ABC. |
| `alert` (5) / `alert_type` (4) / `alerte_user` (5) | Alertes. |
| `task` (15) | Tâches (target/id_target génériques). |
| `lang` (4) / `lang_trad` (4) | Internationalisation (FR par défaut). |
| `page_name` (3) | Libellés de pages. |
| `apk_select_options` (7) | Options de listes déroulantes de l'appli mobile. |
| `logs_apk` (7) | Logs applicatifs mobile (~495k lignes). |
| `log_user_login` (4) / `log_user_navigation` (4) | Journaux connexion/navigation. |
| `log_replacement` (9) | Journal des substitutions d'articles. |
| `uploaded_files` (8) / `downloads` (6) / `dd_history` (4) | Fichiers et téléchargements. |
| `bordereaux_index` (3) | Index des bordereaux. |
| `retours_produits_apk` (12) | Retours/rappels produits (via APK), enum action (detruit/recupere/absent). |
| `cs_visite_commerciale` (9) / `cs_visite_commerciale_steps` (6) | Visites commerciales chef de secteur. |
| `rapport_activite` (6) / `rapport_activite_ligne` (12) | Rapports d'activité hebdo (nouvelle fonctionnalité). |
| `kilometres`, `objectifs`… | (cf. sections métier). |
| `test` (4) | Table de test — **à supprimer**. |
| `importAS400_chrono` (5) / `importAS400_headers` (3) | Chronométrage et en-têtes d'import. |

---

## 5. Tables volumineuses (à surveiller pour la refonte / perfs)

| Table | Ordre de grandeur (AUTO_INCREMENT) |
|---|---|
| `stat_promoteur_visite` | ~70 M |
| `stat_promoteur_ca` | ~15 M |
| `commandes_as400` | ~7,4 M |
| `ref_facture` | ~6,5 M |
| `commande_apk_produits` | ~5,4 M |
| `ref_client` | ~2,36 M (churn dû au ré-import quotidien) |
| `ref_centrale` | ~2 M |
| `visite_step` | ~1,68 M |
| `visite_photo` | ~1,6 M |
| `visite_dn` | ~1,1 M |
| `referentiels` | ~473 k |
| `ref_tarif` | ~424 k |

> L'AUTO_INCREMENT surestime souvent le nombre de lignes réelles (surtout `ref_client`, `ref_article` régénérées), mais donne l'ordre de grandeur de la volumétrie historique.

---

## 6. Synthèse des chantiers identifiés pour la refonte

1. **Persistance CRM vs données AS400** : arrêter de vider `ref_client` (ou séparer clairement les champs CRM persistants). Généraliser le mécanisme de `TABLE 129` (et la renommer).
2. **Identifiants** : unifier `id_repr` (type + sémantique), et bannir l'usage de `ref_client.id`/`ref_article.id` comme références (utiliser `id_as400`).
3. **Intégrité** : introduire de vraies clés étrangères, ou au minimum des contraintes/nettoyages d'orphelins.
4. **Doublons `*_juva`** : fusionner via une colonne `filiere`.
5. **Charset** : migrer tout en `utf8mb4`.
6. **Nettoyage** : supprimer `test`, `ref_client_infos_backup`, `juva_produit_backupimport`, auditer la rétention de `stat_promoteur_visite` (~70M).
7. **Nommage** : `TABLE 129` et quelques colonnes en codes AS400 bruts (`HS*`) à normaliser.
