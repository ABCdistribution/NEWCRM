import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/catalogue/state/filtres_catalogue_state.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_catalogue.dart';

/// Feuille « Filtres » du catalogue : modale `sfiltres` l.1401-1409, actions `p-cat`, `p-stock`, `p-promo`,
/// `p-avant`, `p-kit`, `p-pem`, `p-reset` l.1569-1577.
void main() {
  final references = find.textContaining('Réf. ');

  Future<void> ouvrirFeuille(WidgetTester tester, Role role) async {
    await ouvrirOngletPlus(tester, role, OngletApp.catalogue);
    await toucherFiltres(tester);
  }

  bool choisi(WidgetTester tester, String libelle) => tester
      .widget<OptionRadio>(find.widgetWithText(OptionRadio, libelle))
      .selectionne;

  Finder interrupteur(int i) => find.byType(Interrupteur).at(i);

  bool actif(WidgetTester tester, int i) =>
      tester.widget<Interrupteur>(interrupteur(i)).valeur;

  for (final role in Role.values) {
    group('Filtres du catalogue pour ${role.profil.libelle}', () {
      testWidgets('textes de la maquette et choix par défaut', (tester) async {
        await ouvrirFeuille(tester, role);
        expect(find.text('Filtres'), findsOneWidget);
        for (final t in [
          'MARQUE',
          'Toutes les marques',
          'Franck Provost',
          'Jean Louis David',
          'MB Milano',
          'STOCK',
          'Tous les stocks',
          'En stock',
          'Stock bas',
          'Rupture',
          'AUTRES',
          'En promotion',
          'Mis en avant',
          'Kits',
          'Produits PEM',
          'Réinitialiser',
          'Voir 24 produits',
        ]) {
          expect(find.text(t), findsOneWidget, reason: t);
        }
        expect(choisi(tester, 'Toutes les marques'), isTrue);
        expect(choisi(tester, 'Tous les stocks'), isTrue);
        expect(choisi(tester, 'MB Milano'), isFalse);
        for (var i = 0; i < 4; i++) {
          expect(actif(tester, i), isFalse);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'marque : le compteur « Voir N produits » et la liste suivent',
        (tester) async {
          await ouvrirFeuille(tester, role);
          await toucher(tester, find.text('MB Milano'));
          expect(choisi(tester, 'MB Milano'), isTrue);
          expect(choisi(tester, 'Toutes les marques'), isFalse);
          expect(find.text('Voir 6 produits'), findsOneWidget);
          expect(
            conteneurApp(tester).read(filtresCatalogueProvider).marque,
            'MB Milano',
          );

          await toucher(tester, find.text('Franck Provost'));
          expect(find.text('Voir 4 produits'), findsOneWidget);
          await toucher(tester, find.text('Toutes les marques'));
          expect(find.text('Voir 24 produits'), findsOneWidget);
        },
      );

      testWidgets('stock : singulier à 1 produit, kits et PEM exclus', (
        tester,
      ) async {
        await ouvrirFeuille(tester, role);
        await toucher(tester, find.text('Rupture'));
        expect(find.text('Voir 1 produit'), findsOneWidget);
        await toucher(tester, find.text('Stock bas'));
        expect(find.text('Voir 4 produits'), findsOneWidget);
        await toucher(tester, find.text('En stock'));
        expect(find.text('Voir 9 produits'), findsOneWidget);
        await toucher(tester, find.text('Tous les stocks'));
        expect(find.text('Voir 24 produits'), findsOneWidget);
      });

      testWidgets('interrupteurs : kits, PEM, promotion et mis en avant', (
        tester,
      ) async {
        await ouvrirFeuille(tester, role);
        // Seul l'interrupteur agit : toucher le libellé ne change rien (`.qrow` n'a pas d'action).
        await toucher(tester, find.text('Kits'));
        expect(actif(tester, 2), isFalse);
        await toucher(tester, interrupteur(2)); // Kits
        expect(actif(tester, 2), isTrue);
        expect(find.text('Voir 3 produits'), findsOneWidget);
        await toucher(tester, interrupteur(2));
        await toucher(tester, interrupteur(3)); // Produits PEM
        expect(find.text('Voir 8 produits'), findsOneWidget);
        await toucher(tester, interrupteur(3));
        await toucher(tester, interrupteur(0)); // En promotion : aucun produit
        expect(find.text('Voir 0 produit'), findsOneWidget);
        await toucher(tester, interrupteur(0));
        await toucher(tester, interrupteur(1)); // Mis en avant : aucun produit
        expect(find.text('Voir 0 produit'), findsOneWidget);
        await toucher(tester, interrupteur(1));
        expect(find.text('Voir 24 produits'), findsOneWidget);
      });

      testWidgets('un interrupteur actif prend le bleu de l’univers', (
        tester,
      ) async {
        await ouvrirFeuille(tester, role);
        await toucher(tester, interrupteur(2));
        final boite = tester.widget<AnimatedContainer>(
          find.descendant(
            of: interrupteur(2),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(
          (boite.decoration! as BoxDecoration).color,
          UniversPalette.pour(role.univers).bleu,
        );
      });

      testWidgets('Réinitialiser garde la marque, comme la maquette', (
        tester,
      ) async {
        await ouvrirFeuille(tester, role);
        await toucher(tester, find.text('MB Milano'));
        await toucher(tester, find.text('Stock bas'));
        await toucher(tester, interrupteur(0));
        await toucher(tester, interrupteur(1));
        await toucher(tester, interrupteur(2));
        await toucher(tester, interrupteur(3));
        expect(find.text('Voir 0 produit'), findsOneWidget);

        await toucher(tester, find.text('Réinitialiser'));
        expect(choisi(tester, 'MB Milano'), isTrue);
        expect(choisi(tester, 'Tous les stocks'), isTrue);
        for (var i = 0; i < 4; i++) {
          expect(actif(tester, i), isFalse);
        }
        expect(find.text('Voir 6 produits'), findsOneWidget);
        final f = conteneurApp(tester).read(filtresCatalogueProvider);
        expect(f.marque, 'MB Milano');
        expect(f.nombreActifs, 1);
      });

      testWidgets(
        '« Voir N produits » ferme la feuille : la liste et le compteur sont à jour',
        (tester) async {
          await ouvrirFeuille(tester, role);
          await toucher(tester, find.text('Jean Louis David'));
          await toucher(tester, find.text('Stock bas'));
          expect(find.text('Voir 1 produit'), findsOneWidget);
          await toucher(tester, find.text('Voir 1 produit'));
          expect(find.text('Voir 1 produit'), findsNothing);
          expect(find.text('MARQUE'), findsNothing);
          expect(references, findsOneWidget);
          expect(find.text('Après-shampooing démêlant'), findsOneWidget);
          // Deux filtres actifs : marque et stock.
          expect(
            find.descendant(
              of: find.byType(BoutonFiltre),
              matching: find.text('2'),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'un appui sur le voile ferme la feuille et garde les filtres',
        (tester) async {
          await ouvrirFeuille(tester, role);
          await toucher(tester, interrupteur(2));
          await tester.tapAt(const Offset(195, 20));
          await tester.pumpAndSettle();
          expect(find.text('MARQUE'), findsNothing);
          expect(references, findsNWidgets(3));
          expect(
            conteneurApp(tester).read(filtresCatalogueProvider).kit,
            isTrue,
          );
        },
      );
    });
  }

  testWidgets('la feuille s’ouvre aussi par AppRoutes.filtresCatalogue', (
    tester,
  ) async {
    await ouvrirOngletPlus(tester, Role.dir, OngletApp.catalogue);
    final ctx = tester.element(find.byType(ShellScreen));
    AppRoutes.filtresCatalogue(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Voir 24 produits'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
