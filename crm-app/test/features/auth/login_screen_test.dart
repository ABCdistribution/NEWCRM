import 'package:crm_app/app.dart';
import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/auth_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/db/cle_base.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _StockageMemoire implements StockageSecret {
  final Map<String, String> valeurs = {};

  @override
  Future<String?> lire(String nom) async => valeurs[nom];

  @override
  Future<void> ecrire(String nom, String valeur) async => valeurs[nom] = valeur;
}

class _FauxAuth implements AuthApi {
  _FauxAuth(this.suite);
  final Future<ReponseConnexion> Function(String, String) suite;
  final List<(String, String)> appels = [];

  @override
  Future<ReponseConnexion> connecter(String identifiant, String motDePasse) {
    appels.add((identifiant, motDePasse));
    return suite(identifiant, motDePasse);
  }
}

Future<void> _lancer(WidgetTester tester, _FauxAuth api) async {
  tester.view.physicalSize = const Size(390 * 3, 780 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await initializeDateFormatting('fr_FR');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(api),
        stockageSessionProvider.overrideWithValue(
          StockageSession(_StockageMemoire()),
        ),
      ],
      child: const CrmApp(),
    ),
  );
  await tester.pump();
}

Future<void> _saisir(WidgetTester tester, String id, String mdp) async {
  await tester.enterText(find.byType(TextFormField).at(0), id);
  await tester.enterText(find.byType(TextFormField).at(1), mdp);
  await tester.tap(find.text('Se connecter'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('écran de connexion au lancement, mot de passe masqué', (
    tester,
  ) async {
    await _lancer(
      tester,
      _FauxAuth((_, _) async => throw StateError('non appelé')),
    );
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Identifiant'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    final champs = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(champs[0].obscureText, isFalse);
    expect(champs[1].obscureText, isTrue);
  });

  testWidgets('champs vides : message, aucun appel au serveur', (tester) async {
    final api = _FauxAuth((_, _) async => throw StateError('non appelé'));
    await _lancer(tester, api);
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(
      find.text('Saisissez votre identifiant et votre mot de passe.'),
      findsOneWidget,
    );
    expect(api.appels, isEmpty);
  });

  testWidgets(
    'identifiants refusés : message en français, reste sur la connexion',
    (tester) async {
      final api = _FauxAuth(
        (_, _) async =>
            throw const ErreurApi(TypeErreurApi.identifiants, statut: 401),
      );
      await _lancer(tester, api);
      await _saisir(tester, 'jdupont', 'mauvais');
      expect(
        find.text('Identifiant ou mot de passe incorrect.'),
        findsOneWidget,
      );
      expect(find.byType(ShellScreen), findsNothing);
      expect(api.appels, [('jdupont', 'mauvais')]);
    },
  );

  testWidgets('serveur injoignable : message réseau', (tester) async {
    final api = _FauxAuth(
      (_, _) async => throw const ErreurApi(TypeErreurApi.reseau),
    );
    await _lancer(tester, api);
    await _saisir(tester, 'jdupont', 'mdp');
    expect(
      find.text('Serveur injoignable. Vérifiez votre connexion.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'connexion réussie : application du rôle, prénom réel dans « Bonjour »',
    (tester) async {
      final api = _FauxAuth(
        (_, _) async => const ReponseConnexion(
          jeton: 'jeton',
          utilisateur: Utilisateur(
            id: 'u1',
            identifiant: 'jdupont',
            nomAffiche: 'Karim BENALI',
            email: null,
            roleApi: 'COMMERCIAL',
          ),
        ),
      );
      await _lancer(tester, api);
      await _saisir(tester, 'jdupont', 'bon');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ShellScreen), findsOneWidget);
      expect(find.text('Bonjour Karim'), findsOneWidget);
      expect(
        find.text('KB'),
        findsOneWidget,
      ); // initiales de l'utilisateur réel
    },
  );
}
