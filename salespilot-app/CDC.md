# Cahier des charges — application mobile SalesPilot

Version 0.1 — 26/10/2026 — **à valider**

> Document destiné à l'équipe qui concevra et développera l'application, et aux décideurs qui la valident. Les contraintes techniques détaillées de l'API sont dans [ANNEXE-API.md](ANNEXE-API.md).

---

## 1. Contexte et objectifs

### 1.1 La plateforme
ABC Cosmétique dispose d'une plateforme commerciale unique, **SalesPilot ABC**, composée de :
- **ABC Sales** : espace terrain (web) — magasins, visites, commandes, catalogue, promotions.
- **ABC Pilot** : espace de pilotage et d'encadrement (web) — équipes, prospection, alertes, administration.
- **Une API et une base de données communes**, avec une authentification unique par l'Active Directory (AD) de l'entreprise.

L'application mobile est le **troisième accès** à cette plateforme : elle ne crée pas de données à part, elle utilise la même API et les mêmes règles de rôles. Comme le web, elle comporte **deux espaces, ABC Sales et ABC Pilot**, accessibles selon les droits (voir §3.0).

### 1.2 Pourquoi un mobile
Les promoteurs des ventes travaillent en magasin, souvent avec une mauvaise couverture réseau. Il leur faut saisir une visite, photographier un linéaire, prendre une commande et consulter une fiche magasin **sur place, même sans réseau**. L'encadrement (chefs de secteur, directeurs régionaux) doit suivre sa tournée et son équipe en déplacement.

### 1.3 Objectifs
1. Permettre la **saisie terrain complète** (visite, photos, commande, notes, appels) hors ligne, avec une synchronisation fiable et sans doublon.
2. Donner au promoteur **l'information utile en visite** : fiche magasin, historique, objectifs, promotions, rappels produits.
3. Donner à l'encadrement **le suivi de sa tournée, de son équipe et de la prospection**.
4. Rendre l'application **supervisable** par l'administrateur : savoir quel téléphone est à jour, lequel a des données bloquées, quelle version tourne.

### 1.4 Hors périmètre (cette version)
- Administration de la plateforme (utilisateurs, imports, configuration) : elle reste dans ABC Pilot sur le web.
- Édition du catalogue, des promotions et du questionnaire de visite : web uniquement.
- Imports ERP (Minos / AS400) : serveur uniquement.

---

## 2. Utilisateurs et rôles

Les rôles existent déjà dans l'API et déterminent ce que chacun voit. L'application les reprend tels quels.

| Rôle (valeur API) | Utilisateur | Espaces | Usage principal sur mobile |
|---|---|---|---|
| `COMMERCIAL` | Promoteur des ventes | Sales | Cœur de cible : visites, commandes, magasins de son portefeuille |
| `CHEF_SECTEUR` | Chef de secteur (CS) | Sales + Pilot | Sa tournée, visites commerciales, prospection, suivi de ses promoteurs |
| `DIRECTEUR_REGIONAL` | Directeur régional (DR) | Sales + Pilot | Idem CS sur sa région, relance de son équipe |
| `DIRECTION` | Direction | Sales + Pilot | Consultation (tableaux de bord, équipe) |
| `ADMIN` | Administrateur | Sales + Pilot | Accès complet en lecture, aucune administration sur mobile |
| `ADV`, `MARKETING` | Services siège | à confirmer | Pas de cible mobile en v1 (à confirmer) |

**Un seul compte, un seul identifiant** : le login AD. L'application donne accès aux espaces autorisés par le rôle reçu à la connexion (voir §3.0).

---

## 3. Fonctionnalités

Priorités : **P1** indispensable au lancement · **P2** important, lot suivant · **P3** souhaitable.
Rôles : **Pro** = promoteur, **Enc.** = encadrement (CS, DR), **Dir.** = direction/admin.

### 3.0 Une application, deux espaces : ABC Sales et ABC Pilot

L'application mobile reprend la structure de la plateforme web : **une seule application « SalesPilot »**, avec **deux espaces** accessibles **selon les droits** de l'utilisateur.

| Espace | Contenu | Équivalent web |
|---|---|---|
| **ABC Sales** — terrain | Magasins, visites, commandes, catalogue, promotions, tournée du jour, notifications | ABC Sales |
| **ABC Pilot** — pilotage | Prospection et pipeline, tournée d'encadrement et validation hebdomadaire, équipe, relances, tableaux de bord de direction | ABC Pilot |

**Accès par rôle** (mêmes règles que le web) :

| Rôle | ABC Sales | ABC Pilot | Changement d'espace |
|---|---|---|---|
| `COMMERCIAL` (promoteur) | Oui | **Non** | Aucun : il arrive directement dans ABC Sales |
| `CHEF_SECTEUR`, `DIRECTEUR_REGIONAL`, `DIRECTION`, `ADMIN` | Oui | **Oui** | Oui |
| `ADV`, `MARKETING` | À confirmer | Non | — |

**Comportement**
- À la connexion, l'application ouvre **ABC Sales** (espace par défaut) ; le rôle est lu dans la réponse de connexion.
- Les rôles autorisés disposent d'un **sélecteur d'espace** (comme sur le web) pour passer d'ABC Sales à ABC Pilot et inversement. Un promoteur **ne voit ni le sélecteur ni aucun écran Pilot**.
- Chaque espace a sa **couleur**, comme sur le web : bleu marine pour ABC Sales, violet pour ABC Pilot, avec le même logo « SalesPilot ABC ».
- **Les droits sont aussi appliqués côté serveur** : masquer un écran dans l'application ne suffit pas. L'API refuse déjà la plupart des routes de prospection et de tournées à un promoteur (voir l'annexe) ; l'application ne fait qu'**épouser** ces règles.
- La **file d'envoi et l'écran de synchronisation sont communs** aux deux espaces.

*Alternative écartée par défaut : deux applications distinctes (ABC Sales Mobile, ABC Pilot Mobile). Elle double la maintenance, les mises à jour et la supervision. À confirmer en §10.*

---

### 3.1 Connexion et session — P1 — tous
- Connexion par identifiant et mot de passe AD (`POST /auth/login`).
- Jeton valable **8 heures** ; à l'expiration, l'utilisateur ressaisit son mot de passe. Les données déjà saisies hors ligne **ne sont jamais perdues** à l'expiration : elles restent en attente d'envoi.
- Déverrouillage local par **biométrie ou code** après la première connexion (P2).
- Déconnexion : efface le jeton ; demande confirmation si des éléments non envoyés existent.
- Message clair si le compte est désactivé (401) ou si l'AD est injoignable (503).

### 3.2 Accueil et indicateurs — P1 — tous · espaces Sales et Pilot
- **Espace ABC Sales (Pro ; Enc. dans cet espace)** : CA du mois et comparaison N-1, nombre de commandes, objectif et taux d'atteinte, visites du mois, **tournée du jour**, commandes à suivre, alertes produits en rappel, top de ses magasins.
- **Espace ABC Pilot (Enc., Dir.)** : synthèse de son périmètre (CA, classement des promoteurs, magasins sans commande, objectifs).
- Évolution du CA et des commandes sur 6 mois (P2).
- Fonctionne **hors ligne sur les dernières données connues**, avec la date de dernière mise à jour affichée.

### 3.3 Magasins — P1 — Pro, Enc. · espace Sales
- Liste du **portefeuille** (périmètre du rôle), recherche par enseigne, raison sociale, code ; filtre actifs / inactifs.
- Indicateurs par magasin : CA du mois, évolution N-1, jours depuis la dernière visite, périodicité, classe (A à G), état (ok / attention / alerte).
- **Fiche magasin** : coordonnées, contacts, notes, historique des commandes et des visites, CA mensuel, journal des appels et e-mails.
- **Carte** des magasins géolocalisés (P2) et navigation vers l'adresse.
- Actions : ajouter un contact, une note, enregistrer un appel ou un e-mail (P1) ; modifier la périodicité (Enc., P2).
- **Hors ligne** : la fiche, les contacts et les 20 dernières notes sont répliqués sur le téléphone.

### 3.4 Visites — P1 — Pro, Enc. · espace Sales
- **Démarrer une visite** depuis la tournée du jour, depuis une fiche magasin ou sur un prospect.
- Saisie : motif, **distribution numérique** (ABC, concurrence, gondole haute, gondole basse), commentaire, **questionnaire dynamique** (cases à cocher, texte, nombre, note 1 à 5) défini côté web.
- **Photos** : plusieurs par visite, compressées avant envoi (limite serveur : 10 Mo, image uniquement).
- Si la visite était planifiée, elle est **soldée automatiquement** à l'enregistrement.
- **Visite commerciale** (Enc.) : rendez-vous ou non, objets traités, remplissage, compte rendu, prochaine visite, réponses au questionnaire ; horodatage de début et de fin.
- **Historique** de ses visites (P2) et détail d'une visite passée (nécessite un ajout API, voir annexe).
- Une visite enregistrée hors ligne est **envoyée dès le retour du réseau**, avec ses photos, sans doublon.

### 3.5 Commandes — P1 — Pro · espace Sales
- **Prise de commande** sur un magasin : lignes article, quantité, prix indicatif, commentaire, date.
- Identifiant de commande mobile de 4 à 10 caractères alphanumériques, généré par l'application, qui sert de clé anti-doublon et de pont avec la commande ERP.
- **Suivi** : « envoyée », « intégrée dans l'ERP » avec le numéro ERP une fois rapprochée.
- Consultation des **commandes ERP** et de leur statut de livraison : en préparation, expédiée, livrée partiellement, livrée ; transporteur et numéro de suivi (P2).

### 3.6 Catalogue — P1 — tous · espace Sales
- Recherche d'articles par libellé, code, **code-barres** et **marque**.
- **Scan du code-barres** avec l'appareil photo (P2).
- Affichage : marque, gamme, famille, colisage, prix indicatif, promotion en cours, mise en avant (PEM), statut de rappel qualité.
- **Promotions et PEM** actives (P1) ; produits **en rappel qualité** (P1).
- Catalogue disponible hors ligne.

### 3.7 Planning et tournées — P2 — Pro (lecture), Enc. (saisie) · tournée du jour dans Sales, tournée d'encadrement dans Pilot
- **Pro** : consulter sa tournée du jour et de la semaine ; les visites planifiées par l'encadrement ou issues de récurrences. Un promoteur ne crée pas ses visites planifiées (règle actuelle de l'API).
- **Enc.** : sa **tournée personnelle** (étapes : visite simple, accompagnement, rendez-vous, soirée étape, tâche administrative), requalification d'une étape, **prévision puis validation hebdomadaire**.
- Planification et récurrences d'équipe : réservées au web en v1.
- Export de la tournée vers l'agenda du téléphone (flux calendrier existant).

### 3.8 Prospection — P2 — Enc. (complet), Pro (partiel) · espace Pilot
- **Enc.** : liste et **pipeline** des prospects (nouveau, contacté, proposition, visite, négociation, gagné, perdu), création sur le terrain, fiche, historique, étape, motif de perte, **conversion en client**, opportunités (référencement, opération promotionnelle, mise en avant).
- **Pro** : ajout de notes, appels, e-mails et pièces jointes sur un prospect (selon les droits actuels).
- Visite de prospection depuis la fiche prospect.

### 3.9 Notifications — P2 — tous · espaces Sales et Pilot
- Liste des notifications, marquage lu / tout lu, compteur de non lues.
- **Notifications push** (nouveau, nécessite un ajout API) : relance de visite non faite, relance par la hiérarchie.
- **Enc.** : relancer un promoteur ou un membre de son équipe.

### 3.10 Équipe — P3 — Enc., Dir. · espace Pilot
- Mon équipe : promoteurs rattachés, planning d'activité, relance.
- Classement et tableau de bord de direction.

### 3.11 Profil et état de l'application — P1 — tous · commun aux deux espaces
- Photo et nom (issus de l'AD), rôle, secteur.
- **Écran « Synchronisation »** : éléments en attente par type (visites, photos, commandes, notes…), dernière synchronisation réussie, erreurs avec bouton « Réessayer » (P1).
- Version de l'application ; invitation à mettre à jour si une version minimale est exigée (P1).

---

## 4. Hors ligne et synchronisation

C'est la partie la plus exigeante du projet. L'application doit rester **entièrement utilisable sans réseau** pour la saisie terrain.

### 4.1 Principes
1. **Base locale** sur le téléphone : référentiels répliqués (magasins du portefeuille avec contacts et notes, catalogue, promotions, questionnaire, tournée) et saisies en attente.
2. **File d'envoi (« outbox »)** : chaque saisie est écrite localement avec un identifiant client unique (`idApk`), puis envoyée quand le réseau le permet. Un envoi rejoué ne crée **jamais de doublon** : le serveur reconnaît l'identifiant.
3. **Ordre d'envoi respecté** quand des éléments dépendent les uns des autres :
   - un prospect avant la visite ou l'étape qui le référence ;
   - une visite **avant ses photos** (les photos utilisent l'identifiant serveur de la visite) ;
   - une prévision hebdomadaire seulement s'il existe au moins une étape.
4. **Transparence** : chaque élément affiche son état (« en attente », « envoyé », « en erreur »). Jamais d'échec silencieux.
5. **Reprise** : après une coupure, l'envoi reprend sans intervention ; les erreurs définitives (refus du serveur) sont conservées avec leur motif.

### 4.2 Réception des données
- Chargement initial puis **rafraîchissement** à l'ouverture et sur demande.
- Aujourd'hui, l'API ne propose ni synchronisation différentielle ni notification des suppressions : un rechargement complet est nécessaire (voir annexe, §5). Cible : un point d'entrée « modifié depuis » avec suppressions.
- Volumétrie à mesurer sur données réelles : nombre de magasins par promoteur, taille du catalogue (pages de 100), poids des photos.

### 4.3 Conflits
- Règle actuelle : **la dernière écriture gagne** (aucun numéro de version). Acceptable pour les créations (visites, commandes, notes) qui ne se modifient pas ; à renforcer pour les modifications de fiches.
- Les saisies terrain sont principalement des **créations** : les conflits réels sont rares.

### 4.4 Photos
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
| Éléments en attente (visites, photos, commandes, notes) | Repérer les données bloquées |
| Dernière erreur de synchronisation | Comprendre un échec |

Le **contact serveur** et la **synchronisation réussie** sont deux mesures distinctes : un téléphone peut joindre le serveur tout en ayant des commandes bloquées.

### 5.2 Indicateurs côté administrateur (sans gestion d'alertes)
Compteurs calculés à la volée : téléphones actifs, **en retard** (seuil configurable, 48 h par défaut), en erreur, version obsolète. Chaque indicateur ouvre la liste des appareils concernés.

### 5.3 Actions à distance (à décider)
- « Forcer une resynchronisation » : le serveur enregistre une **demande**, que le téléphone récupère à son prochain contact. États affichés : demandée, reçue, en cours, réussie, échouée — jamais « exécutée instantanément ».
- Blocage d'un appareil perdu : à décider (voir §10).

### 5.4 Données personnelles
Collecte minimale (aucune géolocalisation en continu), accès réservé aux administrateurs, durée de conservation à fixer.

---

## 6. Exigences non fonctionnelles

### 6.1 Plateformes et distribution
- **Android en priorité** (le terrain parle d'« APK »). iOS à confirmer.
- Distribution : application interne (APK signée, gestion de flotte ou boutique privée) — à décider.
- Langue : français uniquement.

### 6.2 Sécurité
- Jeton stocké dans l'espace sécurisé du système (Keystore / Keychain), jamais en clair.
- Base locale chiffrée (données clients, photos).
- Communication en HTTPS uniquement.
- Aucun secret embarqué dans l'application.
- Verrouillage automatique après inactivité (P2).
- Respect des périmètres de rôle : l'application n'affiche que ce que l'API renvoie.

### 6.3 Performance et robustesse
- Démarrage et ouverture d'une fiche magasin en moins de 2 secondes sur un téléphone d'entrée de gamme, depuis la base locale.
- Fonctionnement sur réseau 2G/3G dégradé ; envois reprenables.
- Aucune perte de données saisie en cas de fermeture brutale de l'application.
- Journal d'erreurs et rapports de plantage remontés (hors données personnelles).

### 6.4 Ergonomie
- Utilisable à une main, en magasin, avec de gros boutons et peu de saisie libre.
- Même identité visuelle que la plateforme : **menu sombre**, bleu marine pour le terrain, violet pour le pilotage ; police Inter ; logo « SalesPilot ABC ».
- Accessibilité : contrastes suffisants, tailles de texte système respectées.

### 6.5 Mises à jour
- **Version minimale exigée** par le serveur : en dessous, l'application bloque l'envoi et invite à se mettre à jour, plutôt que d'envoyer des données dans un format obsolète.
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
| 5 | **Périmètres de lecture** à corriger sur plusieurs routes (fiche magasin, commandes, visites, tableau de bord) | P1 |
| 6 | **Synchronisation différentielle** : « modifié depuis » et suppressions | P2 |
| 7 | **Notifications push** (jetons d'appareil, envoi) | P2 |
| 8 | Détail d'une visite, routes DN / PEM / promotions vues en visite (existent au schéma, jamais alimentées) | P2 |
| 9 | Position GPS d'une visite (check-in) | P3 |
| 10 | Limite de taille et filtre de type sur les pièces jointes de prospect | P2 |
| 11 | Réponse d'API homogène : indicateur de doublon (`dejaSynchronisee` / `dejaSynchronise` coexistent) | P2 |

Ces éléments recoupent le backlog de sécurité de la plateforme (`docs/BACKLOG.md`).

---

## 8. Lots de livraison proposés

| Lot | Contenu | Cible |
|---|---|---|
| **MVP** | Connexion AD, magasins (liste, fiche), **visite + questionnaire + photos**, **commande**, catalogue et promotions, **hors ligne et synchronisation**, écran de synchronisation, télémétrie de base | Promoteurs |
| **Lot 2** | Tournée et planning, notes / appels / e-mails, carte, notifications (liste), scan code-barres, biométrie | Promoteurs + CS |
| **Lot 3** | Prospection complète, tournée d'encadrement avec validation hebdomadaire, équipe et relance, push, tableau de bord de direction | CS, DR, direction |
| **Lot 4** | Actions à distance, synchronisation différentielle, optimisations | Tous |

Le **MVP n'est livrable que si le lot « Prérequis API » 1 à 5 est fait en parallèle**.

---

## 9. Recette — scénarios d'acceptation

1. **Visite hors ligne** : saisir une visite avec 3 photos en mode avion, rétablir le réseau → la visite et les photos arrivent une seule fois, la visite planifiée est soldée.
2. **Double envoi** : couper le réseau pendant un envoi puis le rejouer → aucun doublon côté serveur.
3. **Commande** : créer une commande hors ligne, la synchroniser, la voir « intégrée » avec son numéro ERP après l'import.
4. **Jeton expiré** : laisser expirer la session avec des éléments en attente → reconnexion, aucune donnée perdue, envoi repris.
5. **Version obsolète** : serveur exigeant une version minimale supérieure → l'application bloque l'envoi et propose la mise à jour.
6. **Périmètre** : un promoteur ne voit que son portefeuille ; un CS voit ses promoteurs ; aucune donnée d'un autre périmètre.
7. **Supervision** : un téléphone sans synchronisation depuis plus de 48 h apparaît « en retard » dans la console d'administration.
8. **Fermeture brutale** : tuer l'application pendant une saisie → la saisie est retrouvée à la réouverture.
9. **Espaces et droits** : un promoteur se connecte et n'a accès qu'à ABC Sales, sans sélecteur d'espace ; un chef de secteur voit le sélecteur et accède aux deux espaces ; la même route de prospection appelée avec le jeton d'un promoteur est refusée par le serveur.

---

## 10. Questions ouvertes et décisions à prendre

1. **Une application ou deux** (terrain / pilotage) ? Recommandation : **une seule application, deux espaces** (§3.0).
2. **Android seul ou Android + iOS** ? Parc de téléphones et gestion de flotte (MDM) ?
3. **Qui développe l'application** (équipe interne, prestataire) ? Choix technique (natif, Flutter, React Native…) ?
4. **Distribution** : APK interne, boutique privée, gestion de flotte ?
5. **Actions à distance** : seulement « forcer la synchro », ou aussi blocage d'un appareil perdu ?
6. **Seuil de « téléphone en retard »** : 48 h convient-il, y compris le week-end et les congés ?
7. **Les rôles ADV et MARKETING** ont-ils un usage mobile ?
8. **Photos** : limite par visite, durée de conservation, compression cible.
9. **Conflits** : la règle « dernière écriture gagne » suffit-elle pour les modifications de fiches magasin ?
10. **Valeurs métier « à valider »** dans l'API : sources de prospect, motifs de perte, probabilités par étape du pipeline.
11. **Un promoteur peut-il créer un prospect** ou une visite non planifiée sur le terrain ? Aujourd'hui, non pour le prospect.
12. **Commandes** : contrôle que le magasin appartient au portefeuille, quantités minimales, prix affiché ou non.
13. **Espace d'ouverture** : toujours ABC Sales à la connexion, ou rouvrir le dernier espace utilisé ?

---

## 11. Glossaire

| Terme | Sens |
|---|---|
| **AD** | Active Directory de l'entreprise, source des comptes et mots de passe |
| **APK** | Fichier d'installation d'une application Android ; désigne ici l'application mobile |
| **idApk** | Identifiant unique généré par l'application pour chaque saisie, qui évite les doublons à l'envoi |
| **Outbox** | File des saisies locales en attente d'envoi |
| **DN** | Distribution numérique : présence des références ABC et concurrentes en rayon |
| **PEM** | Produits mis en avant |
| **CS / DR** | Chef de secteur / Directeur régional |
| **Minos / AS400** | Système de gestion d'ABC, source des magasins, articles et commandes |
| **Portefeuille** | Magasins rattachés à un promoteur par son code représentant |
| **Code représentant** | Code ERP du promoteur ; « 68 » et « 068 » désignent le même |
