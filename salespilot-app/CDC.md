# Cahier des charges — application mobile SalesPilot

Version 0.2 — 26/10/2026 — **à valider**

> Document destiné à l'équipe qui concevra et développera l'application, et aux décideurs qui la valident. Les contraintes techniques détaillées de l'API sont dans [ANNEXE-API.md](ANNEXE-API.md).
>
> **Évolutions de la v0.2** : MVP recentré sur le travail quotidien du promoteur ; tournée du jour en P1 et page d'accueil ; séparation ABC Sales / ABC Pilot précisée (rôle du chef de secteur dans chaque espace, incohérence sur les promoteurs levée) ; règles hors ligne détaillées ; brouillons et trois états de visite ; prise de commande simplifiée ; sécurité des données locales ; critères de validation mesurables.

---

## 1. Contexte et objectifs

### 1.1 La plateforme
ABC Cosmétique dispose d'une plateforme commerciale unique, **SalesPilot ABC**, composée de :
- **ABC Sales** : espace terrain (web) — magasins, visites, commandes, catalogue, promotions.
- **ABC Pilot** : espace de pilotage et d'encadrement (web) — équipes, prospection, alertes, administration.
- **Une API et une base de données communes**, avec une authentification unique par l'Active Directory (AD) de l'entreprise.

L'application mobile est le **troisième accès** à cette plateforme : elle ne crée pas de données à part, elle utilise la même API et les mêmes règles de rôles. Comme le web, elle comporte **deux espaces, ABC Sales et ABC Pilot**, accessibles selon les droits (voir §3.0).

### 1.2 Pourquoi un mobile
Les promoteurs des ventes travaillent en magasin, souvent avec une mauvaise couverture réseau. Il leur faut voir leur tournée, saisir une visite, photographier un linéaire, prendre une commande et consulter une fiche magasin **sur place, même sans réseau**. L'encadrement (chefs de secteur, directeurs régionaux) doit ensuite suivre sa tournée et son équipe en déplacement.

### 1.3 Objectifs
1. Permettre la **saisie terrain complète** (visite, photos, commande) hors ligne, avec une synchronisation fiable et **sans perte ni doublon**.
2. Donner au promoteur **l'information utile en visite** : tournée du jour, fiche magasin, promotions, rappels produits.
3. Rendre l'application **supervisable** par l'administrateur : quel téléphone est à jour, lequel a des données bloquées, quelle version tourne.
4. Donner ensuite à l'encadrement **le suivi de sa tournée, de son équipe et de la prospection**.

### 1.4 Hors périmètre (cette version)
- Administration de la plateforme (utilisateurs, imports, configuration) : elle reste dans ABC Pilot sur le web.
- Édition du catalogue, des promotions et du questionnaire de visite : web uniquement.
- Imports ERP (Minos / AS400) : serveur uniquement.

### 1.5 Principe de livraison : commencer par le quotidien du promoteur
Le premier lot ne couvre que **cinq usages du promoteur** : consulter ses magasins, voir sa tournée du jour, réaliser une visite avec photos, prendre une commande, et synchroniser ses données de façon fiable. Les tableaux de bord détaillés, les fonctions de direction et la prospection avancée viennent **après**, une fois la saisie terrain éprouvée.

---

## 2. Utilisateurs et rôles

Les rôles existent déjà dans l'API et déterminent ce que chacun voit. L'application les reprend tels quels.

| Rôle (valeur API) | Utilisateur | Espaces | Usage principal sur mobile |
|---|---|---|---|
| `COMMERCIAL` | Promoteur des ventes | Sales | **Cœur de cible** : tournée, visites, commandes, magasins de son portefeuille |
| `CHEF_SECTEUR` | Chef de secteur (CS) | Sales + Pilot | Ses propres visites (Sales) ; sa tournée d'encadrement, visites commerciales, prospection et suivi de ses promoteurs (Pilot) |
| `DIRECTEUR_REGIONAL` | Directeur régional (DR) | Sales + Pilot | Idem CS sur sa région, relance de son équipe |
| `DIRECTION` | Direction | Sales + Pilot | Consultation (tableaux de bord, équipe) |
| `ADMIN` | Administrateur | Sales + Pilot | Accès complet en lecture, aucune administration sur mobile |
| `ADV`, `MARKETING` | Services siège | Sales | Consultation terrain : magasins, commandes et statut de livraison (ADV), catalogue et promotions (Marketing) ; périmètre à préciser (§10) |

**Un seul compte, un seul identifiant** : le login AD. L'application donne accès aux espaces autorisés par le rôle reçu à la connexion (voir §3.0).

---

## 3. Fonctionnalités

Priorités : **P1** indispensable au premier lot (MVP) · **P2** lot suivant · **P3** plus tard.
Rôles : **Pro** = promoteur, **Enc.** = encadrement (CS, DR), **Dir.** = direction/admin.

### 3.0 Une application, deux espaces : ABC Sales et ABC Pilot

L'application reprend la structure de la plateforme web : **une seule application « SalesPilot »**, avec **deux espaces** accessibles **selon les droits** de l'utilisateur.

| Espace | Contenu | Équivalent web |
|---|---|---|
| **ABC Sales** — terrain | Tournée du jour, magasins, visites, commandes, catalogue, promotions, notifications | ABC Sales |
| **ABC Pilot** — pilotage | Tournée d'encadrement, visites commerciales, prospection et pipeline, équipe, relances, tableaux de bord de direction | ABC Pilot |

**Accès par rôle** (mêmes règles que le web : **ABC Sales est accessible à tous les rôles**, ABC Pilot est réservé à l'encadrement) :

| Rôle | ABC Sales | ABC Pilot | Changement d'espace |
|---|---|---|---|
| `COMMERCIAL` (promoteur) | Oui | **Non** | Aucun : il arrive directement dans ABC Sales |
| `CHEF_SECTEUR`, `DIRECTEUR_REGIONAL`, `DIRECTION`, `ADMIN` | Oui | **Oui** | Oui |
| `ADV`, `MARKETING` | **Oui** | Non | Aucun : ils arrivent dans ABC Sales |

**Comportement**
- À la connexion, l'application ouvre **ABC Sales** (espace par défaut) ; le rôle est lu dans la réponse de connexion.
- Les rôles autorisés à ABC Pilot disposent d'un **sélecteur d'espace** (comme sur le web). Les autres rôles — **promoteurs, ADV, Marketing** — ne voient **ni le sélecteur ni aucun écran Pilot**.
- Chaque espace a sa **couleur**, comme sur le web : bleu marine pour ABC Sales, violet pour ABC Pilot, avec le même logo « SalesPilot ABC ».
- **Les droits sont aussi appliqués côté serveur** : masquer un écran ne suffit pas. L'API refuse déjà la plupart des routes de prospection et de tournées d'encadrement à un promoteur ; l'application ne fait qu'**épouser** ces règles.
- La **file d'envoi, le compteur d'éléments en attente et l'écran de synchronisation sont communs** aux deux espaces.

**Ce que fait le chef de secteur dans chaque espace**

| Espace | Actions du chef de secteur |
|---|---|
| **ABC Sales** | Voir **ses propres visites** du jour et les réaliser comme un promoteur (visite, photos, commande si besoin) ; consulter les magasins de son périmètre, le catalogue, les promotions et les rappels produits |
| **ABC Pilot** | Gérer **sa tournée d'encadrement** (étapes, requalification, prévision puis validation hebdomadaire) ; faire une **visite commerciale** ; suivre la **prospection** (pipeline, création, conversion) ; consulter **ses promoteurs** (planning, activité) ; consulter les indicateurs de son secteur |

Le directeur régional a les mêmes droits sur sa région, avec en plus la relance de son équipe. La direction et l'administrateur consultent, sans administration sur mobile.

**Prospection et promoteurs — incohérence levée.** L'API permet aujourd'hui à un promoteur d'ajouter une note, un appel, un e-mail ou une pièce jointe à un prospect, **mais pas de lister ni de créer un prospect**, et ABC Pilot lui est fermé. Ces droits ne peuvent donc pas servir. **Décision proposée : aucune fonction de prospection pour les promoteurs dans l'application** (leur fiche magasin couvre le terrain). Si le métier veut qu'ils signalent un prospect, ce sera un besoin à part, à spécifier avec l'API (voir §10).

*Alternative écartée par défaut : deux applications distinctes. Elle double la maintenance, les mises à jour et la supervision.*

---

### 3.1 Connexion et session — P1 — tous
- Connexion par identifiant et mot de passe AD (`POST /auth/login`).
- Jeton valable **8 heures** ; à l'expiration, l'utilisateur ressaisit son mot de passe. Les données déjà saisies hors ligne **ne sont jamais perdues** à l'expiration : elles restent en attente d'envoi (règles détaillées en §6.2).
- Déverrouillage local par **biométrie ou code** après la première connexion (P1, car il protège les données locales ; voir §6.2).
- Déconnexion : voir §6.2 (cas des données non envoyées).
- Message clair si le compte est désactivé (401) ou si l'AD est injoignable (503).

### 3.2 Accueil = tournée du jour — P1 — Pro (et tous les rôles dans ABC Sales)

L'accueil d'ABC Sales **est** la tournée du jour. Il affiche immédiatement :
- le **résumé** : nombre de visites prévues, réalisées, restantes ;
- la **liste des magasins à visiter**, dans l'ordre prévu, avec nom, ville, état (à faire / en cours / réalisée / en attente d'envoi) ;
- pour chaque magasin, un bouton **« Démarrer la visite »** (ou « Reprendre » si un brouillon existe) ;
- un bouton **« Visite non planifiée »** pour choisir un magasin hors tournée (motif libre ou prédéfini) ;
- le **compteur permanent d'éléments en attente d'envoi** (voir §4.3).

Données : les visites planifiées du promoteur pour la journée (planning). Un promoteur **ne crée pas** ses visites planifiées : elles sont posées par l'encadrement ou issues de récurrences ; il peut en revanche enregistrer une visite non planifiée. Une visite réalisée **solde automatiquement** la visite planifiée correspondante.

**Hors ligne** : la tournée du jour est préchargée et reste affichée avec ses dernières données connues, la date de mise à jour étant indiquée.

Les indicateurs plus détaillés (CA du mois, objectifs, évolution, produits en rappel) sont proposés en **P2** dans un écran dédié, pour ne pas alourdir l'accueil.

### 3.3 Magasins — P1 — Pro (et tous les rôles dans ABC Sales)
- Liste du **portefeuille** (périmètre du rôle), recherche par enseigne, raison sociale, code ; filtre actifs / inactifs.
- Indicateurs par magasin : jours depuis la dernière visite, périodicité, classe (A à G), état (ok / attention / alerte) ; CA du mois et évolution N-1 (P2).
- **Fiche magasin** : coordonnées, contacts, notes, dernières commandes et visites.
- Actions P1 : consulter, ajouter une **note** (avec identifiant anti-doublon) ; actions P2 : ajouter un contact, enregistrer un appel ou un e-mail.
- **Carte** des magasins géolocalisés et navigation vers l'adresse (P2).
- **Hors ligne** : la fiche, les contacts et les 20 dernières notes sont répliqués sur le téléphone.

### 3.4 Visites — P1 — Pro (et tous les rôles dans ABC Sales)

**Déroulé**
1. **Démarrer** depuis la tournée du jour, depuis une fiche magasin (visite non planifiée).
2. **Saisir** : motif, **distribution numérique** (ABC, concurrence, gondole haute, gondole basse), commentaire, **questionnaire dynamique** (cases à cocher, texte, nombre, note 1 à 5) défini côté web.
3. **Photographier** : plusieurs photos par visite, compressées avant envoi (limite serveur : 10 Mo, image uniquement).
4. **Terminer** : contrôle de la visite puis validation (voir ci-dessous).

**Brouillons et états d'une visite** — une visite passe par trois états, toujours visibles :

| État | Signification | Modifiable | Envoi |
|---|---|---|---|
| **Brouillon** | Visite commencée, non validée | Oui | Non |
| **Terminée, en attente d'envoi** | Validée par l'utilisateur, en file d'envoi | Oui, en la **rouvrant** (elle repasse en brouillon) tant qu'elle n'est pas envoyée | Automatique dès que le réseau le permet |
| **Synchronisée** | Reçue et confirmée par le serveur | Non (plus de modification depuis l'application) | Fait |

À ces trois états s'ajoute un **signal d'erreur** (« envoi refusé », avec le motif) quand le serveur refuse définitivement un élément.

- **Sauvegarde continue** : chaque saisie est écrite immédiatement sur le téléphone. Aucune action « enregistrer » n'est nécessaire.
- **Reprise automatique** : au prochain lancement de l'application, un bandeau propose « Visite en cours — Reprendre ». Un seul brouillon actif par magasin ; les brouillons plus anciens que 7 jours sont signalés pour être terminés ou abandonnés (jamais supprimés sans confirmation).
- **Contrôle avant validation** : l'utilisateur ne peut pas valider une visite incomplète par erreur. Un écran de synthèse affiche le magasin, le motif, le nombre de questions répondues sur le nombre total, le nombre de photos, et bloque la validation si un champ obligatoire manque (liste des champs obligatoires à fixer avec le métier, §10) ; il demande une confirmation explicite sinon.
- Si la visite était planifiée, elle est **soldée automatiquement** à l'enregistrement.
- **Visite commerciale** (Enc.) : rendez-vous ou non, objets traités, remplissage, compte rendu, prochaine visite, réponses au questionnaire ; horodatage de début et de fin. Disponible dans **ABC Pilot** (lot 3).
- **Historique** de ses visites (P2) ; le détail d'une visite passée nécessite un ajout API (voir annexe).

### 3.5 Commandes — P1 — Pro (et tous les rôles dans ABC Sales)

**Prise de commande rapide** sur un magasin :
- **Recherche instantanée d'articles** (libellé, code, code-barres, marque) avec résultats dès les premières lettres, depuis le catalogue local ; scan du code-barres en P2.
- **Quantités par colisage** : l'utilisateur saisit des **colis** (le colisage de chaque article est connu) ; l'application affiche la conversion en unités. Le serveur reçoit des unités entières.
- **Récapitulatif avant validation** : liste des lignes, quantités, total ; bouton de confirmation.
- **Alerte produit rappelé** : si un article est en rappel qualité ou retour autorisé, l'application l'indique à l'ajout **et** au récapitulatif, et demande une confirmation explicite.
- Identifiant de commande mobile de 4 à 10 caractères alphanumériques, généré par l'application, qui sert de clé anti-doublon et de pont avec la commande ERP.

**Prix** : l'API fournit un **prix indicatif** par article. Proposition : l'afficher avec la mention « prix indicatif, non contractuel » ; à valider avec le métier (§10).

**Modification d'une commande** :
- **Avant envoi** (brouillon ou terminée en attente d'envoi) : modifiable et supprimable depuis l'application.
- **Après envoi** : **aucune modification possible** depuis l'application (l'API ne propose ni modification ni annulation d'une commande mobile). Toute correction passe par l'ADV. L'écran l'indique clairement avant la validation d'envoi.

**Suivi** : « en attente d'envoi », « envoyée », « intégrée dans l'ERP » avec le numéro ERP une fois rapprochée. Consultation des **commandes ERP** et de leur statut de livraison (en préparation, expédiée, livrée partiellement, livrée ; transporteur et numéro de suivi) en P2.

### 3.6 Catalogue — P1 — tous · espace Sales
- Recherche d'articles par libellé, code, **code-barres** et **marque**, depuis le catalogue local (disponible hors ligne).
- Affichage : marque, gamme, famille, colisage, prix indicatif, promotion en cours, mise en avant (PEM), statut de rappel qualité.
- **Promotions et PEM** actives ; produits **en rappel qualité**.
- Scan du code-barres avec l'appareil photo : P2.

### 3.7 Planning et tournées
- **Tournée du jour (P1, Pro)** : voir §3.2.
- **Planning de la semaine (P2, Pro)** : consultation de ses visites planifiées sur la semaine.
- **Tournée d'encadrement (P3, Enc., espace Pilot)** : étapes personnelles (visite simple, accompagnement, rendez-vous, soirée étape, tâche administrative), requalification, **prévision puis validation hebdomadaire**.
- Planification et récurrences d'équipe : web uniquement en v1.
- Export vers l'agenda du téléphone (flux calendrier existant) : P3.

### 3.8 Prospection — P3 — Enc. uniquement · espace Pilot
- Liste et **pipeline** des prospects (nouveau, contacté, proposition, visite, négociation, gagné, perdu), création sur le terrain, fiche, historique, étape, motif de perte, **conversion en client**, opportunités (référencement, opération promotionnelle, mise en avant).
- Notes, appels, e-mails et pièces jointes sur un prospect ; visite de prospection depuis la fiche.
- **Aucune fonction de prospection pour les promoteurs** (voir §3.0).

### 3.9 Notifications — P2 — tous
- Liste des notifications, marquage lu / tout lu, compteur de non lues.
- **Notifications push** (P3, nécessite un ajout API) : relance de visite non faite, relance par la hiérarchie.
- **Enc.** : relancer un promoteur ou un membre de son équipe (selon les droits de l'API, §10).

### 3.10 Équipe, indicateurs et direction — P3 — Enc., Dir. · espace Pilot
- Mon équipe : promoteurs rattachés, planning d'activité, relance.
- Classement et tableaux de bord (CA, objectifs, magasins sans commande), tableau de bord de direction.
- Indicateurs du promoteur (CA du mois, objectifs, évolution sur 6 mois) : P2, dans ABC Sales.

### 3.11 Profil et état de l'application — P1 — tous · commun aux deux espaces
- Photo et nom (issus de l'AD), rôle, secteur.
- **Écran « Synchronisation »** : éléments en attente par type (visites, photos, commandes, notes…) et par état, dernière synchronisation réussie, erreurs avec bouton « Réessayer ».
- Version de l'application ; invitation à mettre à jour si une version minimale est exigée.

---

## 4. Hors ligne et synchronisation

C'est la partie la plus exigeante du projet. L'application doit rester **entièrement utilisable sans réseau** pour la saisie terrain.

### 4.1 Principes
1. **Base locale** sur le téléphone : référentiels répliqués (tournée du jour, magasins du portefeuille avec contacts et notes, catalogue, promotions, questionnaire) et saisies en attente.
2. **File d'envoi (« outbox »)** : chaque saisie est écrite localement avec un identifiant client unique (`idApk`), puis envoyée quand le réseau le permet. Un envoi rejoué ne crée **jamais de doublon** : le serveur reconnaît l'identifiant.
3. **Ordre d'envoi respecté** quand des éléments dépendent les uns des autres :
   - un prospect avant la visite ou l'étape qui le référence ;
   - une visite **avant ses photos** (les photos utilisent l'identifiant serveur de la visite) ;
   - une prévision hebdomadaire seulement s'il existe au moins une étape.
4. **Transparence** : chaque élément affiche son état (brouillon, en attente, envoyé, en erreur). Jamais d'échec silencieux.
5. **Reprise** : après une coupure, l'envoi reprend sans intervention ; les erreurs définitives (refus du serveur) sont conservées avec leur motif.

### 4.2 Règles pour les cas difficiles

| Situation | Règle |
|---|---|
| **Téléphone redémarré ou application tuée pendant une visite** | Toute saisie est écrite à l'instant. Au relancement, la visite revient en brouillon avec toutes ses données, et l'application propose de la reprendre. Aucune photo prise n'est perdue. |
| **Photos partiellement envoyées** | Chaque photo est un élément indépendant de la file, avec son propre identifiant. La visite apparaît **« synchronisée, photos en cours (n sur N) »** tant que toutes les photos ne sont pas confirmées. Les photos déjà reçues ne sont jamais renvoyées (anti-doublon) ; la photo locale n'est effacée qu'**après** la confirmation du serveur. Une photo refusée (trop lourde, format) reste sur le téléphone avec son motif. |
| **Changement d'utilisateur sur le même téléphone** | Les données locales et la file d'envoi sont **cloisonnées par utilisateur**. Le nouvel utilisateur ne voit rien de l'ancien. Les éléments non envoyés de l'ancien restent **chiffrés et bloqués**, et ne partent qu'à sa reconnexion (le serveur refuse l'envoi au nom d'un autre promoteur). Un message l'indique : « n éléments en attente appartiennent à un autre utilisateur ». |
| **Stockage presque plein** | Avertissement dès qu'il reste moins de 500 Mo ; **blocage de la prise de nouvelles photos** sous 100 Mo, avec explication ; proposition de libérer l'espace (photos déjà synchronisées, cache). **Aucune suppression silencieuse** de données non envoyées. |
| **Synchronisation interrompue** (réseau coupé, batterie, application fermée) | Reprise automatique et rejouable, avec attente progressive entre essais. Un élément en erreur définitive **ne bloque pas** les éléments indépendants ; il ne bloque que ceux qui en dépendent. |
| **Réseau instable** | Envois par petits éléments ; reprise d'un fichier photo sans repartir de zéro si possible, sinon renvoi complet de cette seule photo. |
| **Horloge du téléphone incorrecte** | Les dates saisies sont enregistrées avec l'heure du téléphone ; l'application avertit si l'écart avec le serveur dépasse une limite fixée (à définir). |

### 4.3 Indicateur permanent d'éléments en attente
- Une **pastille avec le nombre d'éléments en attente** est affichée **en permanence** dans l'en-tête, sur tous les écrans des deux espaces.
- Elle change de couleur selon l'ancienneté du plus ancien élément : neutre, **orange à partir de 24 h**, **rouge à partir de 48 h** (même seuil que la supervision, §5).
- Un appui ouvre l'écran de synchronisation, avec le détail et le bouton « Réessayer ».
- Le nombre est **toujours exact** : visites, photos, commandes et notes en attente ou en erreur.

### 4.4 Réception des données
- Chargement initial puis **rafraîchissement** à l'ouverture et sur demande.
- Aujourd'hui, l'API ne propose ni synchronisation différentielle ni notification des suppressions : un rechargement complet est nécessaire (voir annexe, §5). Cible : un point d'entrée « modifié depuis » avec suppressions.
- Volumétrie à mesurer sur données réelles : nombre de magasins par promoteur, taille du catalogue (pages de 100), poids des photos.

### 4.5 Conflits
- Règle actuelle : **la dernière écriture gagne** (aucun numéro de version). Acceptable pour les créations (visites, commandes, notes), qui ne se modifient pas après envoi ; à renforcer pour les modifications de fiches.
- Les saisies terrain sont principalement des **créations** : les conflits réels sont rares.

### 4.6 Photos
- Compression et redimensionnement **dans l'application** avant envoi (le serveur ne le fait pas).
- Envoi en tâche de fond, reprenable, après la visite associée.
- Nombre de photos par visite non limité côté serveur : limite fonctionnelle à définir.

---

## 5. Supervision et télémétrie

La console d'administration (ABC Pilot, onglet **Mobile**) est prévue mais **vide aujourd'hui** : l'application ne remonte rien. Ce cahier des charges la rend possible.

### 5.1 Données remontées par l'application à chaque synchronisation
| Donnée | Usage |
|---|---|
| Identifiant d'installation | Reconnaître un téléphone |
| Modèle, système et version | Diagnostic |
| **Version de l'application** | Repérer les versions obsolètes |
| Dernier contact avec le serveur | Savoir si l'application communique |
| **Dernière synchronisation réussie** | Savoir si les données sont réellement remontées |
| Éléments en attente (visites, photos, commandes, notes) et ancienneté du plus ancien | Repérer les données bloquées |
| Dernière erreur de synchronisation | Comprendre un échec |

Le **contact serveur** et la **synchronisation réussie** sont deux mesures distinctes : un téléphone peut joindre le serveur tout en ayant des commandes bloquées.

### 5.2 Indicateurs côté administrateur (sans gestion d'alertes)
Compteurs calculés à la volée : téléphones actifs, **en retard** (seuil configurable, 48 h par défaut), en erreur, version obsolète. Chaque indicateur ouvre la liste des appareils concernés.

### 5.3 Actions à distance (à décider)
- « Forcer une resynchronisation » : le serveur enregistre une **demande**, que le téléphone récupère à son prochain contact. États affichés : demandée, reçue, en cours, réussie, échouée — jamais « exécutée instantanément ».
- Blocage d'un appareil perdu : voir §6.2.

### 5.4 Données personnelles
Collecte minimale (aucune géolocalisation en continu), accès réservé aux administrateurs, durée de conservation à fixer.

---

## 6. Exigences non fonctionnelles

### 6.1 Plateformes et distribution
- **Android en priorité** (le terrain parle d'« APK »). iOS à confirmer.
- Distribution : application interne (APK signée, gestion de flotte ou boutique privée) — à décider.
- Langue : français uniquement.

### 6.2 Sécurité des données locales

**Protection de base**
- Jeton stocké dans l'espace sécurisé du système (Keystore / Keychain), jamais en clair.
- **Base locale et photos chiffrées** ; la clé est protégée par le système et par le déverrouillage biométrique ou par code.
- Communication en HTTPS uniquement ; aucun secret embarqué dans l'application.
- Verrouillage automatique après inactivité ; masquage de l'aperçu de l'application dans la liste des applications récentes.
- L'application n'affiche que ce que l'API renvoie pour le rôle de l'utilisateur.

**Scénarios à traiter**

| Situation | Comportement |
|---|---|
| **Perte ou vol du téléphone** | L'utilisateur prévient son responsable ; l'administrateur **désactive le compte**. L'API vérifie le compte à **chaque appel** : toutes les requêtes sont alors refusées, quel que soit le jeton. Au prochain contact avec le serveur, l'application détecte le refus, **se verrouille et supprime les données locales** (après envoi impossible, l'utilisateur est prévenu en amont de ce que cela implique). Sans réseau, les données restent **chiffrées** et inaccessibles sans le déverrouillage. |
| **Départ d'un salarié** | Même mécanisme : désactivation du compte, effet immédiat côté serveur. Une règle complémentaire peut effacer les données locales d'un téléphone **sans contact avec le serveur depuis N jours** (valeur à fixer, §10) ; l'utilisateur en est averti avant l'échéance. |
| **Expiration du jeton (8 h)** | La **lecture hors ligne reste possible** avec le déverrouillage local pendant une durée limitée (proposition : 72 h après la dernière authentification réussie). L'**envoi** et le rafraîchissement exigent une nouvelle connexion. La file d'envoi est conservée intacte. |
| **Déconnexion avec données non envoyées** | L'application **avertit** : « n éléments ne sont pas envoyés ». Par défaut, la déconnexion **conserve** ces éléments chiffrés pour leur propriétaire et les renvoie à sa reconnexion. La suppression des données non envoyées n'est possible qu'avec une **double confirmation** explicite. |
| **Compte désactivé alors que des données ne sont pas envoyées** | Le serveur refuse les envois. Les éléments restent signalés « en erreur — compte désactivé » ; leur récupération éventuelle se décide avec le responsable avant tout effacement. |

**À tester avant le lancement** (bloquant) :
- **révocation** : un compte désactivé ne peut plus rien envoyer ni recevoir, et l'application se verrouille au contact suivant ;
- **chiffrement** : l'inspection du stockage du téléphone, sans le déverrouillage, ne révèle ni jeton, ni données, ni photos exploitables ;
- **cloisonnement** entre deux comptes sur un même téléphone.

*Limite actuelle de l'API : il n'y a pas de jeton de rafraîchissement, de déconnexion ni de révocation de jeton ; l'effet de la désactivation du compte, vérifié à chaque appel, joue le rôle de révocation (voir §7).*

### 6.3 Performance et robustesse
- Démarrage à froid en moins de 3 secondes ; **ouverture d'une fiche magasin en moins de 2 secondes**, depuis la base locale, sur un téléphone d'entrée de gamme.
- Fonctionnement sur réseau 2G/3G dégradé ; envois reprenables.
- Aucune perte de données saisie en cas de fermeture brutale de l'application.
- Journal d'erreurs et rapports de plantage remontés (hors données personnelles).

### 6.4 Ergonomie
- Utilisable à une main, en magasin, avec de gros boutons et peu de saisie libre.
- Même identité visuelle que la plateforme : **menu sombre**, bleu marine pour le terrain, violet pour le pilotage ; police Inter ; logo « SalesPilot ABC ».
- Accessibilité : contrastes suffisants, tailles de texte système respectées.

### 6.5 Mises à jour
- **Version minimale exigée** par le serveur : en dessous, l'application bloque l'envoi et invite à se mettre à jour, plutôt que d'envoyer des données dans un format obsolète. Les données déjà saisies restent conservées.
- Compatibilité ascendante de l'API sur au moins deux versions de l'application.

---

## 7. Prérequis côté API

L'API couvre déjà l'essentiel de la saisie terrain. Il manque, pour un mobile fiable, les éléments suivants (détail et références dans l'annexe) :

| # | Besoin | Priorité |
|---|---|---|
| 1 | **Télémétrie des appareils** : enregistrement, version, dernière synchro, éléments en attente | P1 |
| 2 | **Version minimale de l'application** et numéro de version de l'API | P1 |
| 3 | **Idempotence complète** : contacts, pièces jointes, opportunités ; unicité de l'`idApk` des notes ; collision d'`idApk` de tournée entre utilisateurs (erreur serveur aujourd'hui) | P1 |
| 4 | **Sécurité du jeton** : déconnexion, révocation, limitation des tentatives de connexion | P1 |
| 5 | **Périmètres de lecture** à corriger sur plusieurs routes (fiche magasin, commandes, visites, tableau de bord) ; création / modification / suppression de magasins ouvertes à tous les rôles | P1 |
| 6 | **Synchronisation différentielle** : « modifié depuis » et suppressions | P2 |
| 7 | **Notifications push** (jetons d'appareil, envoi) | P3 |
| 8 | Détail d'une visite ; routes DN / PEM / promotions vues en visite (existent au schéma, jamais alimentées) | P2 |
| 9 | Position GPS d'une visite (check-in) | P3 |
| 10 | Limite de taille et filtre de type sur les pièces jointes de prospect | P2 |
| 11 | Réponse d'API homogène : indicateur de doublon (`dejaSynchronisee` / `dejaSynchronise` coexistent) | P2 |
| 12 | **Modification ou annulation d'une commande mobile** (n'existe pas) — seulement si le métier le demande | P3 |

Ces éléments recoupent le backlog de sécurité de la plateforme (`docs/BACKLOG.md`).

---

## 8. Lots de livraison proposés

| Lot | Contenu | Cible |
|---|---|---|
| **MVP — le quotidien du promoteur** | Connexion AD et déverrouillage local · **accueil = tournée du jour** · magasins (liste, fiche, notes) · **visite** avec brouillon, questionnaire, distribution numérique et **photos** · **commande** simplifiée (recherche, colisage, récapitulatif, alerte rappel) · catalogue, promotions et rappels · **hors ligne, file d'envoi, compteur d'attente et écran de synchronisation** · télémétrie de base · version minimale | Promoteurs (espace Sales) |
| **Lot 2** | Indicateurs du promoteur (CA, objectifs, évolution) · planning de la semaine · contacts, appels, e-mails · carte · liste des notifications · scan de code-barres · commandes ERP et livraison · accès ADV et Marketing en consultation | Promoteurs, ADV, Marketing |
| **Lot 3** | **Espace ABC Pilot** : sélecteur d'espace · tournée d'encadrement et validation hebdomadaire · visite commerciale · prospection complète · équipe et relance · notifications push | CS, DR |
| **Lot 4** | Tableaux de bord de direction · actions à distance · synchronisation différentielle · optimisations | Direction, tous |

**Reporté volontairement après le MVP** : tableaux de bord détaillés, fonctions de direction, prospection avancée, planning de la semaine, carte, scan de code-barres, notifications.

Le **MVP n'est livrable que si les prérequis API 1 à 5 sont traités en parallèle** (§7).

---

## 9. Recette — critères de validation

Chaque critère est **mesurable**. Un critère non atteint bloque la livraison du lot concerné.

### 9.1 Fiabilité de la saisie et de la synchronisation
| # | Critère | Mesure |
|---|---|---|
| 1 | **Aucune perte de visite en mode avion** | 100 visites (dont 30 avec 3 photos chacune) saisies hors ligne puis synchronisées : **100 retrouvées** côté serveur |
| 2 | **Aucun doublon après envois répétés** | Pour 50 visites et 50 commandes, envoi interrompu puis rejoué 5 fois chacune : **exactement 1** enregistrement serveur par élément |
| 3 | **Reprise après fermeture brutale** | Application tuée à 20 moments différents d'une visite (début, milieu, pendant une photo, pendant l'envoi) : **100 % des saisies retrouvées** en brouillon |
| 4 | **Photos partiellement envoyées** | 10 photos de 3 Mo envoyées sur réseau coupé à intervalles aléatoires : **10 reçues, 0 doublon, 0 corruption** (poids identique à l'original compressé) |
| 5 | **Synchronisation sur réseau instable** | Profil réseau dégradé (3G, 10 % de pertes, coupures de 30 s) : **100 % des éléments livrés** moins de 10 minutes après le retour d'un réseau stable |
| 6 | **Compteur d'attente exact** | À chaque étape des tests ci-dessus, le nombre affiché est **égal** au nombre réel d'éléments non confirmés (écart 0) |
| 7 | **États de visite corrects** | Une visite passe par brouillon, terminée, synchronisée ; une visite incomplète **ne peut pas** être validée |

### 9.2 Performance
| # | Critère | Mesure |
|---|---|---|
| 8 | **Ouverture d'une fiche magasin** | **Moins de 2 secondes** (95 % des ouvertures) sur le téléphone d'entrée de gamme de référence, avec 500 magasins en local |
| 9 | **Démarrage à froid** | **Moins de 3 secondes** jusqu'à la tournée du jour |
| 10 | **Recherche d'article** | Résultat affiché **en moins de 500 ms** sur un catalogue complet local |

### 9.3 Sécurité et droits
| # | Critère | Mesure |
|---|---|---|
| 11 | **Révocation** | Compte désactivé : **toute requête est refusée** ; l'application se verrouille **au premier contact réseau suivant** |
| 12 | **Chiffrement** | Sans déverrouillage, l'inspection du stockage ne révèle **aucun** jeton, donnée ni photo exploitable |
| 13 | **Cloisonnement** | Deux comptes successifs sur un même téléphone : **aucune donnée de l'un visible par l'autre** ; les éléments non envoyés du premier ne partent pas sous l'identité du second |
| 14 | **Droits par rôle** | Un promoteur n'a **ni sélecteur ni écran Pilot** ; la même route de prospection appelée avec son jeton est **refusée par le serveur** ; un CS voit les deux espaces |
| 15 | **Jeton expiré** | Session expirée avec des éléments en attente : **aucune donnée perdue**, envoi repris après reconnexion |

### 9.4 Mises à jour et supervision
| # | Critère | Mesure |
|---|---|---|
| 16 | **Version obsolète** | Serveur exigeant une version supérieure : **100 % des envois bloqués**, données conservées, invitation à mettre à jour |
| 17 | **Supervision** | Un téléphone sans synchronisation réussie depuis plus de 48 h apparaît « en retard » dans la console d'administration |
| 18 | **Commande de bout en bout** | Commande créée hors ligne, synchronisée, puis vue « intégrée » avec son numéro ERP après l'import |
| 19 | **Stockage saturé** | Avec moins de 100 Mo libres : prise de photo bloquée avec explication, **aucune donnée non envoyée supprimée** |

---

## 10. Questions ouvertes et décisions à prendre

1. **Une application ou deux** (terrain / pilotage) ? Recommandation : **une seule application, deux espaces** (§3.0).
2. **Android seul ou Android + iOS** ? Parc de téléphones et gestion de flotte (MDM) ? **Téléphone d'entrée de gamme de référence** pour les mesures de performance ?
3. **Qui développe l'application** (équipe interne, prestataire) ? Choix technique (natif, Flutter, React Native…) ?
4. **Distribution** : APK interne, boutique privée, gestion de flotte ?
5. **Actions à distance** : seulement « forcer la synchro », ou aussi blocage d'un appareil perdu au-delà de la désactivation du compte ?
6. **Seuil de « téléphone en retard »** : 48 h convient-il, y compris le week-end et les congés ?
7. **ADV et MARKETING dans ABC Sales** : que voient-ils exactement ? L'API ne leur applique aucun portefeuille (vue globale des magasins) et n'a pas de règle d'écriture précise pour eux. À fixer : lecture seule ou saisie (visites, commandes) ? Quel périmètre de magasins ? Un ADV peut modifier le statut de livraison d'une commande : faut-il l'offrir sur mobile ?
8. **Photos** : limite par visite, durée de conservation, compression cible.
9. **Conflits** : la règle « dernière écriture gagne » suffit-elle pour les modifications de fiches magasin ?
10. **Valeurs métier « à valider »** dans l'API : sources de prospect, motifs de perte, probabilités par étape du pipeline.
11. **Prospection par les promoteurs** : confirmer qu'ils n'en ont aucune dans l'application (§3.0), ou spécifier le besoin (signaler un prospect ?) avec les droits d'API correspondants.
12. **Commandes** : contrôle que le magasin appartient au portefeuille ; quantités minimales ; **prix indicatif affiché ou non** ; **commande modifiable avant envoi** (proposé : oui) et **non modifiable après** (proposé) — ou création d'une route de modification / annulation.
13. **Espace d'ouverture** : toujours ABC Sales à la connexion, ou rouvrir le dernier espace utilisé ?
14. **Champs obligatoires d'une visite** : lesquels bloquent la validation (motif, questionnaire, photo, commentaire) ? Durée minimale ?
15. **Effacement des données locales** : après combien de jours sans contact avec le serveur ? Que faire des données non envoyées dans ce cas ?
16. **Durée de lecture hors ligne sans reconnexion** après expiration du jeton (proposé : 72 h).
17. **Un seul brouillon par magasin** et abandon d'un brouillon : règles à valider avec les promoteurs.
18. **Promoteur sans code représentant** (compte non relié à l'ERP) : que lui montre l'application ?

---

## 11. Glossaire

| Terme | Sens |
|---|---|
| **AD** | Active Directory de l'entreprise, source des comptes et mots de passe |
| **APK** | Fichier d'installation d'une application Android ; désigne ici l'application mobile |
| **idApk** | Identifiant unique généré par l'application pour chaque saisie, qui évite les doublons à l'envoi |
| **Outbox** | File des saisies locales en attente d'envoi |
| **Brouillon** | Saisie commencée, non validée, modifiable et non envoyée |
| **DN** | Distribution numérique : présence des références ABC et concurrentes en rayon |
| **PEM** | Produits mis en avant |
| **CS / DR** | Chef de secteur / Directeur régional |
| **Minos / AS400** | Système de gestion d'ABC, source des magasins, articles et commandes |
| **Portefeuille** | Magasins rattachés à un promoteur par son code représentant |
| **Code représentant** | Code ERP du promoteur ; « 68 » et « 068 » désignent le même |
| **Colisage** | Nombre d'unités par colis ; la commande se saisit en colis |
