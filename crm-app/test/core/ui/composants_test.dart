import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../../support/catalogue_composants.dart';

void main() {
  for (final role in [Role.promoteur, Role.dir]) {
    testWidgets(
      'tous les composants s’affichent sans débordement (${role.univers.name})',
      (tester) async {
        await pumpEcran(tester, const CatalogueComposants(), role: role);
        expect(tester.takeException(), isNull);
        // Fait défiler jusqu'en bas pour construire toute la page.
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -6000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Passer en client'), findsOneWidget);
      },
    );
  }

  testWidgets('NomMagasin : pastille de classe seulement si elle est connue', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      const Column(
        children: [
          NomMagasin('Carrefour – Rouen', classe: 'b'),
          NomMagasin('Leclerc – Caen', classe: '—'),
          NomMagasin('U Express – Lille'),
          PastilleClasse('A++', avecMot: true),
          PastilleClasse(''),
        ],
      ),
      role: Role.promoteur,
    );
    expect(find.text('Carrefour – Rouen'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Leclerc – Caen'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(find.text('U Express – Lille'), findsOneWidget);
    expect(find.text('Classe A++'), findsOneWidget);
    expect(find.byType(Pastille), findsNWidgets(2));
  });

  testWidgets('la palette suit l’univers du thème', (tester) async {
    late UniversPalette p;
    await pumpEcran(
      tester,
      Builder(
        builder: (c) {
          p = c.univers;
          return const SizedBox();
        },
      ),
      role: Role.promoteur,
    );
    expect(p.univers, Univers.sales);
    expect(p.acc, const Color(0xFF1F7AEA));
    expect(p.fondCouleurs, hasLength(6));
    expect(UniversPalette.fondArrets, [0, 0.12, 0.28, 0.46, 0.66, 1]);
    expect(UniversPalette.pilot.acc, const Color(0xFF7A56E6));
    expect(UniversPalette.pilot.bleu, const Color(0xFF1D4ED8));
  });

  testWidgets('segment, interrupteur et stepper réagissent', (tester) async {
    await pumpEcran(tester, const CatalogueComposants());
    await tester.ensureVisible(find.text('Tout le secteur'));
    await tester.tap(find.text('Tout le secteur'));
    await tester.pump();
    await tester.ensureVisible(find.byType(StepperQte));
    await tester.tap(find.bySemanticsLabel('Plus'));
    await tester.pump();
    expect(find.text('7'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'le toast s’affiche puis disparaît tout seul, un seul à la fois',
    (tester) async {
      late BuildContext ctx;
      await pumpEcran(
        tester,
        Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: Text('page'));
          },
        ),
      );
      AppToast.show(ctx, 'Premier message');
      await tester.pump();
      expect(find.text('Premier message'), findsOneWidget);
      AppToast.show(ctx, 'Second message');
      await tester.pump();
      expect(find.text('Premier message'), findsNothing);
      expect(find.text('Second message'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2700));
      expect(find.text('Second message'), findsNothing);
    },
  );

  testWidgets('feuille basse et confirmation', (tester) async {
    late BuildContext ctx;
    await pumpEcran(
      tester,
      Builder(
        builder: (c) {
          ctx = c;
          return const Scaffold(body: Text('page'));
        },
      ),
    );
    unawaitedSheet() => showAppSheet<void>(
      ctx,
      builder: (_) =>
          const FeuilleBase(titre: 'Filtres', children: [Text('contenu')]),
    );
    unawaitedSheet();
    await tester.pumpAndSettle();
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.text('contenu'), findsOneWidget);
    await tester.tapAt(const Offset(195, 30));
    await tester.pumpAndSettle();
    expect(find.text('Filtres'), findsNothing);

    bool? reponse;
    showConfirmation(
      ctx,
      titre: 'Passer en client ?',
      texte: 'Action définitive.',
      ok: 'Passer en client',
    ).then((v) => reponse = v);
    await tester.pumpAndSettle();
    expect(find.text('Passer en client ?'), findsOneWidget);
    await tester.tap(find.text('Passer en client'));
    await tester.pumpAndSettle();
    expect(reponse, isTrue);
  });
}
