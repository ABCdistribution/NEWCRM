import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/planning/rapport_detail_sheet.dart';
import 'package:crm_app/features/planning/state/planning_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Feuille « Détail du rapport » : maquette `rapport-detail` l.1839-1844.

/// Monte un écran vide, puis ouvre la feuille de la semaine `n`.
Future<ProviderContainer> ouvrirSemaine(
  WidgetTester tester,
  Role role,
  int n,
) async {
  await pumpEcran(tester, const Scaffold(body: SizedBox()), role: role);
  final ctx = tester.element(find.byType(Scaffold));
  ouvrirDetailRapport(ctx, n);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(ctx);
}

void main() {
  testWidgets('semaine 44 : prévu, réalisé et écarts triés', (tester) async {
    await ouvrirSemaine(tester, Role.cs, 44);
    expect(find.text('Semaine 44 · 26 – 30 octobre'), findsOneWidget);
    expect(find.text('Prévu 15 · Réalisé 14 (93 %)'), findsOneWidget);
    // Les lignes retirées passent avant les lignes ajoutées.
    expect(find.text('Monoprix – Caen'), findsOneWidget);
    expect(
      find.text('Retiré du planning, non réalisé · prévu mardi'),
      findsOneWidget,
    );
    expect(find.text('Auchan – Rouen'), findsOneWidget);
    expect(find.text('Ajouté (non prévu) · visite non prévue'), findsOneWidget);
    expect(find.text('✕'), findsOneWidget);
    expect(find.text('＋'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Monoprix – Caen')).dy,
      lessThan(tester.getTopLeft(find.text('Auchan – Rouen')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('semaine 43 : retirées avant déplacée', (tester) async {
    await ouvrirSemaine(tester, Role.dir, 43);
    expect(find.text('Semaine 43 · 19 – 23 octobre'), findsOneWidget);
    expect(find.text('Prévu 14 · Réalisé 12 (86 %)'), findsOneWidget);
    expect(find.text('Carrefour – Ivry-sur-Seine'), findsOneWidget);
    expect(find.text('U Express – Paris'), findsOneWidget);
    expect(find.text('Déplacé · prévu mardi, réalisé jeudi'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('U Express – Paris')).dy,
      lessThan(tester.getTopLeft(find.text('Carrefour Market – Rouen')).dy),
    );
  });

  testWidgets('semaine 42 : aucun écart', (tester) async {
    await ouvrirSemaine(tester, Role.cs, 42);
    expect(find.text('Semaine 42 · 12 – 16 octobre'), findsOneWidget);
    expect(find.text('Prévu 15 · Réalisé 15 (100 %)'), findsOneWidget);
    expect(
      find.text("Aucun écart : tout s'est passé comme prévu."),
      findsOneWidget,
    );
  });

  testWidgets('semaine 41 : deux lignes non réalisées', (tester) async {
    await ouvrirSemaine(tester, Role.cs, 41);
    expect(find.text('Semaine 41 · 5 – 9 octobre'), findsOneWidget);
    expect(find.text('Prévu 13 · Réalisé 11 (85 %)'), findsOneWidget);
    expect(find.text('Non réalisé · prévu vendredi'), findsNWidgets(2));
    expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
    expect(find.text('Carrefour – Rouen'), findsOneWidget);
  });

  group('semaine 45 : comparaison en direct', () {
    testWidgets('chef de secteur : prévu 4, réalisé 1', (tester) async {
      await ouvrirSemaine(tester, Role.cs, 45);
      expect(find.text('Semaine 45 · 2 – 6 novembre'), findsOneWidget);
      expect(find.text('Prévu 4 · Réalisé 1 (25 %)'), findsOneWidget);
      // Cinq lignes : réalisée, déplacée, ajoutée et deux à faire.
      expect(
        find.text('Déplacé · prévu Mar 14:00 → planifié Mar 15:10'),
        findsOneWidget,
      );
      expect(find.text('Ajouté (non prévu) · Mer 16:00'), findsOneWidget);
      expect(find.text('Réalisé comme prévu · Lun 09:30'), findsOneWidget);
      expect(find.text('À faire · Mer 11:30'), findsOneWidget);
      expect(find.text('À faire · Jeu 10:00'), findsOneWidget);
    });

    testWidgets('directeur : prévu 8, réalisé 3', (tester) async {
      await ouvrirSemaine(tester, Role.dir, 45);
      expect(find.text('Prévu 8 · Réalisé 3 (38 %)'), findsOneWidget);
      expect(
        find.text('Retiré du planning, non réalisé · prévu Jeu 14:00'),
        findsOneWidget,
      );
    });

    testWidgets('la feuille suit le planning', (tester) async {
      final c = await ouvrirSemaine(tester, Role.cs, 45);
      c
          .read(crmProvider.notifier)
          .majEtape('e8', (e) => e.copyWith(fait: true));
      await tester.pumpAndSettle();
      expect(find.text('Prévu 4 · Réalisé 2 (50 %)'), findsOneWidget);
    });

    testWidgets('semaine validée : lignes non faites « Non réalisé »', (
      tester,
    ) async {
      final c = await ouvrirSemaine(tester, Role.cs, 45);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
      await tester.pumpAndSettle();
      expect(find.text('Non réalisé · Mer 11:30'), findsOneWidget);
      expect(find.text('Non réalisé · Jeu 10:00'), findsOneWidget);
    });

    testWidgets('sans prévision : pas de comparaison possible', (tester) async {
      final c = await ouvrirSemaine(tester, Role.cs, 45);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.prevision);
      await tester.pumpAndSettle();
      expect(find.text('Semaine 45 · 2 – 6 novembre'), findsOneWidget);
      expect(find.textContaining('Prévu '), findsNothing);
      expect(
        find.text(
          "Prévision non renseignée cette semaine : il n'y a pas de comparaison possible.",
        ),
        findsOneWidget,
      );
    });
  });
}
