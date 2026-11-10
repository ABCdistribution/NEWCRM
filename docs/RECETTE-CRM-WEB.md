# Fiche de recette manuelle — crm-web

Application unique (Next 15, port 3001) qui a fusionné ABC Sales (ex-`crm-promoteur`) et ABC Pilot (ex-`crm-helios`). Les deux anciens fronts ont été supprimés le 2026-11-10 (code lisible dans l'historique git, commit `4c5e7b6`).
Fiche destinée à la personne qui teste avec de **vrais comptes Active Directory**.

- Branche : `refonte/front-unique`. Rédigée le 2026-11-09.
- **Statut : à exécuter.** Aucun écran n'a été ouvert avec une session lors de la rédaction (la connexion AD est impossible hors réseau ABC). Tous les résultats « attendus » sont **déduits de la lecture du code** : `crm-web/src/lib/routes.ts`, `roles.ts`, `redirections.ts`, et le `requireRole` de chaque page. Un écart entre cette fiche et ce que vous voyez est une anomalie à consigner, dans un sens ou dans l'autre.
- Les données (listes, chiffres, périmètre) sont filtrées **par l'API** selon le rôle et le périmètre (utilisateur, secteur, région) : le front n'en filtre aucune. Les contrôles de périmètre ci-dessous vérifient donc l'API autant que le front.

Légende des tableaux : **OK** = page affichée ; **Refusé** = écran « Accès refusé » à la place de la page (menu conservé, URL inchangée) ; **→ cible** = redirection ; **404** = « Page introuvable ». Cases à cocher : `[ ]` à faire, `[x]` conforme ; noter tout écart dans la marge ou dans le tableau de synthèse (§7).

---

## 1. Prérequis

### 1.1 Réseau, base, API, front

1. **VPN / réseau ABC** actif : la connexion passe toujours par l'Active Directory, y compris en local (il n'existe volontairement aucun login de contournement).
2. `crm-api/.env` présent (jamais versionné, ne le recopiez nulle part) avec au minimum `DATABASE_URL`, `JWT_SECRET`, `JWT_EXPIRES_IN`, `PORT`, les variables `LDAP_*` et `ADMIN_USERNAMES`.
3. Base locale démarrée et à jour :
   ```
   docker compose up -d db
   set -a; . crm-api/.env; set +a; pnpm --filter @crm/database exec prisma migrate deploy
   pnpm --filter @crm/database run db:generate
   ```
4. API sur le port **4000** : `cd crm-api && pnpm start:dev` (Swagger sur `/docs`).
5. Front crm-web sur le port **3001** :
   ```
   cd crm-web
   pnpm install --ignore-workspace
   pnpm dev
   ```
   (`API_URL` vaut `http://localhost:4000` par défaut.) Ouvrir `http://localhost:3001`.
6. Les anciens fronts (ABC Sales sur 3000, ABC Pilot sur 3001) n'existent plus ; crm-web a repris le port 3001. Aucune comparaison côte à côte n'est possible, voir URL-05.

### 1.2 Comptes de test (un compte AD par rôle)

Le rôle d'un compte est posé par son OU Active Directory à chaque connexion : **un rôle changé à la main dans Administration est écrasé au login suivant** (BACKLOG 2.1). Pour tester un rôle, il faut donc un compte réellement placé dans la bonne OU (ou `ADMIN_USERNAMES` pour ADMIN).

| Rôle | Compte AD à utiliser (à renseigner) | Pré-requis de données |
|---|---|---|
| COMMERCIAL | | Code représentant (`idRepr`) et clients rattachés ; idéalement des visites planifiées cette semaine et quelques commandes |
| CHEF_SECTEUR | | Secteur renseigné, au moins 2 promoteurs rattachés |
| DIRECTEUR_REGIONAL | | Région renseignée, au moins 2 chefs de secteur rattachés |
| DIRECTION | | — |
| ADMIN | | Présent dans `ADMIN_USERNAMES` |
| ADV *(à part, provisoire)* | | Compte AD ADV si disponible |
| MARKETING *(à part, provisoire)* | | Compte AD MARKETING si disponible |

Avant chaque série : se connecter, regarder le libellé sous le nom, en haut à droite dans le bandeau (« Chef de secteur », « Promoteur des ventes »…) pour confirmer le rôle réellement reçu.

### 1.3 Précautions

- **Base locale uniquement.** Les jeux de démonstration (`seed.cjs`, `seed-prospection.cjs`, base LOCALE seulement) ou une copie non productive suffisent. Ne jamais lancer d'import ni de seed contre la production, ne rien tester en production.
- Des écrans **écrivent vraiment** : notes et contacts de clients, périodicité, planning de l'équipe, relances (une notification part chez le promoteur), prospects (étape, conversion en client), news, promos/PEM, administration (rôle, activation, secteur, synchro AD, synchro Minos). Les faire sur des données de test.
- **Valider un rapport d'activité verrouille la semaine** (irréversible, boutons « Valider le rapport »). Le faire sur une semaine sans enjeu.
- **Ne pas multiplier les mauvais mots de passe** : l'API ne limite pas encore les tentatives de connexion (BACKLOG 1.4), un verrouillage du compte AD est possible.
- **Un seul compte à la fois par navigateur** : le cookie de session `crm_session` est propre à l'hôte, pas au port. Se déconnecter entre deux comptes, ou utiliser un profil de navigateur par compte.
- Test d'un build de production derrière HTTP (`pnpm build` puis `pnpm start`) : sur une adresse autre que `localhost`, définir `COOKIE_SECURE=false` pour crm-web, sinon la session ne tient pas (BACKLOG 1.11). En `pnpm dev`, rien à faire.

### 1.4 Contrôles automatiques à lancer avant la recette (non exécutés pour cette fiche)

Dans `crm-web` : `npx tsc --noEmit`, `pnpm test`, `pnpm build`. La recette manuelle ne remplace pas ces trois commandes ; noter leur résultat ici : `tsc` ______ · `test` ______ · `build` ______.

---

## 2. Matrice rôle × page

Abréviations : COM = COMMERCIAL, CS = CHEF_SECTEUR, DR = DIRECTEUR_REGIONAL, DIR = DIRECTION, ADM = ADMIN. **ADV\*** et **MKT\*** (MARKETING) : rôles dont l'espace et le périmètre sont **à définir plus tard** ; leurs colonnes décrivent ce que fait le code aujourd'hui, sans engagement.

Source : table `routes.ts` **et** garde réellement présent dans chaque page (`requireRole`, et layouts de groupe `(direction)` = encadrement, `(promoteurs)` = COMMERCIAL, ADV et encadrement). Encadrement = ADM, DIR, DR, CS.

| Page (URL) | Menu | COM | CS | DR | DIR | ADM | ADV\* | MKT\* |
|---|---|---|---|---|---|---|---|---|
| `/` Accueil | oui | OK | OK | OK | OK | OK | OK | OK |
| `/news` | oui | OK | OK | OK | OK | OK | OK | OK |
| `/clients` | oui | OK | OK | OK | OK | OK | OK | OK |
| `/clients/[id]` | non | OK | OK | OK | OK | OK | OK | OK (lecture seule) |
| `/clients/[id]/visite` | non | Refusé | OK | OK | OK | OK | Refusé | Refusé |
| `/commandes` | oui | OK | OK | OK | OK | OK | OK | OK |
| `/commandes/[id]` | non | OK | OK | OK | OK | OK | OK | OK |
| `/visites` | oui | OK | OK | OK | OK | OK | OK | OK |
| `/produits` | oui | OK | OK | OK | OK | OK | OK | OK |
| `/promos` | oui | OK (lecture) | OK (lecture) | OK (lecture) | OK (édition) | OK (édition) | OK (lecture) | OK (édition) |
| `/qualite` | oui | OK | OK | OK | OK | OK | OK | OK |
| `/planning` | oui (COM et encadrement) | OK (lecture seule) | OK (éditable) | OK (éditable) | OK (éditable) | OK (éditable) | OK (lecture seule, **URL seulement**, voir note a) | Refusé |
| `/planning-equipe` | oui | Refusé | OK | OK | OK | OK | Refusé | Refusé |
| `/prospects`, `/prospects/[id]` | oui | Refusé | OK (écriture) | OK (écriture) | OK (lecture seule) | OK (écriture) | Refusé | Refusé |
| `/mon-equipe` | oui | Refusé | OK | OK | Refusé | OK | Refusé | Refusé |
| `/mon-equipe/[id]` (fiche chef de secteur) | non | Refusé | Refusé | OK | Refusé | OK | Refusé | Refusé |
| `/mon-equipe/[id]/planning` | non | Refusé | Refusé | → `/mon-equipe/[id]?onglet=planning` | Refusé | → idem | Refusé | Refusé |
| `/mon-equipe/promoteur/[id]` | non | Refusé | OK | OK | Refusé | OK | Refusé | Refusé |
| `/rapports` | oui | Refusé | Refusé | OK | OK | OK | Refusé | Refusé |
| `/alertes` (maquette) | oui | Refusé | OK | OK | OK (+ bouton Règles) | OK (+ bouton Règles) | Refusé | Refusé |
| `/admin` | oui | Refusé | Refusé | Refusé | Refusé | OK | Refusé | Refusé |
| `/parametres` | non | Refusé | Refusé | Refusé | Refusé | → `/admin?onglet=configuration` | Refusé | Refusé |
| `/users` | non | Refusé | → `/admin?onglet=utilisateurs` puis Refusé | → idem | → idem | → `/admin?onglet=utilisateurs` | Refusé | Refusé |
| `/agenda` (page « bientôt ») | non (voir note b) | OK | Refusé | Refusé | Refusé | Refusé | OK | Refusé |

Pour `/users`, COM, ADV et MKT obtiennent « Refusé » (layout Direction), éventuellement après la redirection vers `/admin` : l'issue est la même.

Autres adresses :

| Adresse | Comportement attendu |
|---|---|
| `/login` | Publique. Thème violet. Un utilisateur déjà connecté n'est volontairement **pas** renvoyé vers `/`. |
| Toute adresse protégée **sans cookie** | Redirection vers `/login?from=<adresse demandée>` ; après connexion, retour sur cette adresse. |
| `/avatar/[id]` | Photo de l'utilisateur (menu). Id non UUID ou introuvable : réponse vide 404. |
| `/pj/[id]/[pjId]` (pièce jointe de prospect) | Encadrement : téléchargement forcé (`attachment`). Tout autre rôle, session absente, id non UUID : réponse vide **404** (pas d'écran). |
| Adresse inconnue (`/nimportequoi`) | « Page introuvable », **sans menu** (404 racine). |
| `/clients/abc`, `/commandes/abc`, `/prospects/abc`, `/mon-equipe/abc` (id non UUID, avec un rôle autorisé sur la page) | « Page introuvable » **avec menu** (404 de l'application connectée). |

### Droits d'écriture et de gestion (boutons et actions)

| Capacité | Rôles | Où |
|---|---|---|
| Gérer les news (créer, modifier, publier, dépublier, supprimer ; voir les brouillons) | ADM, MKT | `/news` |
| Éditer promos et PEM | ADM, DIR, MKT | `/promos` |
| Éditer contacts, notes, périodicité d'un client | COM, ADV, CS, DR, DIR, ADM (pas MKT) | `/clients/[id]` |
| Mettre à jour la livraison d'une commande | ADV, DIR, ADM | `/commandes/[id]` |
| Écrire sur les prospects (création, étape, coordonnées, conversion) | ADM, DR, CS (DIR en lecture seule) | `/prospects`, `/prospects/[id]` |
| Notes, appels, emails, pièces jointes de prospect | Tout l'encadrement, DIR compris | `/prospects/[id]` |
| Visite commerciale (bouton et questionnaire) | Encadrement | fiche client |
| Planning de l'équipe : ajouter, déplacer, supprimer une visite, récurrence, relance | Encadrement | `/planning-equipe` |
| Planning d'activité : éditer, enregistrer la prévision, valider | Encadrement | `/planning` |
| Détail d'un rapport d'activité | ADM, DIR, DR | `/rapports` |
| Règles d'alertes (bouton « Règles ») | ADM, DIR | `/alertes` |
| Administration : utilisateurs, synchro AD, synchro Minos | ADM | `/admin` |

### Écarts table / pages relevés à la lecture (à connaître avant de tester)

- **a. `/planning` et ADV** : `routes.ts` ne liste que COMMERCIAL et l'encadrement, mais la page ouvre sa vue « lecture » à tout le terrain (COMMERCIAL **et ADV**). ADV n'a donc pas d'entrée de menu mais atteint la page par son URL. Écart déjà connu et couvert par un test automatique ; à trancher avec la décision sur ADV (§6).
- **b. `/agenda`** : listée pour COMMERCIAL et ADV mais sans `menu: true` : aucune entrée de menu pour personne, atteignable par URL seulement. Le groupe `(promoteurs)` laisse passer l'encadrement, mais la page `/agenda` le refuse (garde `COMMERCIAL`, `ADV`). Contenu : page « bientôt ».
- **c.** Les sous-pages `/mon-equipe/[id]` et `/mon-equipe/promoteur/[id]` portent leurs propres listes de rôles (hors table), comme l'annonce le commentaire de `routes.ts`.

---

## 3. Contrôles par rôle

Pour chaque rôle : se connecter avec le compte du §1.2, faire la série, se déconnecter.

**Repérer le thème** : bleu (ABC Sales, `data-espace="promoteurs"`, profils promoteur et ADV : palette bleu principal `#0866F5` pour la navigation et les boutons, bleu royal `#247CF4` pour les accents, bleu ciel `#24A8F2` en série secondaire des graphiques, bleu très clair `#EAF4FF` pour les badges, vert succès `#19C98A` et orange `#FF9D23` pour les indicateurs, fond du contenu `#F3F8FF`, texte `#17253B`) ou violet (ABC Pilot, `data-espace="direction"`, tous les rôles sauf promoteur : palette violet foncé `#7656B8` pour la navigation, les boutons et les graphiques, violet clair `#A98AE9` pour les accents, rose principal `#E76AA5` en série secondaire des graphiques, rose pastel `#F8E7F0` pour les badges, vert menthe `#39C98A` pour les indicateurs positifs, jaune citron `#CFD46B` pour les indicateurs à surveiller, bleu nuit `#202B3A` pour les titres et textes). **Le fond du contenu est un gris-bleu très clair : `#f6f8fa` en Direction, `#f3f8ff` pour les profils promoteur et ADV**, comme le menu et les cartes en blanc ; le menu latéral (et la barre du haut sur mobile) est **blanc plein**, avec l'entrée active teintée de la couleur de l'espace ; les cartes sont blanches. Seuls les accents (titres du menu, entrée active, boutons, graphes) distinguent bleu et violet. Moyen sûr et rapide : outils de développement du navigateur, chercher l'attribut `data-espace` (sur le `div` racine de l'application, sur `main` pour `/login`). Le thème suit le **rôle**, pas la page : l'encadrement garde le violet même sur les écrans « terrain ». Aucun dégradé de couleur nulle part (menu, connexion, bandeaux : aplats).

### 3.0 Contrôles communs (à faire une fois, puis répéter la ligne « menu / thème » pour chaque rôle)

- [ ] **GEN-01** Connexion avec un identifiant ou un mot de passe faux : message « Identifiant ou mot de passe incorrect. », aucun détail sur l'existence du compte.
- [ ] **GEN-02** Connexion correcte : arrivée sur `/` (ou sur la page demandée si l'adresse portait `?from=`).
- [ ] **GEN-03** Déconnexion (icône à droite du bandeau du haut, « Déconnexion ») : retour sur `/login` ; le bouton « Précédent » du navigateur ne ré-affiche **aucune** page protégée ; rouvrir `/` renvoie vers `/login`.
- [ ] **GEN-04** Cloche de notifications (bandeau du haut, à gauche de la photo ; le panneau s'ouvre vers le bas) présente pour tous les rôles ; ouvrir une notification mène à une page valide de crm-web (jamais un 404, y compris pour une notification ancienne dont le lien visait `/tournees` ou `/pilotage/ma-tournee`).
- [ ] **GEN-08** Bandeau du haut (blanc, au-dessus du contenu, fixe sur ordinateur) : **recherche générale** à gauche, cloche, photo + nom + poste (ou rôle) et déconnexion à droite. Saisir au moins 2 lettres : les résultats s'affichent après un court délai, groupés par famille (**Clients, Commandes, Visites, Collaborateurs, Prospects, Produits**, 5 lignes au plus chacune, « Voir les N résultats » quand il y en a davantage). Plusieurs mots : tous doivent se retrouver (« auchan rouen »). Un résultat mène à sa fiche (client, commande, prospect), à la liste filtrée (visite, produit) ou à la fiche « Mon équipe » (collaborateur) **seulement si le rôle peut l'ouvrir** ; sinon la ligne reste affichée sans lien. Clavier : flèches haut/bas, Entrée ouvre la ligne choisie (sinon la première), Échap ferme puis efface. **Périmètre à vérifier par rôle** : COMMERCIAL ne trouve que ses clients, ses commandes et ses visites, et aucun collaborateur ni prospect ; CS = ses promoteurs ; DR = sa région ; DIRECTION / ADMIN / ADV / MARKETING = tout ce que leurs listes montrent (ADV et MARKETING : ni collaborateurs ni prospects) ; les produits sont ouverts à tous. Aucun e-mail, téléphone ni montant dans les résultats. **Chef de secteur et directeur régional** : sous le nom, une ligne d'**activité du mois** (« 0 visite · 0 commande · CA 0 € · objectif non défini », avec le pourcentage et une teinte selon l'objectif quand il existe), visible à partir de 1024 px de large ; absente pour les autres rôles (promoteur, ADV, direction, admin, marketing). Elle ne concerne que la personne connectée (visites faites, commandes et CA de son code représentant, objectif de ses magasins ÷ 12) ; un directeur régional sans code représentant a donc des commandes et un CA à zéro.
- [ ] **GEN-05** Largeur < 768 px : barre supérieure avec hamburger, tiroir de menu (fermé par Échap, par le voile ou par une navigation), tableaux remplacés par des cartes.
- [ ] **GEN-06** Bandeau du haut, à droite : nom, photo (ou initiales) et fonction (« Administrateur », « Direction », « Directeur régional », « Chef de secteur », « Promoteur des ventes », « ADV », « Marketing ») cohérents avec le compte.
- [ ] **GEN-07** Sous-titre sous « ABC » en haut du menu : « Promoteurs » (espace bleu) ; **aucun** dans l'espace violet (rien sous « ABC »).

### 3.1 COMMERCIAL

- [ ] **COM-01** Thème **bleu** ; sous-titre « Promoteurs ».
- [ ] **COM-02** Menu exact : (sans titre) Accueil, Les News · **Mon terrain** : Mon planning, Les visites, Les commandes · **Catalogue** : Les clients, Les produits, Les promos / PEM, Qualité & rappels. **Absents** : Planning de l'équipe, Prospection, Mon équipe, Alertes, Rapports d'activité, Administration.
- [ ] **COM-03** Accueil « Mes performances » : sélecteur de mois (flèches précédent / suivant, URL `?annee=&mois=`), tuiles « CA du mois vs objectif », « Commandes », « Visites », « Couverture portefeuille », cartes « Top de mes clients » et « À relancer — sans commande ce mois », graphiques (évolution CA / commandes, répartition des visites par région). Chiffres cohérents avec les commandes du compte.
- [ ] **COM-04** `/?annee=abc&mois=99` : pas d'erreur, retombe sur le mois courant.
- [ ] **COM-05** Compte sans code représentant (si disponible) : message « Compte non relié à l'ERP » et pas de chiffres. *(Point connu côté API : sans `idRepr`, certaines routes basculent en vue globale ; le noter si vous voyez des chiffres d'autres promoteurs, ce n'est pas un nouveau trou.)*
- [ ] **COM-06** `/clients` : **liste des clients unique** (plus d'onglets Suivi / Portefeuille, plus de carte) : en tête le nombre de clients, avec **actifs** et **inactifs** ; barre de filtres : recherche (enseigne, raison sociale, code AS400, **ville, code postal** ; plusieurs mots = tous doivent se retrouver), **niveau** (Tous / A à G / Sans niveau), **état** (Clients actifs par défaut / inactifs / tous), « Réinitialiser » (grisé tant qu'aucun filtre n'est modifié) ; colonnes **Enseigne** (pastille « Nouveau » sous 30 jours), **Code AS400**, **Ville / CP**, **Niveau**, **Statut** ; toute la ligne ouvre la fiche ; pagination de 50 qui conserve les filtres. Filtre **« Mes clients »** coché par défaut : uniquement les clients de mon code représentant, compteurs compris, libellé « clients dans mon secteur » ; le décocher (`?tous=1`) élargit à tout le référentiel (comportement hérité, le contournement de périmètre est côté API, BACKLOG 1.1).
- [ ] **COM-07** Filtre « État » Tous / Actifs / Inactifs : la liste change sur **tous** les résultats (pas seulement la page affichée), la recherche et la pagination conservent le filtre dans l'URL.
- [ ] **COM-08** Fiche client : blocs Identité (« Minos · lecture »), Organisation (secteur, centrale d'achat, commerciaux), Périodicité, Contacts, Notes, CA mensuel N-1 / N, Dernières commandes (« moi » sur mes commandes), Dernières visites. **Aucun** bouton « Visite commerciale ».
- [ ] **COM-09** Édition sur une fiche de test : ajouter, modifier, supprimer un contact ; ajouter une note ; changer la périodicité. Chaque modification persiste après rechargement de la page.
- [ ] **COM-10** `/commandes` : titre « Mes commandes » et case **« Mes commandes »** cochée par défaut (uniquement les commandes de mon code représentant) ; la **décocher** (`?tous=1`) affiche toutes les commandes et le titre devient « Commandes » (décision de l'utilisateur : un promoteur peut passer sur « Toutes »). **Pas** de bandeau d'indicateurs (réservé à l'encadrement) ; recherche (n° de commande, client, code) ; filtre « Annulées ». Un promoteur **sans code représentant** voit 0 commande en « Mes commandes » (et non plus toutes).
- [ ] **COM-11** Filtre **Livraison** (Toutes, Expédiée, Livrée : ni « En préparation » ni « Livrée partielle » dans les filtres, dont les pastilles restent affichées sur les commandes concernées) et filtre **Origine** (Toutes / Appli / EDI) : « EDI » → URL `?origine=edi`, toutes les lignes portent le badge EDI ; « Appli » → badge Appli ; « Toutes » retire le filtre ; les filtres se combinent entre eux et avec la recherche et la pagination. *(Règle provisoire côté code : saisie mobile = Appli, sinon EDI.)*
- [ ] **COM-12** Fiche commande : lecture seule, **pas** d'éditeur de livraison (réservé ADV, DIRECTION, ADMIN).
- [ ] **COM-13** `/visites` : titre « Mes visites » et case **« Mes visites »** cochée par défaut (mes seules visites, sans colonne Promoteur) ; la décocher (`?tous=1`) affiche toutes les visites avec la colonne Promoteur, titre « Visites » ; clic sur une visite → fiche du client.
- [ ] **COM-14** `/produits` : **une ligne de chiffres compacte** (plus de grandes cartes) : références, promos actives, mises en avant, en rappel (point orange quand il y en a) ; recherche ; **filtres** : boutons à bascule **« Promos / PEM »** (produits en promotion en cours ou mis en avant) et **« En rappel »** (combinables, `?promo=1&rappel=1`), sélecteur **« Toutes les marques »** (marque et nombre d'articles, `?marque=`), « Réinitialiser » quand un filtre est actif ; les filtres se combinent avec la recherche et se conservent en pagination ; cartes < md.
- [ ] **COM-15** `/promos` : « Promotions en cours » et « Mises en avant » en **lecture seule**, aucun bouton d'édition.
- [ ] **COM-16** `/qualite` : « Qualité & Rappels Produits », carte « Produits en rappel », bordereaux avec bandeau « Données d'exemple » (données fictives).
- [ ] **COM-17** `/planning` : « Mon planning », **lecture seule** (aucun bouton d'ajout, de déplacement ni de suppression) ; navigation Préc. / Suiv. / Aujourd'hui ; légende Effectuée, Manquée, À venir, Visite récurrente ; compteur « x/y visites effectuées » ; samedi et dimanche affichés seulement s'ils portent une visite ; clic sur une visite → fiche client. Les visites correspondent à ce que le chef de secteur a planifié.
- [ ] **COM-18** `/news` : lecture seule, aucun bouton « Nouvelle news », brouillons invisibles.
- [ ] **COM-19** Accès direct refusé (menu conservé, « Accès refusé ») : `/planning-equipe`, `/prospects`, `/mon-equipe`, `/rapports`, `/alertes`, `/admin`, `/parametres`, `/users`, `/clients/<id>/visite`.
- [ ] **COM-20** `/agenda` : page « Mon agenda » (bientôt), bleue.
- [ ] **COM-21** Relance reçue : après qu'un chef de secteur a cliqué « Relancer » (voir CS-12), la cloche affiche la notification et son lien ouvre une page valide.
- [ ] **COM-22** Déconnexion (GEN-03) ; expiration (§5.1).

### 3.2 CHEF_SECTEUR

- [ ] **CS-01** Thème **violet** ; aucun sous-titre sous « ABC ».
- [ ] **CS-02** Menu exact, dans cet ordre : Accueil, Les News · **Pilotage** : Prospection, Mon équipe, Alertes · **Terrain** : Mon planning d'activité, Planning de l'équipe, Les visites, Les commandes · **Catalogue** : Les clients, Les produits, Les promos / PEM, Qualité & rappels. **Absents** : Rapports d'activité, Administration.
- [ ] **CS-03** Accueil « Mon secteur » : sélecteur de mois, CA mensuel N-1 / N, « Couverture du mois », « À relancer — sans commande ce mois », « Promoteurs en baisse vs N-1 », « Objectif vs CA réalisé — par client », « Mon équipe — performance du mois », carte du secteur en points, lien vers Alertes marqué « maquette ». *(Connu côté API : le bloc prospection et le nuage objectif / CA d'un CS couvrent tout le réseau, BACKLOG ; noter, ne pas signaler comme nouveau.)*
- [ ] **CS-04** `/clients` : **liste des clients unique** (plus d'onglets Suivi / Portefeuille, plus de carte) : en tête le nombre de clients, avec **actifs** et **inactifs** ; barre de filtres : recherche (enseigne, raison sociale, code AS400, **ville, code postal** ; plusieurs mots = tous doivent se retrouver), **niveau** (Tous / A à G / Sans niveau), **état** (Clients actifs par défaut / inactifs / tous), « Réinitialiser » (grisé tant qu'aucun filtre n'est modifié) ; colonnes **Enseigne** (pastille « Nouveau » sous 30 jours), **Code AS400**, **Ville / CP**, **Niveau**, **Statut** ; toute la ligne ouvre la fiche ; pagination de 50 qui conserve les filtres. Filtre **« Mes clients »** coché par défaut : uniquement les clients de **mes promoteurs** (mon secteur), compteurs compris ; décoché (`?tous=1`), tout le référentiel.
- [ ] **CS-05** `/clients?niveau=D&statut=inactifs&search=…` : chaque filtre est dans l'adresse, se combine avec les autres, ramène à la page 1 et se conserve en pagination ; une valeur inconnue (`niveau=Z`, `statut=x`) est ignorée.
- [ ] **CS-05b** `/clients`, bouton **« Clients passés inactifs »** (encadrement et ADV ; absent pour le promoteur et le marketing) : ouvre une fenêtre (Échap ou clic à côté pour fermer, le focus revient sur le bouton) avec le choix du **mois** (mois courant par défaut), le nombre de clients, **Exporter CSV** (désactivé sans ligne) et le tableau **Enseigne** (pastille « Retiré de l'AS400 »), **Code**, **Ville**, **Date**, **Modifié par**, **DR**, **Envoyé à l'ADV** (date d'envoi avec coche, ou « Non envoyé : client retiré de l'AS400 »). **Aujourd'hui l'API n'enregistre pas cet historique** : la fenêtre annonce « L'historique des passages en inactif n'est pas encore enregistré par le CRM » (ni liste vide, ni export). À recetter quand l'historique existera : bornage au périmètre (DR : sa région, CS : ses promoteurs) et le CSV ouvert dans Excel (accents, une formule `=…` ressort comme texte).
- [ ] **CS-06** Fiche client : bouton **« Visite commerciale »** présent → `/clients/<id>/visite` (questionnaire, retour fiche) ; édition des contacts, notes et périodicité **autorisée**.
- [ ] **CS-07** `/commandes` : bandeau d'indicateurs **du jour à l'ouverture** (CA du jour, Commandes du jour, Panier moyen, Clients commandants), avec le bouton **« Ce mois »** qui bascule sur le mois en cours (`?stats=mois`) et « Aujourd'hui » pour revenir ; chiffres bornés au périmètre du rôle (CS = ses promoteurs, DR = sa région) ; filtres Annulées, Livraison, **Origine EDI / Appli** comme en COM-11 ; pas d'éditeur de livraison sur la fiche commande. *(Connu côté API : `GET /commandes`, `/commandes/:id` ne filtrent pas le périmètre pour CS / DR : une commande hors secteur peut s'afficher ; la noter comme « écart connu », pas comme nouvelle faille.)*
- [ ] **CS-08** `/visites` : visites du périmètre du compte ; titre « Visites » avec colonne Promoteur si l'API renvoie une portée globale, sinon « Historique de visites » sans cette colonne. Noter la variante obtenue, et vérifier qu'aucune visite hors secteur n'apparaît. **« Mes visites » / « Mes commandes »** : cochée par défaut (visites de mon équipe ; commandes de mes promoteurs pour le CS, de ma région pour le DR) ; décochée (`?tous=1`), toutes.
- [ ] **CS-09** `/planning` : « Mon planning d'activité », **éditable** (tournée prévue, tournée réalisée, rapport) ; pastille d'état de la semaine (« Prévision à saisir », « Prévision enregistrée le… », « Rapport en cours », « Rapport validé ») ; glisser des magasins et des prospects dans la tournée ; navigation de semaine. **Ne pas tester** le bouton « Synchroniser avec Outlook » (reporté, §6).
- [ ] **CS-10** Enregistrer la prévision de la semaine ; dès le mardi, la prévision figée s'affiche au-dessus de la tournée ; « Valider le rapport » demande une confirmation puis verrouille la semaine (**irréversible**, semaine de test).
- [ ] **CS-11** `/planning-equipe` : liste déroulante des **seuls promoteurs de mon secteur** ; navigation de semaine ; lien « Voir la fiche » présent ; ajouter une visite chez un client du promoteur, la déplacer, la supprimer ; carte « Clients récurrents » (« Créer la récurrence », suppression d'une règle ; les visites des semaines à venir sont générées par le serveur) ; promoteur sans client rattaché : message explicite, aucun ajout possible.
- [ ] **CS-12** Sur une visite **manquée** : bouton « Relancer » → message « Relance envoyée au promoteur pour <client>. » ; la notification arrive chez le promoteur (COM-21).
- [ ] **CS-13** `/mon-equipe` : « Mon équipe », « N promoteurs · <secteur> », liste des promoteurs du secteur uniquement ; clic → `/mon-equipe/promoteur/<id>` (indicateurs « Visites de la semaine » et « CA du mois / objectif », onglets Planning, Visites, Commandes, sélecteur de client sur les onglets Visites et Commandes, bouton « Modifier le planning » → `/planning-equipe?promoteur=…`).
- [ ] **CS-14** `/mon-equipe/promoteur/<id d'un promoteur d'un autre secteur>` : « Page introuvable » (la liste d'utilisateurs est filtrée par l'API).
- [ ] **CS-15** `/prospects` : tuiles « Prospects actifs », « À relancer », « Transformation » ; Kanban par étape (glisser-déposer) ; liste paginée ; bouton de création de prospect ; **écriture autorisée**. Créer un prospect, changer son étape, modifier ses coordonnées, ajouter une note ; à l'étape « Gagné » et non converti, « Convertir en client » (crée un client : données de test). Déposer puis télécharger une pièce jointe (téléchargement forcé).
- [ ] **CS-16** `/alertes` : bandeau « Données d'exemple » (maquette) ; **pas** de bouton « Règles » ; « Exporter » télécharge `alertes-exemple.csv`.
- [ ] **CS-17** Refusés : `/rapports`, `/admin`, `/parametres`, `/mon-equipe/<id d'un chef de secteur>`, `/agenda` ; `/users` redirige vers `/admin?onglet=utilisateurs` qui affiche « Accès refusé ».
- [ ] **CS-18** `/news` et `/promos` en lecture seule.
- [ ] **CS-19** Déconnexion (GEN-03) ; expiration (§5.1).

### 3.3 DIRECTEUR_REGIONAL

- [ ] **DR-01** Thème **violet** ; aucun sous-titre sous « ABC ».
- [ ] **DR-02** Menu exact : comme le CS (Pilotage en premier), plus **Rapports d'activité** : Pilotage = Prospection, Mon équipe, Alertes, Rapports d'activité. **Absent** : Administration.
- [ ] **DR-03** Accueil (« Pilotage force de vente », titre invisible) **sans en-tête visible** (ni titre, ni « Bonjour … », ni sélecteur de mois : le mois est le mois en cours, modifiable par l'adresse `?annee=&mois=`) et **carte des équipes seule** (plus de tuiles de CA, de graphiques, de classement des promoteurs, de « CA par secteur » ni de « Sans commande ce mois » sous la carte) ; le mois de l'adresse pilote le CA affiché par secteur ; **pas de carte de France** pour le directeur régional (une ou deux régions) : ni carte, ni liste des secteurs, ni pastilles de filtre ; la recherche, la tuile « CA réalisé / Objectif à date » et, **directement dessous, l'équipe de chaque région** (bilan du mois, direction, chefs de secteur et promoteurs avec leur activité) s'affichent. **La personne connectée n'est pas relistée** dans la section « Direction » (son activité est dans le bandeau du haut) ; la section disparaît quand elle n'avait personne d'autre.
- [ ] **DR-04** `/clients` : comme CS-04, avec « Mes clients » = les clients de **ma région**.
- [ ] **DR-05** `/commandes`, `/visites`, `/produits`, `/qualite`, `/promos` (lecture), `/news` (lecture) : comme CS (bandeau d'indicateurs du jour, bascule « Ce mois », sur les commandes ; écart de périmètre connu sur les commandes).
- [ ] **DR-06** `/planning` éditable ; `/planning-equipe` : promoteurs de la **région** ; mêmes actions qu'en CS-11 et CS-12.
- [ ] **DR-07** `/mon-equipe` : liste déroulante « Chefs de secteur » / « Promoteurs » + filtre de région ; cartes des chefs de secteur ; si le périmètre est vide : message « Aucun chef de secteur ni promoteur dans votre périmètre ».
- [ ] **DR-08** Clic sur un chef de secteur → `/mon-equipe/<id>` : onglets **Planning** (« Planning en lecture seule » + carte du rapport de la semaine, navigation de semaine), **Visites**, **Commandes**, **Promoteurs** ; retour « Retour à Mon équipe ».
- [ ] **DR-09** `/mon-equipe/<id>/planning` redirige vers `/mon-equipe/<id>?onglet=planning` (la semaine `?semaine=` est conservée si valide) ; avec un id non UUID, redirige vers `/mon-equipe`.
- [ ] **DR-10** `/mon-equipe/promoteur/<id>` accessible ; hors région : « Page introuvable ».
- [ ] **DR-11** `/rapports` : tableau des rapports d'activité de la semaine, navigation de semaine, ouverture du détail d'un rapport (tournée prévue et réalisée). `?semaine=2026-13-45` retombe sur la semaine courante.
- [ ] **DR-12** `/prospects` : écriture autorisée (comme CS-15).
- [ ] **DR-13** `/alertes` : maquette, pas de bouton « Règles ».
- [ ] **DR-14** Refusés : `/admin`, `/parametres`, `/agenda` ; `/users` → `/admin` → « Accès refusé ». Autorisé (encadrement) : `/clients/<id>/visite`.
- [ ] **DR-15** Déconnexion (GEN-03) ; expiration (§5.1).

### 3.4 DIRECTION

- [ ] **DIR-01** Thème **violet** ; aucun sous-titre sous « ABC ».
- [ ] **DIR-02** Menu exact, dans cet ordre : Accueil, Les News · **Pilotage : Prospection, Alertes, Rapports d'activité** · Terrain (Mon planning d'activité, Planning de l'équipe, Les visites, Les commandes) · Catalogue (Les clients en tête, puis 3 entrées). **Absents** : **Mon équipe**, Administration.
- [ ] **DIR-03** Accueil « Pilotage force de vente » (toute la force de vente), carte des équipes (accueil **sans titre ni phrase de bienvenue** ; la **barre de recherche** de la carte ouvre le bloc ; à sa droite, la tuile **« CA réalisé / Objectif à date »** affiche « — / — bientôt disponible » tant que l'API ne fournit pas la donnée ; les **pastilles de filtre** sont en toutes lettres et dans l'ordre de l'annuaire : Toutes, Île-de-France, Nord-Ouest, Nord-Est, Sud-Est, Sud-Ouest, Benelux, Corse, la liste des secteurs suit le même ordre) : **même carte que l'annuaire intranet** (7 formes : IDF, NORD OUEST, NORD EST, SUD EST, SUD OUEST, BENELUX avec « Belgique », CORSE annotée par un trait), mêmes teintes, chaque région avec son effectif (directeurs régionaux + chefs de secteur + promoteurs : mêmes chiffres que l'annuaire). Survol d'une région : halo. Clic sur une région (carte, pastille ou liste) : **la carte et la liste des secteurs se replient avec une animation** (fondu et réduction), l'équipe prend la place, un bouton « Retour à la carte » la rouvre (avec « Toutes » ou en recliquant la pastille) ; avec « réduire les animations » activé dans le système, le repli est immédiat. Le détail : **bilan du mois** (visites, commandes, CA, et CA comparé à l'objectif avec sa barre : vert à 90 % et plus, orange de 70 à 89 %, rouge en dessous, « objectif non défini » sans objectif), la **direction**, les **chefs de secteur avec leurs promoteurs** et les « autres promoteurs de la région » (chef d'une autre région ou sans chef), chacun avec sa **photo** (celle de l'AD, sinon celle de l'annuaire intranet reprise à la synchro AD ; initiales s'il n'y en a aucune), son poste AD et ses visites, commandes, CA et objectif du mois (le total de la région est la somme de ses membres ; les effectifs sont ceux de l'annuaire) ; une région sans effectif est estompée et inactive ; sous 640 px, étiquettes compactes. À droite de la carte, la liste des secteurs (sans titre ni texte explicatif) avec, pour chacun, le **CA du mois sur son objectif** (barre et pourcentage ; « objectif non défini » sans objectif), et non le nombre de collaborateurs (celui-ci reste sur la carte et dans les pastilles) ; aucune phrase d'explication sur l'écran. Sous la carte, **plus rien** : l'accueil Direction ne montre ni tuiles, ni graphiques, ni classement. Le Benelux n'apparaît avec son effectif qu'après une synchro AD qui l'a créé.
- [ ] **DIR-04** `/clients` (liste unique, **sans** filtre « Mes clients » : tout le référentiel), `/commandes` (bandeau d'indicateurs, filtres Origine EDI / Appli), `/visites`, `/produits`, `/qualite` : comme DR.
- [ ] **DIR-05** Fiche commande : **éditeur de livraison présent** (DIRECTION, ADV et ADMIN seulement) ; modifier le statut, recharger, vérifier la persistance.
- [ ] **DIR-06** `/promos` : **mode édition** (ajout, modification, retrait de promos et de PEM) ; changement visible ensuite chez un COMMERCIAL en lecture.
- [ ] **DIR-07** `/prospects` en **lecture seule** : pas de bouton de création, Kanban non déplaçable ; fiche prospect : étapes en lecture seule, coordonnées en lecture seule, **pas** de « Convertir en client » ; en revanche notes, appels, emails et pièces jointes restent possibles.
- [ ] **DIR-08** `/rapports` accessible (comme DR-11) ; `/planning-equipe` accessible mais **sans** lien « Voir la fiche » (la fiche promoteur est refusée à DIRECTION).
- [ ] **DIR-09** `/alertes` : bouton « Règles » **présent** (ouverture de la fenêtre de règles ; les règles ne sont mémorisées que dans le navigateur).
- [ ] **DIR-10** `/planning` éditable (planning d'activité).
- [ ] **DIR-11** Refusés : `/mon-equipe`, `/mon-equipe/promoteur/<id>`, `/mon-equipe/<id>`, `/admin`, `/parametres`, `/agenda` ; `/users` → `/admin` → « Accès refusé ».
- [ ] **DIR-12** Déconnexion (GEN-03) ; expiration (§5.1).

### 3.5 ADMIN

- [ ] **ADM-01** Thème **violet** ; aucun sous-titre sous « ABC ».
- [ ] **ADM-02** Menu exact : **Accueil, Administration, Les News** (Administration au-dessus de Les News, sans section propre, **sur fond jaune** pour ressortir ; marquée d'un anneau quand on est sur la page) · **Pilotage : Prospection, Mon équipe, Alertes, Rapports d'activité** (en premier, juste après ce bloc) · Terrain (4 : planning d'activité, planning de l'équipe, visites, commandes) · Catalogue (4, Les clients en tête). Pas d'entrée « Paramètres ».
- [ ] **ADM-03** Accueil « Pilotage force de vente » : comme DIR-03 (carte des équipes seule).
- [ ] **ADM-04** `/admin` : bandeau « Accès administrateur » ; colonne d'onglets : Vue d'ensemble, Utilisateurs, Organisation, Synchronisations, Mobile (« bientôt »), Contenus, Configuration (« bientôt »), Journal d'audit (« bientôt »). L'onglet actif est porté par `?onglet=` ; un onglet inconnu (`?onglet=xyz`) ouvre « Vue d'ensemble ».
- [ ] **ADM-05** Onglet **Utilisateurs** : recherche, filtres rôle / secteur / statut, pagination (paramètres d'URL conservés) ; changer un rôle, activer ou désactiver, rattacher un secteur **sur un compte de test**. Rappel : le rôle est réécrit par l'OU AD à la connexion suivante.
- [ ] **ADM-06** Onglet **Organisation** et **Vue d'ensemble** : données affichées, ou message « Données indisponibles — l'API est-elle démarrée ? » si l'API ne répond pas.
- [ ] **ADM-07** Onglet **Synchronisations** : bloc « Active Directory » (bouton de synchro, compte rendu), synchro Minos manuelle (fichiers de la zone d'échange), rapport des intégrations. **Base locale seulement.** Contrôler le compte rendu et le message d'erreur lisible si l'API ou la zone d'échange est injoignable. **Synchro AD** : pendant l'attente, bouton « Synchronisation… N s » et consigne (jusqu'à 3 minutes) ; à la fin, un bandeau reste affiché et est annoncé aux lecteurs d'écran : vert « Synchronisation réussie » (comptes lus, créés, mis à jour, photos, rattachés à un directeur, avec les avertissements : lecture tronquée à 1 000 comptes, comptes sans région reconnue, codes en conflit) ou rouge « La synchronisation a échoué » avec la cause (annuaire injoignable, délai de 3 minutes dépassé, synchro déjà en cours). Un second clic pendant une synchro doit être refusé (409). L'API journalise le début, la durée et la cause de l'échec ; ses échanges avec l'AD sont bornés (10 s de connexion, 2 min par opération, réglables par `LDAP_CONNECT_TIMEOUT_MS` et `LDAP_TIMEOUT_MS`).
- [ ] **ADM-08** Onglet **Contenus** : quatre cartes (Promos / PEM, Produits, Qualité & rappels produits, Les News) qui ouvrent la bonne page.
- [ ] **ADM-09** Onglets « bientôt » (Mobile, Configuration, Journal d'audit) : page d'attente, pas d'erreur.
- [ ] **ADM-10** `/parametres` redirige vers `/admin?onglet=configuration` ; `/users` redirige vers `/admin?onglet=utilisateurs`.
- [ ] **ADM-11** `/news` : **gestion complète** : « Nouvelle news » (titre, extrait, contenu en texte brut, image par adresse https), enregistrement en brouillon (pastille « Brouillon », visible seulement par ADM / MKT), publication (pastille « Publiée »), dépublication, suppression avec confirmation ; la news publiée est visible en lecture chez un COMMERCIAL.
- [ ] **ADM-12** `/promos` : mode édition ; fiche commande : éditeur de livraison ; `/prospects` : écriture ; `/alertes` : bouton « Règles » ; fiche client : édition et « Visite commerciale » ; `/rapports` accessible.
- [ ] **ADM-13** `/mon-equipe` (vue technique : tous les chefs de secteur et promoteurs), `/mon-equipe/<id>`, `/mon-equipe/promoteur/<id>`, `/planning-equipe` accessibles.
- [ ] **ADM-14** `/planning` : planning d'activité éditable.
- [ ] **ADM-15** `/agenda` : « Accès refusé » (page réservée à COMMERCIAL et ADV).
- [ ] **ADM-16** Déconnexion (GEN-03) ; expiration (§5.1).

### 3.6 ADV (provisoire : rien n'est défini, on observe seulement)

- [ ] **ADV-01** Thème **bleu** (ADV est classé « terrain ») ; sous-titre « Promoteurs ». Le rôle ADV vient de l'**OU « Service ADV »** de l'AD (siège), à la connexion comme à la synchro AD : un compte de cette OU n'est plus « Promoteur ». Pas de région, secteur, directeur ni code représentant, donc aucun avertissement « sans région / secteur » pour ces comptes ; un ancien promoteur devenu ADV quitte son secteur, son directeur et son code. Le rôle ADMIN n'est jamais rétrogradé par l'OU, ni à la connexion ni à la synchro.
- [ ] **ADV-02** Menu : Accueil, Les News · Terrain : Les visites, Les commandes · Catalogue : Les clients, puis 3 entrées. **Pas** de « Mon planning » (écart a du §2).
- [ ] **ADV-03** Accueil « Mes performances » : message neutre « Pas de chiffres personnels pour ce rôle » (pas de code représentant).
- [ ] **ADV-04** Fiche commande : éditeur de livraison **présent** ; vérifier la persistance.
- [ ] **ADV-05** Fiche client : boutons d'édition présents (ADV traité comme terrain, décision en attente) ; **pas** de « Visite commerciale ».
- [ ] **ADV-06** `/planning` par URL : vue « Mon planning » en lecture seule (page vide si aucune visite) ; `/agenda` : page « bientôt ».
- [ ] **ADV-07** Refusés : `/planning-equipe`, `/prospects`, `/mon-equipe`, `/rapports`, `/alertes`, `/admin`, `/clients/<id>/visite`.
- [ ] **ADV-08** **Noter** ce que l'API renvoie à ADV sur clients, commandes, visites (listes pleines, vides, ou limitées) pour la décision de périmètre (§6). Ne pas conclure : consigner.

### 3.7 MARKETING (provisoire : rien n'est défini, on observe seulement)

- [ ] **MKT-01** Thème **violet** (espace « direction » par défaut en attendant la décision). Le rôle MARKETING vient de l'**OU « Service Marketing »** de l'AD (siège, même règle que l'ADV) : la synchro AD lit alors 82 comptes au lieu de 64 (5 ADV et 13 marketing de plus) ; le groupe `Grp_Marketing` (45 membres de tous les services) n'est **pas** utilisé.
- [ ] **MKT-02** Menu : Accueil, Les News · Terrain : Les visites, Les commandes · Catalogue : Les clients, puis 3 entrées. Aucune autre entrée.
- [ ] **MKT-03** Accueil : « Bonjour <prénom> » et une seule carte « Les News » (accueil provisoire) qui mène à `/news`.
- [ ] **MKT-04** `/news` : **gestion complète** (comme ADM-11) ; `/promos` : **mode édition**.
- [ ] **MKT-05** Fiche client : **lecture seule** (aucun bouton d'édition de périodicité, contacts, notes) ; fiche commande : pas d'éditeur de livraison.
- [ ] **MKT-06** `/clients` : liste unique, sans filtre « Mes clients » (tout le référentiel).
- [ ] **MKT-07** Refusés : `/planning`, `/planning-equipe`, `/prospects`, `/mon-equipe`, `/rapports`, `/alertes`, `/admin`, `/agenda`, `/clients/<id>/visite`.
- [ ] **MKT-08** **Noter** ce que l'API renvoie à MARKETING sur clients, commandes, visites (périmètre à définir, §6).

---

## 4. Anciennes adresses à tester

Source : `crm-web/src/lib/redirections.ts` (table unique lue par `next.config.ts`). Les redirections sont **temporaires (307)** tant que la table n'est pas figée ; elles ne s'exécutent que pour une requête qui **arrive sur crm-web** : taper l'ancienne adresse **sur le port 3001** (les anciens favoris d'ABC Pilot, déjà sur 3001, arrivent directement sur crm-web ; ceux d'ABC Sales, sur 3000, ne marchent qu'une fois le déploiement aligné). Elles passent **avant** le middleware : tester avec ET sans session. La chaîne de requête de l'ancienne adresse est conservée.

| # | Ancienne adresse (sur `localhost:3001`) | Destination attendue | À vérifier |
|---|---|---|---|
| 1 | `/pilotage` | `/` | accueil du rôle |
| 2 | `/pilotage/magasins` | `/clients` | encadrement : vue « Suivi du secteur » |
| 3 | `/pilotage/magasins/<id>/visite` | `/clients/<id>/visite` | questionnaire de visite |
| 4 | `/pilotage/clients?search=abc&page=2` | `/clients?vue=portefeuille&search=abc&page=2` | vue « Portefeuille », recherche et page conservées |
| 5 | `/pilotage/clients/<id>` | `/clients/<id>` | fiche client |
| 6 | `/pilotage/ma-tournee?semaine=2026-11-02` | `/planning?semaine=2026-11-02` | planning d'activité, semaine conservée |
| 7 | `/pilotage/planning-equipe?promoteur=<id>` | `/planning-equipe?promoteur=<id>` | promoteur conservé |
| 8 | `/pilotage/parametres` | `/parametres` → `/admin?onglet=configuration` (ADMIN) | autres rôles : « Accès refusé » |
| 9 | `/pilotage/users` | `/admin?onglet=utilisateurs` | ADMIN : onglet Utilisateurs ; autres : « Accès refusé » |
| 10 | `/planification?semaine=2026-11-02` | `/planning-equipe?semaine=2026-11-02` | planning de l'équipe, semaine conservée |
| 11 | `/tournees?semaine=2026-11-02` | `/planning?semaine=2026-11-02` | COMMERCIAL : vue lecture ; encadrement : planning d'activité |
| 12 | `/pilotage/admin` | `/admin` | règle générale (préfixe retiré) |
| 13 | `/pilotage/alertes` | `/alertes` | idem |
| 14 | `/pilotage/commandes` et `/pilotage/commandes/<id>` | `/commandes`, `/commandes/<id>` | idem |
| 15 | `/pilotage/mon-equipe`, `/pilotage/mon-equipe/<id>`, `/pilotage/mon-equipe/<id>/planning`, `/pilotage/mon-equipe/promoteur/<id>` | mêmes adresses sans `/pilotage` | la 3e atterrit sur l'onglet planning de la fiche |
| 16 | `/pilotage/news`, `/pilotage/produits`, `/pilotage/promos`, `/pilotage/qualite` | mêmes adresses sans `/pilotage` | idem |
| 17 | `/pilotage/prospects`, `/pilotage/prospects/<id>` | `/prospects`, `/prospects/<id>` | idem |
| 18 | `/pilotage/rapports?semaine=2026-11-02` | `/rapports?semaine=2026-11-02` | semaine conservée |

Autres contrôles :

- [ ] **URL-01** **Sans session** : ouvrir `/tournees` puis `/pilotage/prospects` ; après connexion on arrive sur la page de destination (pas sur l'ancienne adresse ni sur `/`).
- [ ] **URL-02** Les adresses **inchangées** ne sont pas redirigées : `/`, `/agenda`, `/clients`, `/clients/<id>`, `/commandes`, `/commandes/<id>`, `/news`, `/parametres`, `/produits`, `/promos`, `/qualite`, `/visites`, `/login`, `/avatar/<id>`, `/pj/<id>/<pjId>`.
- [ ] **URL-03** Un lien de notification ancien (voir GEN-04) s'ouvre sur la bonne page de crm-web.
- [ ] **URL-04** Redirection avec un id invalide (`/pilotage/clients/abc`) : « Page introuvable » avec menu, pas d'erreur.
- [ ] **URL-05** Cohérence des chiffres : pour un même compte, les chiffres d'une page (CA, clients, commandes) correspondent à ceux de l'ancien CRM ou aux chiffres connus de l'équipe ; consigner tout écart de données. Les anciens fronts, supprimés, ne servent plus de référence.

---

## 5. Cas d'erreur

### 5.1 Session

- [ ] **ERR-01** **Sans session** : navigateur neuf, ouvrir `/clients?search=abc` → `/login?from=/clients?search=abc` ; après connexion, retour sur cette page avec sa recherche.
- [ ] **ERR-02** **Cookie supprimé** (outils de développement → Stockage → Cookies → `localhost:3001` → supprimer `crm_session`) puis actualiser : redirection vers `/login` (avec `?from=` de la page).
- [ ] **ERR-03** **Jeton altéré ou expiré** (cookie présent mais refusé par l'API) : modifier quelques caractères de la valeur de `crm_session`, actualiser : redirection vers `/login?from=<page demandée>` (comme une session absente) et **aucune boucle** `/login` ↔ `/` (pas de « trop de redirections »). Variante réaliste : dans `crm-api/.env`, `JWT_EXPIRES_IN` à une valeur courte (2 minutes), redémarrer l'API, se connecter, attendre, actualiser ; **remettre la valeur d'origine ensuite**. La durée normale du cookie est de 8 heures.
- [ ] **ERR-04** **Action avec session invalide** : sur une page qui écrit (ajouter une note de client, ajouter une visite au planning de l'équipe), altérer le cookie **sans le supprimer**, puis valider l'action : message d'erreur lisible en français (« Accès refusé (rôle insuffisant ou session expirée) » ou équivalent), pas d'écran blanc, aucune écriture.
- [ ] **ERR-05** `/login?from=//evil.example`, `/login?from=https://evil.example`, `/login?from=/\evil.example`, `/login?from=/login` : après connexion on arrive toujours sur **`/`** (jamais sur un autre site, jamais en boucle).
- [ ] **ERR-06** Se connecter, puis ouvrir `/login` à la main : le formulaire s'affiche (pas de renvoi automatique vers `/` : voulu).
- [ ] **ERR-07** Connexion avec l'API arrêtée : « Impossible de joindre le serveur. Réessaie dans un instant. » ; VPN coupé (AD injoignable) : message d'annuaire injoignable (« Annuaire momentanément injoignable. Réessaie plus tard. ») ou erreur serveur : noter le message exact obtenu. Le message « Trop de tentatives » ne devrait pas apparaître (l'API n'a pas de limitation, §6).

### 5.2 API arrêtée ou en panne

- [ ] **ERR-08** Session ouverte puis **API arrêtée** (terminal de l'API, `Ctrl+C`) ; actualiser n'importe quelle page : écran **« Service momentanément indisponible »** avec « Ta session est conservée » et bouton « Réessayer » ; **aucune redirection vers `/login`** (le cookie reste valable).
- [ ] **ERR-09** Relancer l'API puis « Réessayer » : la page revient **sans reconnexion**.
- [ ] **ERR-10** API arrêtée **pendant** une action (ajouter une note, enregistrer la prévision) : message d'erreur lisible (« Impossible de joindre l'API. » ou « Service momentanément indisponible, réessayez dans un instant. »), pas de déconnexion, pas d'écran blanc.
- [ ] **ERR-11** Page d'erreur applicative « Une erreur est survenue » (si elle apparaît) : le menu reste affiché, le bouton « Réessayer » recharge ; noter la « Référence » affichée.

### 5.3 Id inexistant ou invalide

Utiliser un id valide (copié d'une liste) puis le modifier. Tester avec un compte **autorisé sur la page** (encadrement pour `/prospects/...`, DR ou ADMIN pour `/mon-equipe/<id>`, CS, DR ou ADMIN pour `/mon-equipe/promoteur/<id>`) : un rôle non autorisé obtient « Accès refusé » avant même le contrôle de l'id.

- [ ] **ERR-12** `/clients/00000000-0000-4000-8000-000000000000`, `/commandes/00000000-0000-4000-8000-000000000000`, `/prospects/00000000-0000-4000-8000-000000000000` : « Page introuvable » avec menu, bouton « Retour à l'accueil ».
- [ ] **ERR-13** `/clients/abc`, `/commandes/abc`, `/prospects/abc`, `/mon-equipe/abc`, `/mon-equipe/promoteur/abc` : même « Page introuvable » (l'id est contrôlé avant tout appel à l'API). `/mon-equipe/abc/planning` : redirection vers `/mon-equipe` (DR et ADMIN).
- [ ] **ERR-14** `/mon-equipe/<id d'un promoteur>` (au lieu d'un chef de secteur) et `/mon-equipe/promoteur/<id d'un chef de secteur>` : « Page introuvable ».
- [ ] **ERR-15** **Hors périmètre** : `/mon-equipe/promoteur/<id d'un promoteur d'un autre secteur>` (CS) ou d'une autre région (DR) : « Page introuvable ». `/clients/<id d'un client hors secteur>` et `/commandes/<id d'une commande hors secteur>` pour CS / DR : *écart connu* (faille de périmètre de l'API, §6) : la fiche peut s'ouvrir ; **l'attendu à terme est « Page introuvable »**. Consigner, ne pas ouvrir de nouvelle anomalie.
- [ ] **ERR-16** `/pj/abc/def` et `/avatar/abc` : réponse vide 404 (pas de page).

### 5.4 Accès direct par URL à une page refusée

- [ ] **ERR-17** Pour chaque rôle, taper à la main chaque adresse « Refusé » du tableau du §2 : **« Accès refusé »** s'affiche (« Ta fonction ne te donne pas accès à cette page. »), menu et thème du rôle conservés, URL inchangée, **aucune donnée** de la page n'apparaît (même brièvement). `/parametres` pour un non-ADMIN : « Cette page est réservée aux administrateurs. »
- [ ] **ERR-18** Pour COMMERCIAL, ADV et MARKETING, vérifier en particulier les sous-pages de l'espace Direction : `/prospects/<id>`, `/mon-equipe/promoteur/<id>`, `/alertes`, `/admin?onglet=utilisateurs`.
- [ ] **ERR-19** Rôle autorisé sur la page mais pas sur le détail : CS sur `/mon-equipe/<id d'un chef de secteur>` ; DIRECTION sur `/mon-equipe`, `/mon-equipe/promoteur/<id>` ; CS sur `/rapports` : « Accès refusé ».
- [ ] **ERR-20** Pièce jointe de prospect : lien de téléchargement d'un encadrant ouvert **tel quel** dans une session COMMERCIAL ou sans session : réponse 404 vide, aucun fichier.

### 5.5 Valeurs d'URL invalides (aucun plantage attendu)

- [ ] **ERR-21** `?page=abc`, `?page=-3`, `?page=999999` sur `/clients`, `/commandes`, `/visites`, `/produits`, `/prospects`, `/news` : liste de la première page ou liste vide, jamais d'écran d'erreur.
- [ ] **ERR-22** `/commandes?origine=xyz&livraison=xyz` : filtres ignorés. `/?annee=abc&mois=99`, `/rapports?semaine=2026-13-45`, `/planning?semaine=abc`, `/planning-equipe?promoteur=abc` : retombent sur la valeur par défaut (mois ou semaine courante, premier promoteur).
- [ ] **ERR-23** `/admin?onglet=xyz` : « Vue d'ensemble ».
- [ ] **ERR-24** Pièce jointe de prospect de 9 à 10 Mo (limite annoncée de 10 Mo, plafond du serveur à 11 Mo) : le dépôt passe, ou un message d'erreur lisible est affiché. Si le corps est tronqué en passant par le middleware, le noter (BACKLOG, section déploiement).

### 5.6 Page introuvable à la racine

- [ ] **ERR-25** Avec session, `/nimportequoi` : « Page introuvable » **sans menu** (carte centrée, lien « Retour à l'accueil »).

---

## 6. Décisions en attente

À remplir avec l'utilisateur. Rien de ceci n'a de cas de test, sauf l'observation demandée dans les fiches ADV et MARKETING.

| # | Sujet | État actuel dans crm-web | Décision attendue | Décision / date |
|---|---|---|---|---|
| 1 | **MARKETING** : espace, accueil, périmètre | Espace « direction » (violet) par défaut ; accueil provisoire (« Bonjour » + carte Les News) ; menu : accueil, news, clients, visites, commandes, catalogue ; gère les news, édite promos et PEM, lecture seule sur les fiches clients ; refusé sur planning, prospects, équipe, rapports, alertes, admin | Thème, écrans visibles, accueil, périmètre de données | |
| 2 | **ADV** : espace, accueil, périmètre, droits | Espace « promoteurs » (bleu), classé « terrain » ; pas de code représentant donc pas de chiffres personnels ; peut éditer les fiches clients et la livraison des commandes ; `/planning` ouvert par URL sans entrée de menu (écart table / page) | Espace, accueil, périmètre, droits d'édition client, accès au planning | |
| 3 | **Éditeur PEM / promos** | Ouvert à ADMIN, DIRECTION et MARKETING (même règle que l'API) | Réservé à l'ADMIN seul, ou conserver les trois rôles | |
| 4 | **Droits d'édition de l'encadrement** sur contacts, notes, périodicité d'un client | L'encadrement et le terrain éditent (MARKETING exclu) ; côté API, `POST` / `PATCH` / `DELETE /clients` et les routes contacts, notes, périodicité n'ont pas de contrôle de rôle ni de périmètre (BACKLOG 1.1) | Qui peut éditer quoi, et sur quel périmètre | |
| 5 | **Nom visible de l'application** | Onglet et accueil : « SalesPilot ABC » ; menu : « ABC » avec « Promoteurs » (rien sous « ABC » dans l'espace violet) ; anciens noms ABC Sales et ABC Pilot supprimés des écrans ; pied de la connexion : « ABC Distribution · CRM · ABcosmétique » | Nom définitif (onglet, menu, connexion) | |
| 6 | **URL et port de production** | Développement et production sur le port 3001 (repris d'ABC Pilot) ; les anciennes adresses d'ABC Sales (hôte ou port 3000, 3002 en production) ne redirigent vers crm-web qu'une fois le reverse proxy aligné ; redirections en 307 tant que la table n'est pas figée (308 à la mise en production) ; `TZ=Europe/Paris` à définir ; HTTPS et `COOKIE_SECURE=true` (BACKLOG 1.11) | Adresse et port définitifs, bascule des anciens hôtes, passage au 308 | |
| 7 | **Logos à conserver** | Connexion : `logo.png` (ABC Group) et un seul logo dans le carrousel (Thelios) ; `logo-ascendo.png` et `logo-goback.png` restent dans `crm-web/public` mais ne sont plus utilisés (retirés à la demande de l'utilisateur) | Fichiers à supprimer ou à garder ; logos du menu | |
| 8 | **Faille de périmètre API sur commandes et clients** | `GET /commandes`, `GET /commandes/:id`, `GET /clients/:id` et l'historique ne filtrent pas le périmètre pour CS et DR ; non compensé côté front ; autres trous recensés dans `docs/BACKLOG.md` (section crm-web) | Correction côté API (service central de périmètre, BACKLOG 1.1 et 1.8) avant mise en production | |
| 9 | **Limitation des tentatives de connexion côté API** | `POST /auth/login` sans limite (BACKLOG 1.4) ; le front sait afficher « Trop de tentatives » (429) mais l'API ne le renvoie pas | Mise en place côté API ; en attendant, pas de mots de passe faux répétés pendant la recette | |
| 10 | **Abonnement Outlook / flux iCal du planning** | **Reporté par l'utilisateur.** Le bouton « Synchroniser avec Outlook » reste affiché dans « Mon planning d'activité » (encadrement) ; aucun cas de test | Retirer, masquer ou réactiver plus tard (le jeton du flux est aussi un point de sécurité, BACKLOG 1.2) | |

Autres points relevés à la lecture du code, hors liste ci-dessus :

| # | Sujet | État actuel | Décision attendue |
|---|---|---|---|
| 11 | Écran **Alertes** et **bordereaux de rappel** (Qualité) | Maquettes avec bandeau « Données d'exemple » ; pas de moteur d'alertes ni de flux de bordereaux côté API ; règles d'alertes mémorisées dans le navigateur | Brancher sur l'API ou masquer avant la production |
| 12 | **Source du rôle** | Le rôle changé à la main dans Administration est écrasé à la connexion par l'OU AD (BACKLOG 2.1) | Quelle source fait foi (AD ou CRM) |
| 13 | **Pages « bientôt »** | `/agenda` (aucune entrée de menu), onglets Mobile, Configuration et Journal d'audit de l'administration | Calendrier de mise en œuvre ou retrait |
| 14 | `?tous=1` sur `/clients` pour un COMMERCIAL | La case « Mes clients » peut être décochée et élargit à tout le référentiel (contournement côté API, BACKLOG 1.1) | Conserver la case ou la retirer, une fois le périmètre appliqué par l'API |

---

## 7. Synthèse et consignation

Par rôle, noter le nombre de contrôles conformes et les anomalies :

| Rôle | Compte testé | Date | Conformes / total | Anomalies (références des contrôles) |
|---|---|---|---|---|
| COMMERCIAL | | | / 22 | |
| CHEF_SECTEUR | | | / 19 | |
| DIRECTEUR_REGIONAL | | | / 15 | |
| DIRECTION | | | / 12 | |
| ADMIN | | | / 16 | |
| ADV (provisoire) | | | / 8 | |
| MARKETING (provisoire) | | | / 8 | |
| Communs, anciennes adresses, erreurs | | | / 7 + 5 + 25 | |

Pour une anomalie, consigner : identifiant du contrôle, rôle et compte, adresse complète (avec la chaîne de requête), étapes, résultat attendu, résultat obtenu, capture d'écran, et, si utile, le comportement de l'ancien front (code lisible dans l'historique git, commit `4c5e7b6`).

Ce que cette fiche ne couvre pas : l'application mobile, les imports AS400 et Minos de bout en bout, la charge, l'accessibilité détaillée, l'abonnement Outlook (reporté), la mise en production.
