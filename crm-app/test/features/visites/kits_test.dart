import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/visites/kit_detail_sheet.dart';
import 'package:crm_app/features/visites/kits_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_visites.dart';

Visite d0(WidgetTester tester) =>
    storeApp(tester).visites.firstWhere((v) => v.id == 'd0');

int nbCochees(WidgetTester tester) => tester
    .widgetList<CaseCoche>(find.byType(CaseCoche))
    .where((c) => c.cochee)
    .length;

void main() {
  group('Kits du rayon (kits l.1352-1358, KITS l.354-359)', () {
    testWidgets('liste des quatre kits avec ceux déjà cochés', (tester) async {
      await lancerApp(tester, Role.promoteur);
      AppRoutes.kitsDuRayon(contexteCoquille(tester), 'd0');
      await tester.pumpAndSettle();
      expect(find.byType(KitsSheet), findsOneWidget);
      expect(find.text('Kits du rayon'), findsOneWidget);
      expect(
        find.text(
          'Cochez les kits constatés en rayon pour la distribution numérique.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('COSMIA ZIPPED PLANE KIT\nCosmia · Réf. COSMIA-01'),
        findsOneWidget,
      );
      expect(find.text('HP-KIT 0,50M GH\nRéf. KIT91265'), findsOneWidget);
      expect(find.text('FP-KIT 0,66M GB\nRéf. KIT91267'), findsOneWidget);
      expect(
        find.text('Kit racines brun\nJean Louis David · Réf. 900024'),
        findsOneWidget,
      );
      expect(find.byType(CaseCoche), findsNWidgets(4));
      // d0 a déjà COSMIA-01 et 900024
      expect(nbCochees(tester), 2);
      expect(find.text('✓'), findsNWidgets(2));
      expect(find.text('Tout décocher'), findsOneWidget);
      expect(find.text('Valider (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'cocher ajoute le kit à la visite, décocher le retire avec sa DN',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        AppRoutes.kitsDuRayon(contexteCoquille(tester), 'd0');
        await tester.pumpAndSettle();
        expect(d0(tester).dn.keys, containsAll(['COSMIA-01', '900024']));

        await tester.tap(find.textContaining('HP-KIT 0,50M GH'));
        await tester.pumpAndSettle();
        expect(d0(tester).kits, ['COSMIA-01', '900024', 'KIT91265']);
        expect(d0(tester).dn['KIT91265'], 0);
        expect(find.text('Valider (3)'), findsOneWidget);
        expect(nbCochees(tester), 3);

        await tester.tap(find.textContaining('COSMIA ZIPPED PLANE KIT'));
        await tester.pumpAndSettle();
        expect(d0(tester).kits, ['900024', 'KIT91265']);
        expect(d0(tester).dn.containsKey('COSMIA-01'), isFalse);
        expect(find.text('Valider (2)'), findsOneWidget);
      },
    );

    testWidgets('« Tout décocher » vide la sélection, « Valider » ferme', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      AppRoutes.kitsDuRayon(contexteCoquille(tester), 'd0');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tout décocher'));
      await tester.pumpAndSettle();
      expect(d0(tester).kits, isEmpty);
      expect(d0(tester).dn, isEmpty);
      expect(find.text('Valider (0)'), findsOneWidget);
      expect(nbCochees(tester), 0);
      await tester.tap(find.text('Valider (0)'));
      await tester.pumpAndSettle();
      expect(find.byType(KitsSheet), findsNothing);
    });

    testWidgets('le directeur coche aussi les kits de sa visite', (
      tester,
    ) async {
      await lancerApp(tester, Role.dir);
      AppRoutes.kitsDuRayon(contexteCoquille(tester), 'd0');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('FP-KIT 0,66M GB'));
      await tester.pumpAndSettle();
      expect(d0(tester).kits.last, 'KIT91267');
    });
  });

  group('Détail d’un kit (kit-detail l.1345-1351, KIT_PRODUITS l.361-366)', () {
    Future<void> ouvrir(WidgetTester tester, String code) async {
      await lancerApp(tester, Role.promoteur);
      AppRoutes.detailKit(contexteCoquille(tester), code);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'COSMIA-01 : cinq produits dans le kit, quatre connus du catalogue',
      (tester) async {
        await ouvrir(tester, 'COSMIA-01');
        expect(find.byType(KitDetailSheet), findsOneWidget);
        expect(find.text('COSMIA ZIPPED PLANE KIT'), findsOneWidget);
        expect(
          find.text('Réf. COSMIA-01 · 5 produits dans le kit'),
          findsOneWidget,
        );
        // 900025 n'est pas au catalogue : sa ligne n'est pas affichée
        expect(find.text('×6'), findsNWidgets(4));
        expect(find.text('Coloration châtain 4.0'), findsOneWidget);
        expect(
          find.text('Franck Provost · Réf. 900021 · EAN 376123450021'),
          findsOneWidget,
        );
        expect(find.text('Coloration blond 7.3'), findsOneWidget);
        expect(find.text('Coloration acajou 5.5'), findsOneWidget);
        expect(
          find.text('Jean Louis David · Réf. 900023 · EAN 376123450023'),
          findsOneWidget,
        );
        expect(find.text('Kit racines brun'), findsOneWidget);
        expect(find.text('Fermer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('KIT91265 : quantités différentes', (tester) async {
      await ouvrir(tester, 'KIT91265');
      expect(find.text('HP-KIT 0,50M GH'), findsOneWidget);
      expect(
        find.text('Réf. KIT91265 · 5 produits dans le kit'),
        findsOneWidget,
      );
      expect(find.text('×12'), findsOneWidget);
      expect(find.text('×6'), findsNWidgets(3));
      expect(find.text('Shampooing doux usage fréquent'), findsOneWidget);
    });

    testWidgets('KIT91267 : les cinq produits sont au catalogue', (
      tester,
    ) async {
      await ouvrir(tester, 'KIT91267');
      expect(
        find.text('Réf. KIT91267 · 5 produits dans le kit'),
        findsOneWidget,
      );
      expect(find.text('×6'), findsNWidgets(5));
      expect(find.text('Rouge mat 101'), findsOneWidget);
      expect(find.text('Baume teinté 520'), findsOneWidget);
    });

    testWidgets('900024 : quatre produits par trois', (tester) async {
      await ouvrir(tester, '900024');
      expect(find.text('Kit racines brun'), findsWidgets);
      expect(find.text('Réf. 900024 · 4 produits dans le kit'), findsOneWidget);
      expect(find.text('×3'), findsNWidgets(3));
    });

    testWidgets(
      'un kit inconnu : son code pour nom, composition non renseignée',
      (tester) async {
        await ouvrir(tester, 'XYZ-9');
        expect(find.text('XYZ-9'), findsOneWidget);
        expect(find.text('Réf. XYZ-9 · 0 produit dans le kit'), findsOneWidget);
        expect(find.text('Composition non renseignée.'), findsOneWidget);
      },
    );

    testWidgets('« Fermer » ferme la feuille', (tester) async {
      await ouvrir(tester, 'COSMIA-01');
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(find.byType(KitDetailSheet), findsNothing);
    });
  });
}
