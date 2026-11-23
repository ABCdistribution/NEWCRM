import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/pem_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/accueil/accueil_screen.dart';
import 'package:crm_app/features/accueil/widgets/feuille_pem.dart';
import 'package:crm_app/features/visites/visite_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../visites/aide_visites.dart' show contexteCoquille;
import 'aide_accueil.dart';

/// Rubrique « Visites PEM » de l'accueil du promoteur (démonstration : deux propositions fictives, l'une à traiter
/// chez « U Express – Paris » avec un report déjà fait, l'autre devenue obligatoire chez « Carrefour – Ivry-sur-Seine »).

/// Démonstration sans aucune proposition.
class _SansProposition extends PropositionsPemDemoNotifier {
  @override
  List<PropositionPem> build() => const [];
}

/// Actions qui échouent comme le CRM : le message en français doit s'afficher tel quel.
class _Refus implements ActionsPem {
  @override
  Future<PropositionPem> accepter(String id, {String? date}) async =>
      throw const ErreurApi(
        TypeErreurApi.inattendue,
        statut: 409,
        detail: 'Proposition déjà acceptée par un autre appareil',
      );

  @override
  Future<PropositionPem> reporter(
    String id, {
    String? motif,
    String? date,
  }) async => throw const ErreurApi(TypeErreurApi.reseau);
}

Finder _dansFeuille(String texte) =>
    find.descendant(of: find.byType(FeuillePem), matching: find.text(texte));

/// Carte de la rubrique qui porte `texte` (nom du magasin).
Finder _carte(String nom) =>
    find.ancestor(of: find.text(nom), matching: find.byType(AppCarte));

void main() {
  Future<void> monter(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) => pumpEcran(
    tester,
    const AccueilScreen(),
    role: Role.promoteur,
    overrides: overrides,
  );

  group('rubrique « Visites PEM »', () {
    testWidgets('une carte par proposition : magasin, date, reports restants', (
      tester,
    ) async {
      await monter(tester);
      await tester.ensureVisible(find.text('Visites PEM'));
      await tester.pumpAndSettle();
      expect(find.text('Visites PEM'), findsOneWidget);

      // La plus proche d'abord : la visite obligatoire du 6 nov.
      final ivry = _carte('Carrefour – Ivry-sur-Seine').last;
      expect(
        find.descendant(
          of: ivry,
          matching: find.text('Proposée pour le ven. 6 nov.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: ivry, matching: find.text('Obligatoire')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: ivry, matching: find.text('Accepter')),
        findsOneWidget,
      );
      // Obligatoire : pas de bouton « Reporter ».
      expect(
        find.descendant(of: ivry, matching: find.text('Reporter')),
        findsNothing,
      );

      final paris = _carte('U Express – Paris');
      expect(
        find.descendant(
          of: paris,
          matching: find.text('Proposée pour le lun. 9 nov.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: paris, matching: find.text('2 reports restants')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: paris, matching: find.text('Accepter')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: paris, matching: find.text('Reporter')),
        findsOneWidget,
      );
      expect(find.text('Obligatoire'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rien n’est affiché sans proposition', (tester) async {
      await monter(
        tester,
        overrides: [
          propositionsPemDemoProvider.overrideWith(_SansProposition.new),
        ],
      );
      expect(find.text('Visites PEM'), findsNothing);
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Obligatoire'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('accepter', () {
    testWidgets(
      'la feuille propose la date proposée ; la proposition devient « Prévue »',
      (tester) async {
        await monter(tester);
        await toucher(
          tester,
          find.descendant(
            of: _carte('U Express – Paris'),
            matching: find.text('Accepter'),
          ),
        );
        expect(find.text('Accepter la visite PEM'), findsOneWidget);
        expect(find.text('U Express – Paris'), findsNWidgets(2));
        expect(find.text('09/11/2026'), findsOneWidget);
        // Pas de motif à l'acceptation.
        expect(find.text('Motif (facultatif)'), findsNothing);

        await tester.tap(_dansFeuille('Accepter'));
        await tester.pumpAndSettle();
        expect(find.byType(FeuillePem), findsNothing);
        expect(
          find.text('Visite PEM acceptée pour le lun. 9 nov.'),
          findsOneWidget,
        );

        final paris = _carte('U Express – Paris');
        expect(
          find.descendant(
            of: paris,
            matching: find.text('Prévue le lun. 9 nov.'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: paris,
            matching: find.text('Démarrer la visite PEM'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: paris, matching: find.text('Reporter')),
          findsNothing,
        );
        expect(
          find.descendant(of: paris, matching: find.text('2 reports restants')),
          findsNothing,
        );
        await laisserPasserToast(tester);
      },
    );

    testWidgets('la visite obligatoire s’accepte aussi', (tester) async {
      await monter(tester);
      await toucher(
        tester,
        find.descendant(
          of: _carte('Carrefour – Ivry-sur-Seine').last,
          matching: find.text('Accepter'),
        ),
      );
      expect(find.text('06/11/2026'), findsOneWidget);
      await tester.tap(_dansFeuille('Accepter'));
      await tester.pumpAndSettle();
      final carte = _carte('Carrefour – Ivry-sur-Seine').last;
      expect(
        find.descendant(
          of: carte,
          matching: find.text('Démarrer la visite PEM'),
        ),
        findsOneWidget,
      );
      // Toujours obligatoire.
      expect(
        find.descendant(of: carte, matching: find.text('Obligatoire')),
        findsOneWidget,
      );
      await laisserPasserToast(tester);
    });

    testWidgets(
      'échec : le message de l’API s’affiche et la feuille reste ouverte',
      (tester) async {
        await monter(
          tester,
          overrides: [actionsPemProvider.overrideWithValue(_Refus())],
        );
        await toucher(
          tester,
          find.descendant(
            of: _carte('U Express – Paris'),
            matching: find.text('Accepter'),
          ),
        );
        await tester.tap(_dansFeuille('Accepter'));
        await tester.pumpAndSettle();
        expect(
          find.text('Proposition déjà acceptée par un autre appareil'),
          findsOneWidget,
        );
        expect(find.byType(FeuillePem), findsOneWidget);
        await laisserPasserToast(tester);
        // On peut annuler : rien n'a changé.
        await tester.tap(_dansFeuille('Annuler'));
        await tester.pumpAndSettle();
        expect(find.byType(FeuillePem), findsNothing);
        expect(find.text('2 reports restants'), findsOneWidget);
      },
    );
  });

  group('reporter', () {
    Future<void> ouvrirReport(WidgetTester tester) => toucher(
      tester,
      find.descendant(
        of: _carte('U Express – Paris'),
        matching: find.text('Reporter'),
      ),
    );

    testWidgets(
      'la feuille : motif facultatif, date dans une semaine par défaut',
      (tester) async {
        await monter(tester);
        await ouvrirReport(tester);
        expect(find.text('Reporter la visite PEM'), findsOneWidget);
        expect(find.text('Motif (facultatif)'), findsOneWidget);
        expect(find.text('Reporter au *'), findsOneWidget);
        // 4 nov. + 7 jours.
        expect(find.text('11/11/2026'), findsOneWidget);

        // Le sélecteur de date n'offre que de demain à +14 jours.
        await tester.tap(find.text('11/11/2026'));
        await tester.pumpAndSettle();
        final dialogue = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(dialogue.firstDate, DateTime(2026, 11, 5));
        expect(dialogue.lastDate, DateTime(2026, 11, 18));
        expect(dialogue.initialDate, DateTime(2026, 11, 11));
        await tester.tap(find.text('Annuler').last);
        await tester.pumpAndSettle();
        expect(find.byType(FeuillePem), findsOneWidget);
      },
    );

    testWidgets('report avec motif : un report de moins, nouvelle date', (
      tester,
    ) async {
      await monter(tester);
      await ouvrirReport(tester);
      await tester.enterText(find.byType(TextField), 'Inventaire en magasin');
      await tester.tap(_dansFeuille('Reporter'));
      await tester.pumpAndSettle();
      expect(find.byType(FeuillePem), findsNothing);
      expect(find.text('Visite PEM reportée au mer. 11 nov.'), findsOneWidget);
      final p = conteneurMonte(
        tester,
      ).read(propositionsPemProvider).firstWhere((x) => x.id == 'pem-d1');
      expect(p.motifDernierReport, 'Inventaire en magasin');
      expect(p.dateProposee, '2026-11-11');
      final carte = _carte('U Express – Paris');
      expect(
        find.descendant(of: carte, matching: find.text('1 report restant')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: carte,
          matching: find.text('Proposée pour le mer. 11 nov.'),
        ),
        findsOneWidget,
      );
      await laisserPasserToast(tester);
    });

    testWidgets('au troisième report la visite devient obligatoire', (
      tester,
    ) async {
      await monter(tester);
      await ouvrirReport(tester);
      await tester.tap(_dansFeuille('Reporter'));
      await tester.pumpAndSettle();
      await laisserPasserToast(tester);
      expect(find.text('1 report restant'), findsOneWidget);

      await ouvrirReport(tester);
      await tester.tap(_dansFeuille('Reporter'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Visite PEM reportée au mer. 11 nov. Elle est maintenant obligatoire.',
        ),
        findsOneWidget,
      );
      final carte = _carte('U Express – Paris');
      expect(
        find.descendant(of: carte, matching: find.text('Obligatoire')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: carte, matching: find.text('Reporter')),
        findsNothing,
      );
      // Acceptée d'office : on peut la démarrer.
      expect(
        find.descendant(
          of: carte,
          matching: find.text('Démarrer la visite PEM'),
        ),
        findsOneWidget,
      );
      expect(find.text('Obligatoire'), findsNWidgets(2));
      await laisserPasserToast(tester);
    });

    testWidgets('échec réseau : message de l’API, la feuille reste ouverte', (
      tester,
    ) async {
      await monter(
        tester,
        overrides: [actionsPemProvider.overrideWithValue(_Refus())],
      );
      await ouvrirReport(tester);
      await tester.tap(_dansFeuille('Reporter'));
      await tester.pumpAndSettle();
      expect(
        find.text('Serveur injoignable. Vérifiez votre connexion.'),
        findsOneWidget,
      );
      expect(find.byType(FeuillePem), findsOneWidget);
      await laisserPasserToast(tester);
    });
  });

  testWidgets(
    '« Démarrer la visite PEM » crée une visite PEM liée à la proposition',
    (tester) async {
      await lancerApp(tester, Role.promoteur);
      await toucher(
        tester,
        find.descendant(
          of: _carte('U Express – Paris'),
          matching: find.text('Accepter'),
        ),
      );
      await tester.tap(_dansFeuille('Accepter'));
      await tester.pumpAndSettle();
      await laisserPasserToast(tester);
      await toucher(tester, find.text('Démarrer la visite PEM'));

      expect(find.byType(VisiteScreen), findsOneWidget);
      final v = conteneurMonte(tester).read(crmProvider).visites.first;
      expect(v.estPem, isTrue);
      expect(v.etat, EtatVisite.brouillon);
      expect(v.magasinId, 'm5');
      expect(v.propositionPemId, 'pem-d1');

      // De retour à l'accueil, la proposition propose de reprendre la visite, sans en créer une seconde.
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      AppRoutes.retourRacine(contexteCoquille(tester));
      await tester.pumpAndSettle();
      await toucher(tester, find.text('Reprendre la visite PEM'));
      expect(find.byType(VisiteScreen), findsOneWidget);
      expect(
        conteneurMonte(tester).read(crmProvider).visites.where((x) => x.estPem),
        hasLength(1),
      );
    },
  );
}
