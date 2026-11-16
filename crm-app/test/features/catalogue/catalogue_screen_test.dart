import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/catalogue/catalogue_screen.dart';
import 'package:crm_app/features/catalogue/state/filtres_catalogue_state.dart';
import 'package:crm_app/features/catalogue/widgets/carte_produit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_catalogue.dart';

/// « Référentiel produits » : `salesProduits` l.1241-1248, `prodsFiltres` l.1237-1240, actions `p-*` l.1569-1577
/// et `bientot-scan` l.1494 de la maquette. Le catalogue est le même pour les trois rôles (menu « + » de chacun).
void main() {
  final hint = find.text('Nom, marque, EAN ou code article');
  final references = find.textContaining('Réf. ');

  for (final role in Role.values) {
    group('Catalogue pour ${role.profil.libelle}', () {
      testWidgets(
        'ouvert depuis le menu « + » : entête, recherche et 24 références',
        (tester) async {
          await ouvrirOngletPlus(tester, role, OngletApp.catalogue);
          expect(find.text('Référentiel produits'), findsWidgets);
          expect(
            find.text('24 références · données du 4 nov.'),
            findsOneWidget,
          );
          expect(find.text('▦'), findsOneWidget);
          expect(hint, findsOneWidget);
          expect(find.byType(BoutonFiltre), findsOneWidget);
          expect(references, findsNWidgets(24));
          expect(find.text('Aucun produit ne correspond.'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'la recherche filtre la liste et le texte est gardé en changeant d’onglet',
        (tester) async {
          await ouvrirOngletPlus(tester, role, OngletApp.catalogue);
          await tester.enterText(find.byType(TextFormField), 'milano');
          await tester.pumpAndSettle();
          expect(references, findsNWidgets(6));
          expect(find.text('Rouge mat 101'), findsOneWidget);
          expect(find.text('Shampooing doux usage fréquent'), findsNothing);
          expect(
            conteneurApp(tester).read(filtresCatalogueProvider).q,
            'milano',
          );

          // Autre onglet puis retour : la recherche est conservée (S.sProd.q).
          await allerOngletPlus(tester, OngletApp.news);
          expect(find.text('4 informations du siège'), findsOneWidget);
          await allerOngletPlus(tester, OngletApp.catalogue);
          expect(references, findsNWidgets(6));
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField))
                .controller!
                .text,
            'milano',
          );
        },
      );

      testWidgets(
        'un appui sur « ▦ » annonce que le scan n’est pas encore disponible',
        (tester) async {
          await ouvrirOngletPlus(tester, role, OngletApp.catalogue);
          await tester.tap(find.text('▦'));
          await tester.pump();
          expect(find.text(messageScan), findsOneWidget);
          await laisserPasserToast(tester);
          expect(find.text(messageScan), findsNothing);
        },
      );

      testWidgets('un appui sur un produit ouvre sa fiche en feuille', (
        tester,
      ) async {
        await ouvrirOngletPlus(tester, role, OngletApp.catalogue);
        await toucher(tester, find.text('Coloration blond 7.3'));
        // Le nom est le titre de la feuille : il est affiché deux fois (carte et feuille).
        expect(find.text('Coloration blond 7.3'), findsNWidgets(2));
        expect(find.text('14,61 € HT (prix indicatif)'), findsOneWidget);
        expect(find.text('Colisage'), findsOneWidget);
        expect(find.text('6 unités par colis'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('Cartes produit', () {
    testWidgets(
      'textes de la maquette : nom, marque · famille, prix HT, stock, référence',
      (tester) async {
        await pumpEcran(tester, const CatalogueScreen());
        // a1 : `PRODUITS[0]` l.1446.
        expect(find.text('Shampooing doux usage fréquent'), findsOneWidget);
        expect(find.text('Franck Provost · Shampooings'), findsNWidgets(2));
        expect(find.text('3,46 €'), findsOneWidget);
        expect(find.text('En stock · 98'), findsOneWidget);
        expect(find.text('Réf. 900016'), findsOneWidget);
        // a2 : stock bas ; a13 : rupture ; a6 : prix entier affiché avec deux décimales.
        expect(find.text('Stock bas · 45'), findsOneWidget);
        expect(find.text('Rupture · 3'), findsOneWidget);
        expect(find.text('11,00 €'), findsOneWidget);
        expect(find.text('Jean Louis David · Colorations'), findsNWidgets(2));
        expect(find.text('MB Milano · Protections SPF'), findsOneWidget);
        // « HT » sous chacun des 14 prix du catalogue ; ni les kits ni les produits PEM n'ont de prix.
        expect(find.text('HT'), findsNWidgets(14));
      },
    );

    testWidgets('couleurs du stock : vert, ambre, rouge', (tester) async {
      await pumpEcran(tester, const CatalogueScreen());
      Color? couleur(String texte) =>
          tester.widget<Text>(find.text(texte)).style?.color;
      expect(couleur('En stock · 98'), AppColors.ok);
      expect(couleur('Stock bas · 45'), const Color(0xFFB45309));
      expect(couleur('Rupture · 3'), AppColors.alert);
    });

    testWidgets(
      'kits et produits PEM : pastilles, famille seule et pas de prix ni de stock',
      (tester) async {
        await pumpEcran(tester, const CatalogueScreen());
        // Kit du catalogue (a5) + 2 kits : 3 pastilles « Kit » ; les 2 kits sans marque ont la famille « Kit ».
        expect(find.text('Kit'), findsNWidgets(5));
        expect(find.text('HP-KIT 0,50M GH'), findsOneWidget);
        expect(find.text('Réf. KIT91265'), findsOneWidget);
        // Produits PEM : 8 pastilles, famille « Produit PEM », statut Actif (3) ou Inactif (4), aucun pour le dernier.
        expect(find.text('PEM'), findsNWidgets(8));
        expect(find.text('Produit PEM'), findsNWidgets(8));
        expect(find.text('Actif'), findsNWidgets(3));
        expect(find.text('Inactif'), findsNWidgets(4));
        expect(find.text('DEMELISS AIRBRUSH WONDER WOMAN'), findsOneWidget);
        expect(find.text('Réf. 20021'), findsOneWidget);
        expect(find.text('Mis en avant'), findsNothing);
      },
    );

    testWidgets(
      'pastille de promotion et « Mis en avant » quand le produit en a',
      (tester) async {
        const produit = Produit(
          id: 'x1',
          nom: 'Produit d’essai',
          marque: 'Franck Provost',
          cat: 'Franck Provost',
          famille: 'Shampooings',
          code: '900099',
          prix: 5,
          stock: NiveauStock.enStock,
          promo: '-20 %',
          avant: true,
          qte: 0,
        );
        await pumpEcran(
          tester,
          Scaffold(
            body: CarteProduit(produit: produit, onTap: () {}),
          ),
        );
        expect(find.text('-20 %'), findsOneWidget);
        expect(find.text('Mis en avant'), findsOneWidget);
        // Quantité nulle : seul le niveau de stock est affiché (`p.qte ? … : ''`).
        expect(find.text('En stock'), findsOneWidget);
        final pastille = tester.widget<Pastille>(
          find.widgetWithText(Pastille, '-20 %'),
        );
        expect(pastille.variante, VariantePastille.rose);
      },
    );
  });

  group('Recherche et filtres', () {
    testWidgets('EAN, code article et nom retrouvent le produit', (
      tester,
    ) async {
      await pumpEcran(tester, const CatalogueScreen());
      await tester.enterText(find.byType(TextFormField), '376123450040');
      await tester.pumpAndSettle();
      expect(references, findsOneWidget);
      expect(find.text('Stick lèvres SPF 30'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '900016');
      await tester.pumpAndSettle();
      expect(find.text('Shampooing doux usage fréquent'), findsOneWidget);
      expect(references, findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'ROUGE');
      await tester.pumpAndSettle();
      expect(references, findsNWidgets(3));
    });

    testWidgets('aucun résultat : message vide de la maquette', (tester) async {
      await pumpEcran(tester, const CatalogueScreen(), role: Role.cs);
      await tester.enterText(find.byType(TextFormField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Aucun produit ne correspond.'), findsOneWidget);
      expect(references, findsNothing);
      expect(find.byType(CarteProduit), findsNothing);
      // La mention « 24 références » reste celle du référentiel entier.
      expect(find.text('24 références · données du 4 nov.'), findsOneWidget);
    });

    testWidgets('le bouton filtre affiche le nombre de filtres actifs', (
      tester,
    ) async {
      await pumpEcran(tester, const CatalogueScreen(), role: Role.dir);
      final compteur = find.descendant(
        of: find.byType(BoutonFiltre),
        matching: find.byType(Text),
      );
      expect(compteur, findsNothing);

      final conteneur = conteneurEcran<CatalogueScreen>(tester);
      final f = conteneur.read(filtresCatalogueProvider.notifier);
      f.choisirMarque('MB Milano');
      f.choisirStock(NiveauStock.stockBas);
      f.basculerPem();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BoutonFiltre),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      // Marque MB Milano + stock bas + PEM : aucun produit.
      expect(find.text('Aucun produit ne correspond.'), findsOneWidget);
    });

    testWidgets('le bouton filtre ouvre la feuille « Filtres »', (
      tester,
    ) async {
      await pumpEcran(tester, const CatalogueScreen());
      await toucherFiltres(tester);
      expect(find.text('Filtres'), findsWidgets);
      expect(find.text('MARQUE'), findsOneWidget);
      expect(find.text('Voir 24 produits'), findsOneWidget);
    });
  });
}
