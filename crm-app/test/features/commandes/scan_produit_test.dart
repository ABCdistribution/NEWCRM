import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/features/commandes/logic/regles_commande.dart';
import 'package:crm_app/features/commandes/logic/scan_produit.dart';
import 'package:crm_app/features/commandes/prise_commande_screen.dart';
import 'package:crm_app/features/commandes/state/commande_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

Produit _p(String id) => produitParId(id)!;

ProviderContainer _conteneur(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PriseCommandeScreen)));

/// Ouvre la prise de commande puis la feuille de scan (animation réduite : la ligne rouge ne boucle pas).
Future<void> _ouvrirScan(WidgetTester tester) async {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  await pumpEcran(tester, const PriseCommandeScreen(magasinId: 'm1'));
  await tester.tap(find.bySemanticsLabel('Scanner un code-barres'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(chargerInter);

  group('Retrouver un produit par le code lu', () {
    test('par son EAN, espaces ignorés', () {
      expect(produitParCodeLu(' ${_p('a1').ean} ', tousProduits())?.id, 'a1');
    });

    test('un UPC-A (sans le 0 de tête) retrouve l’EAN-13 correspondant', () {
      const p = Produit(
        id: 'x',
        nom: 'X',
        marque: 'M',
        famille: 'F',
        code: '1',
        ean: '0123456789012',
      );
      expect(produitParCodeLu('123456789012', [p])?.id, 'x');
    });

    test('code vide, nul ou inconnu : aucun produit', () {
      expect(produitParCodeLu(null, tousProduits()), isNull);
      expect(produitParCodeLu('  ', tousProduits()), isNull);
      expect(produitParCodeLu('999', tousProduits()), isNull);
    });

    test('un produit sans EAN n’est jamais retrouvé', () {
      const p = Produit(
        id: 'x',
        nom: 'X',
        marque: 'M',
        famille: 'F',
        code: '1',
      );
      expect(produitParCodeLu('0', [p]), isNull);
    });
  });

  group('Classer un scan', () {
    test('inconnu', () {
      final l = classerScan('0000000000999', tousProduits());
      expect(l.resultat, ResultatScan.inconnu);
      expect(l.produit, isNull);
    });

    test('disponible (en stock ou stock bas)', () {
      expect(
        classerScan(_p('a1').ean, tousProduits()).resultat,
        ResultatScan.disponible,
      );
      expect(
        classerScan(_p('a2').ean, tousProduits()).resultat,
        ResultatScan.disponible,
      );
    });

    test('en rupture', () {
      final l = classerScan(_p('a13').ean, tousProduits());
      expect(l.resultat, ResultatScan.rupture);
      expect(l.produit?.id, 'a13');
    });

    test('rupture : niveau « Rupture » ou quantité à zéro', () {
      const base = Produit(
        id: 'x',
        nom: 'X',
        marque: 'M',
        famille: 'F',
        code: '1',
      );
      expect(produitEnRupture(base), isFalse);
      const zero = Produit(
        id: 'x',
        nom: 'X',
        marque: 'M',
        famille: 'F',
        code: '1',
        stock: NiveauStock.enStock,
        qte: 0,
      );
      expect(produitEnRupture(zero), isTrue);
      const niveau = Produit(
        id: 'x',
        nom: 'X',
        marque: 'M',
        famille: 'F',
        code: '1',
        stock: NiveauStock.rupture,
      );
      expect(produitEnRupture(niveau), isTrue);
    });
  });

  group('Doublon immédiat', () {
    final t = DateTime(2026, 11, 23, 10);

    test('même code en moins de 3 s : doublon', () {
      expect(
        scanEnDoublon(
          code: 'A',
          dernier: 'A',
          vuLe: t,
          maintenant: t.add(const Duration(milliseconds: 2900)),
        ),
        isTrue,
      );
    });

    test('même code après 3 s ou autre code : pas un doublon', () {
      expect(
        scanEnDoublon(
          code: 'A',
          dernier: 'A',
          vuLe: t,
          maintenant: t.add(const Duration(seconds: 3)),
        ),
        isFalse,
      );
      expect(
        scanEnDoublon(code: 'B', dernier: 'A', vuLe: t, maintenant: t),
        isFalse,
      );
    });
  });

  group('Message de rupture (démonstration)', () {
    testWidgets('s’affiche dès la lecture, sans ajouter le produit', (
      tester,
    ) async {
      await _ouvrirScan(tester);
      await tester.tap(find.text('Simuler un produit en rupture'));
      await tester.pumpAndSettle();
      expect(find.text('Scanner un produit'), findsOneWidget);
      expect(
        find.text('Stick lèvres SPF 30 est en rupture de stock'),
        findsOne,
      );
      expect(find.text('Réapprovisionnement prévu le 12 nov.'), findsOne);
      expect(find.text('Voir les remplacements'), findsOneWidget);
      expect(find.text('Fermer'), findsOneWidget);
      expect(find.text('Simuler un scan'), findsNothing);
      expect(_conteneur(tester).read(commandeEnCoursProvider)!.lignes, isEmpty);
    });

    testWidgets('« Fermer » reprend le scan', (tester) async {
      await _ouvrirScan(tester);
      await tester.tap(find.text('Simuler un produit en rupture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('est en rupture de stock'), findsNothing);
      expect(find.text('Simuler un scan'), findsOneWidget);
      expect(find.text('Scanner un produit'), findsOneWidget);
    });

    testWidgets(
      '« Voir les remplacements » propose 3 produits ; le choix les ajoute à la commande',
      (tester) async {
        await _ouvrirScan(tester);
        await tester.tap(find.text('Simuler un produit en rupture'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Voir les remplacements'));
        await tester.pumpAndSettle();
        expect(find.text('Produits de remplacement'), findsOneWidget);
        expect(find.text('Choisir'), findsNWidgets(3));
        await tester.tap(find.text('Choisir').first);
        await tester.pumpAndSettle();
        final lignes = _conteneur(tester).read(commandeEnCoursProvider)!.lignes;
        expect(lignes, hasLength(1));
        expect(lignes.single.remplace, 'a13');
        expect(lignes.single.qty, greaterThan(0));
        expect(find.textContaining('est en rupture de stock'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    test(
      'sans date de réapprovisionnement, le texte de stock reste correct',
      () {
        const p = Produit(
          id: 'x',
          nom: 'X',
          marque: 'M',
          famille: 'F',
          code: '1',
          stock: NiveauStock.rupture,
          qte: 0,
        );
        expect(infoStock(p).texte, 'Rupture de stock');
      },
    );
  });
}
