# Tables importantes de l'application `gescom` et colonnes inutilisées

> Analyse au niveau **colonne** des tables métier importantes, avec repérage des
> colonnes **non exploitées par l'application**.
> Complète `docs/SCHEMA_BDD.md` (qui décrit la base par domaine, sans le détail colonne).

## Méthodologie

- Usage de chaque colonne mesuré par recherche (mot entier) dans le code **applicatif** :
  `partial/`, `dist/js/` (hors `vendor`/plugins/min/map), `api/`, `_class/`
  (hors `importAS400.class.php`).
- Croisement avec les tables de mapping d'import `struc_*` pour distinguer :
  - **morte** : jamais alimentée ni lue ;
  - **alimentée mais jamais lue** : écrite par l'import AS400/Minos mais aucun code ne la consomme.
- Convention ci-dessous :
  - ✅ utilisée ;
  - 🟠 **alimentée par l'import mais jamais lue par l'appli** ;
  - ❌ **morte** (ni écrite ni lue par du code exploité).

Les tables jugées **non utilisées** ne sont pas décrites ici (voir la liste finale).

---

## 1. Clients / magasins

### `ref_client` — référentiel magasins (importé AS400, vidé/réinséré chaque nuit)
Clé métier : `id_as400` (l'`id` interne est instable, régénéré à chaque import).

| Colonne | Statut | Remarque |
|---|---|---|
| `id`, `id_as400` | ✅ | `id_as400` = clé de jointure réelle |
| `enseigne`, `raison_sociale` | ✅ | |
| `adresse1`, `adresse2`, `adresse3` | ✅ | |
| `code_postal`, `code_postal_2`, `ville` | ✅ | CP scindé en 2 (fichier Minos) |
| `pays`, `langue`, `devise` | ✅ | |
| `siret` | ✅ | |
| `contact_1`, `contact_2`, `contact_3` | ✅ | correspondants Minos (peu lus) |
| `tel1`, `tel2` | ✅ | |
| `id_commercial_1`, `id_commercial_2` | ✅ | représentants |
| `ean_client` | ✅ | |
| `statut_commande_par`, `statut_livre`, `statut_facture` | ✅ | |
| `actif` | ✅ | réappliqué depuis `TABLE 129` après import |
| `niveau_class` | ✅ | note CRM (A→G), persistée dans `TABLE 129` |
| `id_createur` | ✅ | clients créés manuellement |
| `date_creation`, `date_modification`, `deleted` | ✅ | |
| **`forme_entreprise`** | 🟠 | mappée à l'import (FRMENT) mais **jamais lue** |
| **`code_region`** | 🟠 | mappée à l'import mais **jamais lue** ; mapping douteux (chevauche EAN) |

### `ref_client_contact` — contacts d'un magasin
| Colonne | Statut | Remarque |
|---|---|---|
| `id`, `id_ref_client` (= id_as400), `id_user` | ✅ | |
| `prenom`, `nom`, `poste`, `type_poste` | ✅ | `type_poste` = enum (PDG, Directeur, Chef de rayon…) |
| `fixe`, `portable`, `mail` | ✅ | |
| `deleted` | ✅ | |
| **`login_createur`** | ❌ | **morte** (jamais écrite ni lue) |

### `ref_client_infos` — infos complémentaires CRM
Toutes les colonnes sont utilisées : `id_ref_client`, `num_juva`, `type_cmd`,
`cli_avant_ouverture`, `flash`, `cmd_labell`, `chaussures_secu`, `attestation`, `cni`, `id_user_dr`.

### `ref_client_periodicite` — périodicité de visite
Toutes utilisées : `id_client_as400`, `id_periodicite`, `id_user`, `date_creation`, `date_modification`, `deleted`.

---

## 2. Articles / tarifs

### `ref_article` — référentiel articles (importé Minos, fichier `ART`)
Clé métier : `id_as400`.

| Colonne | Statut | Remarque |
|---|---|---|
| `id`, `id_as400` | ✅ | |
| `id_ita` | ✅ | code article Italie (recherche + fiche) |
| `libelle`, `gencode` | ✅ | |
| `code_famille`, `sous_famille`, `type_article` | ✅ | résolus via `referentiels` |
| `code_marque`, `code_tva`, `gamme` | ✅ | |
| `statut`, `sous_statut` | ✅ | `sous_statut = RAPPE` → `retour_autorise` |
| `famille_acd`, `sous_famille_acd`, `famille_plan` | ✅ | |
| `zparm_pcb` | ✅ | colisage utilisé en commande |
| `actif`, `date_creation`, `date_modification`, `deleted` | ✅ | |
| `retour_autorise` | ✅ | calculé à l'import depuis `sous_statut` |
| **`zparm_nb_uc`** | 🟠 | mappée (ZNBUC) mais **jamais lue** |
| **`zparm_x_pcb`** | 🟠 | mappée (ZPCB2) mais **jamais lue** |
| **`zparm_spcb`** | 🟠 | mappée (ZSPCB) mais **jamais lue** |
| **`id_famille`** | ❌ | **morte** : non alimentée par l'import, écrite seulement par `ref::createArticle()` (jamais appelé). Index `id_famille` inutile. |

### `ref_article_infos` — détails/avantages produit (CRM)
Toutes utilisées : `id_as400`, `details`, `avantages`.

### `ref_article_stock` — stock par article
| Colonne | Statut | Remarque |
|---|---|---|
| `id`, `id_as400`, `stock` | ✅ | |
| **`last_update`** | 🟠 | maintenue automatiquement (`ON UPDATE`) mais **jamais lue** |

### `ref_article_switch` — substitution en cas de rupture
| Colonne | Statut | Remarque |
|---|---|---|
| `id`, `id_as400`, `id_switch`, `seuil`, `id_user` | ✅ | |
| **`last_update`** | 🟠 | jamais lue |

### `ref_tarif` — tarifs par article
| Colonne | Statut | Remarque |
|---|---|---|
| `id`, `code_article`, `tarif` | ✅ | |
| `date_creation`, `date_modification`, `deleted` | ✅ | |
| **`code_tarif`** | 🟠 | mappée à l'import mais **jamais lue** |

---

## 3. Commandes

### `commande_apk` — commandes saisies sur l'appli mobile
| Colonne | Statut | Remarque |
|---|---|---|
| `id`, `id_apk`, `id_magasin`, `user` | ✅ | `user` = login |
| `date_creation_apk`, `date_liv_estimee`, `date_next_cmd`, `queue_date` | ✅ | |
| `no_cmd_client`, `no_visit`, `no_visit_reason`, `fp_raison` | ✅ | |
| `statut`, `filename`, `total`, `total_reel` | ✅ | |
| `remarque`, `externe`, `externeMail` | ✅ | |
| `no_facture`, `no_commande`, `bl` | ✅ | |
| `date_creation`, `date_modification`, `deleted` | ✅ | |
| **`no_visite_client`** | ❌ | **morte** (jamais écrite ni lue) — doublon apparent de `no_visit` |

### `commande_apk_produits` — lignes de commande APK (~2,1M lignes)
Toutes utilisées : `id_commande_apk`, `id_produit`, `quantite`, `pcb`, `prix_unitaire`, `prix_total`.

### `commandes_as400` — commandes/lignes remontées de l'AS400 (~2,7M lignes)
Toutes les colonnes sont **alimentées par l'import** (mapping `struc_commandes_as400`).
Colonnes utilisées côté appli : `numero`, `annee/mois/jour_annul`, `code_client_cmd`,
`raison_sociale_cmd`, `id_repr`, `repr`, `cs`, `dr`, `code_article`, `libelle_article`,
`gamme`, `marque`, `famille`, `famille_acd`, `quantite`, `montant`, `type_cmd`,
`checky/checkm/checkd`, `id_commande_apk`, `deleted`…

Colonnes **alimentées mais jamais lues** (🟠) :

| Colonne | Remarque |
|---|---|
| `id_cs` | code chef de secteur — jamais lu (seul `cs` l'est) |
| `code_dz`, `dz` | directeur de zone — non exploités |
| `code_dr` | code directeur régional — non lu (seul `dr` l'est) |
| `id_repr2`, `repr2` | 2ᵉ représentant — non exploités |
| `dpt` | département — non exploité |
| `gamme_dang` | gamme « dangereux » — non exploité |
| `no_ligne` | numéro de ligne — non exploité |

### `commandes_as400_total` — totaux de commande AS400
Utilisée (`numero`, `total`).

### `commande_colis` / `commande_colis_codes` — colisage
Utilisées (`id_client`, `no_logis`, `colis`, `produits`, `id_visite`…).

---

## 4. Facturation

### `ref_facture` — lignes de facture (importées AS400, ~6,3M lignes, plus grosse table)
Toutes les colonnes sont **alimentées par l'import** (mapping `struc_ref_facture`).
Colonnes utilisées : `no_commande`, `no_facture`, `annee/mois/jour_facture`,
`id_client_cmd`, `id_client_livre`, `client_livre`, `id_client_facture`, `id_centrale`,
`id_rep`, `nom_rep`, `dir_region`, `id_article`, `article`, `gamme`, `marque`, `famille`,
`famille_acd`, `qte_facturee`, `montant_facture`, `facture_avoir`, `numero_bl`, `no_crm`.

Colonnes **alimentées mais jamais lues** (🟠) :

| Colonne | Remarque |
|---|---|
| `client_cmd`, `client_facture` | libellés client (seuls les `id_*` sont lus) |
| `id_sscentrale`, `id_scentrale` | sous-centrale / centrale intermédiaire |
| `id_chef_secteur`, `chef_secteur` | chef de secteur |
| `id_dir_zone`, `dir_zone` | directeur de zone |
| `id_dir_region` | code DR (seul le libellé `dir_region` est lu) |
| `id_rep2`, `nom_rep2` | 2ᵉ représentant |
| `dept` | département |
| `gamme_dang` | gamme « dangereux » |

> ⚠️ Vu la volumétrie (~6,3M lignes), ces colonnes mortes représentent un gain
> significatif en espace/perf si supprimées (après retrait des mappings `struc_ref_facture`).

---

## 5. Visites

### `visite` — visite d'un magasin par un promoteur (~162k lignes)
Toutes utilisées : `id_user`, `id_commande`, `id_visite`, `no_cmd`, `no_cmd_reason`,
`id_client`, `pmc_state`, `pmc_coms`, `dn_abc`, `dn_concurence`, `queue_date`, `pem`,
`id_visite_linked`, `alerte_raison`, `alerte_obs`, `is_juva`, `date_creation`, `date_modification`, `deleted`.

### `visite_dn` — distribution numérique relevée (~1M lignes)
Toutes utilisées : `id_client`, `id_visite`, `type`, `marque`, `gamme`, `metrage`.

### `visite_photo` — photos de visite (~1,5M lignes)
Toutes utilisées : `id_visite`, `file`, `size`, `id_visite_apk`, `app_name`.

> Les autres tables `visite_*` (`visite_step`, `visite_promo`, `visite_deballage`,
> `visite_questionnaire`, `visite_no_pem`) suivent le même schéma et sont utilisées.
> Les répliques `*_juva` dupliquent ce circuit (candidates à mutualisation).

---

## 6. Planning / tournées

### `planning` — visites planifiées (occurrences datées)
Toutes utilisées : `id_repr` (⚠️ contient `user.id`, pas `user.id_repr`), `id_magasin`,
`date_passage`, `green`, `raison`, `id_plannification`, `date_creation`, `date_modification`, `deleted`.

### `plannification` — récurrences de planning
Toutes utilisées : `unique_id`, `id_repr`, `id_client`, `days`, `rec`, `start`, `annee`…

### `tournee` — tournées type d'un représentant
Toutes utilisées : `id_repr`, `id_as400`, `days`, `weeks`, `start`, `annee`…

---

## 7. Utilisateurs / sécurité

### `user` — utilisateurs CRM
Toutes utilisées : `id_profile`, `login`, `mail`, `token`, `token_expires`, `name`,
`givenname`, `displayname`, `dn`, `uid`, `poste`, `secteur`, `app_db_update`, `api_query`,
`apk_version`, `sync`, `id_repr`, `actif`, `deleted`.

### `secu_profile` — profils/rôles
Toutes utilisées : `libelle`, `defaut`, `protected`, `admin`, `homepage`…
Profils : Promoteur=1, Administrateur=2, Chef de secteur=4, Direction=5,
Directeur Régional=6, Service ADV=7, Marketing=8, Resp. merch.=9, Promoteur+Juva=10, SERVICE ADV +=11.

> `secu_droit`, `secu_droit_categorie`, `secu_profile_droit` : système de droits, utilisées.

---

## 8. Prospection

### `prospect` — prospects (futurs clients)
Toutes utilisées (nombreuses colonnes : `appid`, `ptype`, `step`, `enseigne`, `nom`,
`adresse`, `cp`, `ville`, `telephone`, `email`, `code_centrale`, `code_scentrale`,
`code_magasin`, `type_rdv`, `ca_potentiel`, `id_user`, `code_client`, `id_as400`, `siret`,
`cnud`, `no_tva`, adresse de livraison `al_*`, `id_commercial`…).

> Tables liées utilisées : `prospect_contact`, `prospect_horaires`, `prospect_jours`,
> `prospection`, `prospection_dn`, `prospection_step`, `prospection_photo`.

---

## 9. Retours produits

### `retours_produits_apk`
Toutes utilisées : `user_id`, `id_bordereau`, `code_magasin`, `num_lot`, `scan_produit`,
`code_produit`, `quantite`, `action_produit`, `date_retour`, `photo_path`, `created_at`.

---

## 10. Statistiques

### `stat_ca_client` — CA par client / mois
Toutes utilisées : `id_as400`, `annee`, `mois`, `ca`.

### `stat_promoteur_visite` — temps de visite/transport (table la plus volumineuse)
Toutes utilisées : `id_repr`, `date_stat`, `id_visite`, `temps_init`, `temps_visite`, `temps_transport`.

> `stat_delta_ca_client`, `stat_promoteur_ca`, `stat_promoteur_cumul_ca` : utilisées.

---

## 11. Divers utilisés

- `task` — tâches (toutes colonnes utilisées).
- `news` — actualités (toutes utilisées).
- `messagerie` — messagerie interne (toutes utilisées).
- `referentiels` / `referentiels_nature` — nomenclatures AS400 (référentiels résolus partout).
- `TABLE 129` — persistance CRM du statut `actif`/`niveau_class` (réappliquée après import).
- `pem_article`, `strats_pem`, `strats_pem_line` — module PEM (utilisées).
- Filière Juva : `juva_produit`, `juva_client`, `juva_commande`, `juva_commandeligne`,
  `juva_enseigne`, `juva_statuterp` — utilisées.
  Dans `juva_produit`, `profondeur`, `ChampExt19`, `ChampExt20` sont **mortes/inexploitées**.

---

## 12. Synthèse — colonnes à supprimer (candidates)

| Table | Colonne(s) | Type |
|---|---|---|
| `ref_client` | `forme_entreprise`, `code_region` | alimentées, jamais lues |
| `ref_client_contact` | `login_createur` | morte |
| `ref_article` | `zparm_nb_uc`, `zparm_x_pcb`, `zparm_spcb` | alimentées, jamais lues |
| `ref_article` | `id_famille` (+ index) | morte |
| `ref_article_stock` | `last_update` | jamais lue |
| `ref_article_switch` | `last_update` | jamais lue |
| `ref_tarif` | `code_tarif` | alimentée, jamais lue |
| `commande_apk` | `no_visite_client` | morte |
| `commandes_as400` | `id_cs`, `code_dz`, `dz`, `code_dr`, `id_repr2`, `repr2`, `dpt`, `gamme_dang`, `no_ligne` | alimentées, jamais lues |
| `ref_facture` | `client_cmd`, `client_facture`, `id_sscentrale`, `id_scentrale`, `id_chef_secteur`, `chef_secteur`, `id_dir_zone`, `dir_zone`, `id_dir_region`, `id_rep2`, `nom_rep2`, `dept`, `gamme_dang` | alimentées, jamais lues (impact fort : ~6,3M lignes) |
| `juva_produit` | `profondeur`, `ChampExt19`, `ChampExt20` | mortes/inexploitées |

> Pour toute colonne « alimentée par l'import », **retirer d'abord son entrée dans la table
> de mapping `struc_*`** avant le `ALTER TABLE`, sinon l'import échouera.

---

## 13. Tables apparemment non utilisées (non décrites — à confirmer)

Non référencées dans le code applicatif (candidates à suppression / archivage) :

- `ref_client_infos_backup`, `juva_produit_backupimport` — sauvegardes obsolètes.
- `juva_ref` — 0 ligne, non référencée.
- `test` — table de test.
- `importAS400_chrono`, `importAS400_headers` — non référencées.
- `ref_region`, `ref_secteur`, `ref_structure_commerciale`, `user_secteur` — aucune
  référence littérale trouvée (à vérifier : possible usage via requêtes construites dynamiquement).

> Les tables de mapping `struc_*` sont bien **utilisées** (référencées dynamiquement via
> `"struc_".$table` dans l'import), même si une recherche littérale ne les remonte pas.
