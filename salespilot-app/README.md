# SalesPilot — application mobile (Flutter)

Application mobile de la plateforme **SalesPilot ABC** : espace **ABC Sales** (terrain) et espace **ABC Pilot** (pilotage), accessibles selon les droits du compte. Spécification dans [CDC.md](CDC.md) ; contrat d'API et écarts dans [ANNEXE-API.md](ANNEXE-API.md).

État : **développement du MVP en cours** (version 0.1.0). Android en priorité.

## Lancer l'application

Prérequis : Flutter 3.44, SDK Android. L'API doit tourner (`crm-api`, port 4000) et le compte doit être connecté à l'Active Directory (pas de contournement de connexion).

```bash
cd salespilot-app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # code de la base locale (drift)

# Émulateur Android : l'API de l'ordinateur est vue sur 10.0.2.2
flutter run
# Téléphone réel : adresse de l'ordinateur sur le réseau
flutter run --dart-define=API_URL=http://192.168.x.x:4000
```

Vérifications : `flutter analyze` · `flutter test` · `flutter build apk --debug`.

Production : l'API doit être en **HTTPS** (le trafic HTTP n'est autorisé que dans les builds de débogage).

## Structure

| Dossier | Rôle |
|---|---|
| `lib/core/auth` | Rôles, espaces (Sales / Pilot), session sécurisée |
| `lib/core/api` | Client HTTP (jeton, version, identifiant d'installation) |
| `lib/core/db` | Base locale (drift) : file d'envoi, brouillons de visite, cache |
| `lib/core/sync` | **File d'envoi et moteur de synchronisation** (idempotence, dépendances, reprise) |
| `lib/features/*` | Écrans : connexion, tournée du jour, magasins, visite, synchronisation, profil |

## Avancement par rapport au cahier des charges (lot MVP)

| Fonction | État |
|---|---|
| Connexion AD, session, sélecteur d'espace par rôle | **Fait** (non testé contre l'AD réelle) |
| Accueil = tournée du jour, mode hors ligne | **Fait** |
| Magasins : liste, recherche, filtre actif / inactif, fiche, note | **Fait** (fiche hors ligne seulement si déjà ouverte) |
| Visite : brouillon, reprise, questionnaire, DN, photos, contrôle avant validation, 3 états | **Fait** |
| File d'envoi, dépendances visite → photos, reprise, compteur permanent, écran de synchronisation | **Fait**, testé (38 tests) |
| **Commande** (recherche, colisage, récapitulatif, alerte rappel) | **À faire** |
| **Catalogue, promotions, rappels qualité** | **À faire** |
| Déverrouillage biométrique / code | **À faire** |
| **Chiffrement de la base locale et des photos** | **À faire — test bloquant avant lancement** |
| Télémétrie des appareils, version minimale | **À faire** (nécessite l'API, CDC §7) |
| Espace ABC Pilot | Sélecteur en place, écrans au lot 3 |

Limites connues : la base locale n'est **pas encore chiffrée** et les photos sont stockées en clair dans le dossier de l'application ; l'application n'a **pas été essayée sur un téléphone ni un émulateur** ni contre l'API réelle (voir ci-dessous).
