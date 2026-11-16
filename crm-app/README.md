# CRM ABC — application mobile (Flutter)

Application mobile du CRM ABC pour le **promoteur**, le **chef de secteur** et le **directeur régional**, codée à partir de
la maquette HTML `maquette/demo-appli.html` (la seule référence : fidélité visuelle et fonctionnelle maximale).
L'ancienne application `salespilot-app` a été supprimée du dépôt (son code reste lisible dans l'historique git, par exemple `git show 31ddde7:salespilot-app/lib/core/sync/sync_engine.dart`) ; ses documents de spécification sont conservés dans `docs/CDC.md` et `docs/ANNEXE-API.md`.

État actuel : **socle** (thème, composants, modèles, données de démo, store, navigation, coquille par rôle, logique partagée
des alertes et des écarts), **huit lots réalisés** (accueil, clients, prospects, planning, équipe, visites, commandes, catalogue :
les 12 onglets, 11 écrans empilés et 27 feuilles ou dialogues de la maquette, voir `docs/ECRANS.md`) et **intégration faite**
(interligne de la maquette, composants du socle corrigés, liens entre lots câblés et testés). Guide : `docs/CONVENTIONS.md` ;
liste des écrans : `docs/ECRANS.md`.

## Lancer l'application

Prérequis : Flutter 3.44 (Dart 3.12).

```bash
cd crm-app
flutter pub get
flutter run -d chrome          # ou un émulateur / un téléphone Android : flutter run
```

Au lancement, un écran « Démo » propose trois profils de démonstration :

| Profil | Nom | Univers | Navigation |
|---|---|---|---|
| Promoteur | Julien M. | bleu « sales » | Accueil, Visites, Commandes, Clients, Planning + « + » (Catalogue, News) |
| Chef de secteur | Nadia H. | violet « pilot » | Accueil, Clients, Prospects, Planning + « + » (Visites, Commandes, Catalogue, News, Mes rapports, Équipe) |
| Directeur régional | Cindy R. | violet « pilot » | Accueil, Clients, Prospects, Planning + « + » (Catalogue, News, Mes rapports, Équipe) |

Pour changer de profil en cours de route : toucher l'**avatar** (initiales) de l'accueil, puis « Changer de profil (démo) ».
Changer de profil recharge toutes les données de démonstration du nouveau profil.

## Commandes

```bash
flutter analyze                 # doit afficher « No issues found »
flutter test                    # logique pure, store, composants, parcours des onglets par rôle
flutter build web --debug       # preuve de compilation
dart format lib test
```

## Structure

```
lib/
  main.dart, app.dart        point d'entrée, MaterialApp (thème selon le rôle)
  core/                      socle partagé (architecte) : theme, models, data, logic, state, nav, ui
  features/
    shell/                   choix du profil, coquille par rôle (barre de navigation, menu « + »)
    accueil/ clients/ prospects/ planning/ equipe/ visites/ commandes/ catalogue/   un lot par dossier
test/
  core/ smoke/ support/      tests du socle
  integration/               parcours qui traversent plusieurs lots
  features/<lot>/            tests de chaque lot
docs/
  CONVENTIONS.md             guide des développeurs de lot
  ECRANS.md                  tous les écrans, lots, fichiers, lignes de la maquette
assets/fonts/Inter-Variable.ttf
```

Choix techniques : Riverpod 3 (`flutter_riverpod`), `flutter_svg` pour les icônes, `intl` et `flutter_localizations` (locale
`fr_FR`), navigation par `Navigator` + `MaterialPageRoute` (la « pile » de la maquette), pas de `go_router`.

## Données de démonstration et limites

- Toutes les données sont **fictives** et portées fidèlement de la maquette (clients, prospects, planning, visites, commandes,
  produits, équipe). Aucun appel réseau, aucun secret, aucune connexion à l'API `crm-api` : elle sera branchée plus tard en
  remplaçant la construction de l'état initial (`core/state/crm_etat.dart`), sans toucher aux écrans.
- La date est figée au **mercredi 4 novembre 2026, 14:23** (semaine 45), comme dans la maquette.
- Les écrans réels sont à réaliser par les lots : pour l'instant chaque écran, feuille ou dialogue affiche son titre et la
  mention « Écran à réaliser par le lot … ». Les composants partagés et la navigation sont, eux, complets et testés.
- Les emojis (📍 🚚 ⚠ …) s'affichent avec la police du système, comme dans la maquette ; Inter ne les contient pas.
- Plateformes générées : Android et Web. L'application n'a pas encore été essayée sur un émulateur ni sur un téléphone :
  la vérification actuelle repose sur `flutter analyze`, `flutter test` et `flutter build web --debug`.
- Fonctions de la maquette sans source de données dans l'API actuelle (objectifs en euros, stocks, suivi de transport, scan) :
  elles sont reproduites avec les données de la maquette, à confirmer avant tout branchement sur l'API.
