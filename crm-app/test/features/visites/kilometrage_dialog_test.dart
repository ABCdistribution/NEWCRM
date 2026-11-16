import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/visites/kilometrage_dialog.dart';
import 'package:crm_app/features/visites/state/kilometrage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_visites.dart';

Future<void> ouvrir(WidgetTester tester, PhaseKilometrage phase) async {
  AppRoutes.kilometrage(contexteCoquille(tester), phase);
  await tester.pumpAndSettle();
}

Kilometrage km(WidgetTester tester) =>
    conteneurApp(tester).read(kilometrageProvider);

Future<void> saisir(WidgetTester tester, String texte) async {
  await tester.enterText(find.byType(EditableText), texte);
  await tester.tap(find.text('Enregistrer'));
  await tester.pumpAndSettle();
}

void main() {
  group('Kilométrage (km l.1337-1343, actions l.1536-1543)', () {
    testWidgets('départ : textes de la maquette', (tester) async {
      await lancerApp(tester, Role.promoteur);
      await ouvrir(tester, PhaseKilometrage.depart);
      expect(find.byType(KilometrageDialog), findsOneWidget);
      expect(find.text('🚗'), findsOneWidget);
      expect(find.text('Kilométrage de départ'), findsOneWidget);
      expect(
        find.text(
          'Relevez le compteur de votre véhicule avant de commencer votre tournée. Facultatif : vous pouvez le faire plus tard.',
        ),
        findsOneWidget,
      );
      expect(find.text('Kilométrage (km)'), findsOneWidget);
      expect(find.text('Dernier relevé : 48 215 km'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('arrivée : textes de la maquette', (tester) async {
      await lancerApp(tester, Role.promoteur);
      await ouvrir(tester, PhaseKilometrage.arrivee);
      expect(find.text("Kilométrage d'arrivée"), findsOneWidget);
      expect(
        find.text(
          'Votre tournée est terminée : relevez le compteur de votre véhicule. Facultatif : vous pouvez le faire plus tard.',
        ),
        findsOneWidget,
      );
      expect(find.text('Dernier relevé : 48 215 km'), findsOneWidget);
    });

    testWidgets('« Plus tard » ferme sans rien enregistrer', (tester) async {
      await lancerApp(tester, Role.promoteur);
      await ouvrir(tester, PhaseKilometrage.depart);
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(find.byType(KilometrageDialog), findsNothing);
      expect(km(tester).depart, isNull);
    });

    testWidgets(
      'un relevé vide ou nul est refusé et le dialogue reste ouvert',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        await ouvrir(tester, PhaseKilometrage.depart);
        for (final saisie in ['', 'abc', '0']) {
          await saisir(tester, saisie);
          expect(
            find.text('Indiquez le kilométrage, ou touchez « Plus tard ».'),
            findsOneWidget,
            reason: 'saisie « $saisie »',
          );
          expect(find.byType(KilometrageDialog), findsOneWidget);
          await attendreToast(tester);
        }
        expect(km(tester).depart, isNull);
      },
    );

    testWidgets('le départ est enregistré (les non-chiffres sont ignorés)', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await ouvrir(tester, PhaseKilometrage.depart);
      await saisir(tester, '48 300 km');
      expect(find.text('Kilométrage enregistré : 48300 km.'), findsOneWidget);
      expect(find.byType(KilometrageDialog), findsNothing);
      expect(km(tester).depart, 48300);
      expect(km(tester).arrivee, isNull);
    });

    testWidgets('l’arrivée sans départ enregistré n’est comparée à rien', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await ouvrir(tester, PhaseKilometrage.arrivee);
      await saisir(tester, '48400');
      expect(find.text('Kilométrage enregistré : 48400 km.'), findsOneWidget);
      expect(km(tester).arrivee, 48400);
    });

    testWidgets('l’arrivée ne peut pas être inférieure au départ', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await ouvrir(tester, PhaseKilometrage.depart);
      await saisir(tester, '48300');
      await attendreToast(tester);

      await ouvrir(tester, PhaseKilometrage.arrivee);
      // le dernier relevé proposé est celui du départ
      expect(find.text('Dernier relevé : 48 300 km'), findsOneWidget);
      await saisir(tester, '48200');
      expect(
        find.text(
          "Le kilométrage d'arrivée ne peut pas être inférieur à celui du départ (48300 km).",
        ),
        findsOneWidget,
      );
      expect(find.byType(KilometrageDialog), findsOneWidget);
      expect(km(tester).arrivee, isNull);
      await attendreToast(tester);

      await saisir(tester, '48350');
      expect(
        find.text("Kilométrage enregistré : 50 km parcourus aujourd'hui."),
        findsOneWidget,
      );
      expect(km(tester).arrivee, 48350);
      expect(find.byType(KilometrageDialog), findsNothing);
    });

    testWidgets('le kilométrage repart de zéro quand le profil change', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await ouvrir(tester, PhaseKilometrage.depart);
      await saisir(tester, '48300');
      await attendreToast(tester);
      expect(km(tester).depart, 48300);
      conteneurApp(tester)
          .read(kilometrageProvider.notifier)
          .maj((k) => k.copyWith(departPropose: true));
      expect(km(tester).departPropose, isTrue);
      conteneurApp(tester).read(roleProvider.notifier).choisir(Role.cs);
      await tester.pumpAndSettle();
      expect(km(tester).depart, isNull);
      expect(km(tester).departPropose, isFalse);
    });
  });
}
