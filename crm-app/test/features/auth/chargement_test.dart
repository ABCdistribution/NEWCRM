import 'package:crm_app/app.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/features/auth/chargement_screen.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/app_test_support.dart';

/// Catalogue dont l'état est imposé par le test (aucune base ni serveur).
class _CatalogueFixe extends CatalogueNotifier {
  _CatalogueFixe(this.etat);
  final EtatSynchro etat;

  @override
  EtatSynchro build() => etat;

  @override
  Future<void> rafraichir() async {}
}

/// Attente après connexion déjà demandée.
class _AttenteActive extends AttenteConnexionNotifier {
  @override
  bool build() => true;
}

/// Clients dont l'état est imposé par le test.
class _ClientsFixe extends ClientsNotifier {
  _ClientsFixe(this.etat);
  final EtatSynchro etat;

  @override
  EtatSynchro build() => etat;

  @override
  Future<void> rafraichir() async {}
}

Future<void> _lancer(
  WidgetTester tester,
  EtatSynchro etat, {
  EtatSynchro clients = const EtatSynchro(phase: PhaseSynchro.ok, nb: 100),
  bool apresConnexion = false,
}) async {
  await assurerInter(tester);
  utiliserTelephone(tester);
  await initializeDateFormatting('fr_FR');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogueProvider.overrideWith(() => _CatalogueFixe(etat)),
        clientsProvider.overrideWith(() => _ClientsFixe(clients)),
        if (apresConnexion)
          attenteConnexionProvider.overrideWith(_AttenteActive.new),
        sessionProvider.overrideWith(
          () => SessionNotifier(
            const Utilisateur(
              id: 'u',
              identifiant: 'x',
              nomAffiche: 'Jean DUPONT',
              email: null,
              roleApi: 'COMMERCIAL',
            ),
          ),
        ),
        roleProvider.overrideWith(() => RoleNotifier(Role.promoteur)),
      ],
      child: const CrmApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'premier téléchargement : écran de chargement avec progression, pas d\'application',
    (tester) async {
      await _lancer(
        tester,
        const EtatSynchro(
          phase: PhaseSynchro.chargement,
          recus: 1200,
          total: 5400,
        ),
      );
      expect(find.byType(ChargementScreen), findsOneWidget);
      expect(find.byType(ShellScreen), findsNothing);
      expect(find.text('Chargement des données'), findsOneWidget);
      expect(find.text('Catalogue : 1 200 / 5 400'), findsOneWidget);
      expect(
        find.textContaining('Clients'),
        findsNothing,
      ); // clients déjà en base
    },
  );

  testWidgets(
    'catalogue et clients à télécharger : une ligne de progression pour chacun',
    (tester) async {
      await _lancer(
        tester,
        const EtatSynchro(
          phase: PhaseSynchro.chargement,
          recus: 1200,
          total: 5400,
        ),
        clients: const EtatSynchro(
          phase: PhaseSynchro.chargement,
          recus: 300,
          total: 4000,
        ),
      );
      expect(find.byType(ChargementScreen), findsOneWidget);
      expect(find.text('Catalogue : 1 200 / 5 400'), findsOneWidget);
      expect(find.text('Clients : 300 / 4 000'), findsOneWidget);
    },
  );

  testWidgets(
    "catalogue prêt mais clients encore à télécharger : l'application reste derrière le chargement",
    (tester) async {
      await _lancer(
        tester,
        const EtatSynchro(phase: PhaseSynchro.ok, nb: 5400),
        clients: const EtatSynchro(
          phase: PhaseSynchro.chargement,
          recus: 10,
          total: 100,
        ),
      );
      expect(find.byType(ChargementScreen), findsOneWidget);
      expect(find.byType(ShellScreen), findsNothing);
      expect(find.text('Clients : 10 / 100'), findsOneWidget);
    },
  );

  testWidgets(
    'avant la première réponse du serveur : « Connexion au serveur… »',
    (tester) async {
      await _lancer(tester, const EtatSynchro(phase: PhaseSynchro.chargement));
      expect(find.text('Connexion au serveur…'), findsOneWidget);
      expect(find.byType(ShellScreen), findsNothing);
    },
  );

  testWidgets(
    'serveur injoignable sans données : message, Réessayer, Continuer sans données',
    (tester) async {
      await _lancer(tester, const EtatSynchro(phase: PhaseSynchro.horsLigne));
      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(
        find.text('Serveur injoignable. Vérifiez votre connexion.'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
      await tester.tap(find.text('Continuer sans données'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ChargementScreen), findsNothing);
      expect(find.byType(ShellScreen), findsOneWidget);
    },
  );

  testWidgets(
    'données déjà en base : l\'application s\'ouvre directement, la synchro se fait en arrière-plan',
    (tester) async {
      await _lancer(
        tester,
        const EtatSynchro(phase: PhaseSynchro.chargement, nb: 5400),
      );
      expect(find.byType(ChargementScreen), findsNothing);
      expect(find.byType(ShellScreen), findsOneWidget);
    },
  );

  testWidgets('téléchargement terminé : l\'application s\'ouvre', (
    tester,
  ) async {
    await _lancer(tester, const EtatSynchro(phase: PhaseSynchro.ok, nb: 5400));
    expect(find.byType(ChargementScreen), findsNothing);
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  test(
    'bloquant : seulement sans aucune donnée locale et pendant ou après un échec',
    () {
      expect(const EtatSynchro().bloquant, isFalse); // démo
      expect(
        const EtatSynchro(phase: PhaseSynchro.chargement).bloquant,
        isTrue,
      );
      expect(const EtatSynchro(phase: PhaseSynchro.horsLigne).bloquant, isTrue);
      expect(const EtatSynchro(phase: PhaseSynchro.erreur).bloquant, isTrue);
      expect(const EtatSynchro(phase: PhaseSynchro.ok).bloquant, isFalse);
      expect(
        const EtatSynchro(phase: PhaseSynchro.chargement, nb: 1).bloquant,
        isFalse,
      );
    },
  );

  testWidgets(
    'juste après la connexion : on attend la fin du téléchargement même avec des données locales',
    (tester) async {
      await _lancer(
        tester,
        const EtatSynchro(
          phase: PhaseSynchro.chargement,
          nb: 5400,
          recus: 100,
          total: 5400,
        ),
        apresConnexion: true,
      );
      expect(find.byType(ChargementScreen), findsOneWidget);
      expect(find.byType(ShellScreen), findsNothing);
      expect(find.text('Catalogue : 100 / 5 400'), findsOneWidget);
    },
  );

  testWidgets(
    "au simple relancement (pas de connexion) : avec des données locales l'application s'ouvre tout de suite",
    (tester) async {
      await _lancer(
        tester,
        const EtatSynchro(
          phase: PhaseSynchro.chargement,
          nb: 5400,
          recus: 100,
          total: 5400,
        ),
      );
      expect(find.byType(ChargementScreen), findsNothing);
      expect(find.byType(ShellScreen), findsOneWidget);
    },
  );
}
