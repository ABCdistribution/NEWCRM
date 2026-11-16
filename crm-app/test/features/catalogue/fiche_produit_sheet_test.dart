import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/features/catalogue/fiche_produit_sheet.dart';
import 'package:crm_app/features/catalogue/widgets/ligne_feuille.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Feuille « Fiche produit » : modale `sproduit` l.1436-1440 de la maquette.
void main() {
  /// Ouvre la fiche d'un produit par `AppRoutes.ficheProduit` dans l'application lancée avec `role`.
  Future<void> ouvrirFiche(
    WidgetTester tester,
    Role role,
    String produitId,
  ) async {
    await lancerApp(tester, role);
    AppRoutes.ficheProduit(tester.element(find.byType(ShellScreen)), produitId);
    await tester.pumpAndSettle();
  }

  Finder ligne(String cle) => find.widgetWithText(LigneFeuille, cle);

  /// Valeur de la ligne `cle` (le texte en gras à droite).
  String valeur(WidgetTester tester, String cle) =>
      tester.widget<LigneFeuille>(ligne(cle)).valeur;

  for (final role in Role.values) {
    group('Fiche produit pour ${role.profil.libelle}', () {
      testWidgets('produit du catalogue : toutes les lignes de la maquette', (
        tester,
      ) async {
        await ouvrirFiche(tester, role, 'a1');
        expect(find.text('Shampooing doux usage fréquent'), findsOneWidget);
        expect(find.text('3,46 € HT (prix indicatif)'), findsOneWidget);
        expect(valeur(tester, 'Marque'), 'Franck Provost');
        expect(valeur(tester, 'Famille'), 'Shampooings');
        expect(valeur(tester, 'Code article'), '900016');
        expect(valeur(tester, 'EAN'), '376123450016');
        expect(valeur(tester, 'Colisage'), '6 unités par colis');
        expect(valeur(tester, 'Stock'), 'En stock');
        // Pas de promotion en cours dans la démo : pas de ligne « Promotion ».
        expect(ligne('Promotion'), findsNothing);
        expect(
          find.text('Produit disponible dans les visites PEM'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('le prix indicatif est en bleu de l’univers', (tester) async {
        await ouvrirFiche(tester, role, 'a2');
        final prix = tester.widget<Text>(
          find.text('22,62 € HT (prix indicatif)'),
        );
        expect(prix.style?.color, UniversPalette.pour(role.univers).bleu);
        expect(prix.style?.fontWeight, FontWeight.w800);
      });

      testWidgets('produit en rupture : le stock affiche « Rupture »', (
        tester,
      ) async {
        await ouvrirFiche(tester, role, 'a13');
        expect(find.text('20,05 € HT (prix indicatif)'), findsOneWidget);
        expect(valeur(tester, 'Stock'), 'Rupture');
        expect(valeur(tester, 'Colisage'), '6 unités par colis');
        expect(valeur(tester, 'Famille'), 'Protections SPF');
      });

      testWidgets('produit PEM : version réduite avec le code et le statut', (
        tester,
      ) async {
        await ouvrirFiche(tester, role, 'pem20007');
        expect(find.text('Salon Series'), findsOneWidget);
        expect(
          find.text('Produit disponible dans les visites PEM'),
          findsOneWidget,
        );
        expect(valeur(tester, 'Code article'), '20007');
        expect(valeur(tester, 'Statut'), 'Actif');
        // La version réduite n'a ni prix, ni marque, ni stock.
        expect(find.textContaining('HT (prix indicatif)'), findsNothing);
        expect(ligne('Marque'), findsNothing);
        expect(ligne('Stock'), findsNothing);
        expect(ligne('Colisage'), findsNothing);
        expect(ligne('EAN'), findsNothing);
      });

      testWidgets('produit PEM inactif ou sans statut', (tester) async {
        await ouvrirFiche(tester, role, 'pem20000');
        expect(valeur(tester, 'Statut'), 'Inactif');
        expect(valeur(tester, 'Code article'), '20000');
      });
    });
  }

  testWidgets('produit PEM sans statut : pas de ligne « Statut »', (
    tester,
  ) async {
    await ouvrirFiche(tester, Role.promoteur, 'pem20021');
    expect(find.text('DEMELISS AIRBRUSH WONDER WOMAN'), findsOneWidget);
    expect(
      find.text('Produit disponible dans les visites PEM'),
      findsOneWidget,
    );
    expect(valeur(tester, 'Code article'), '20021');
    expect(ligne('Statut'), findsNothing);
  });

  testWidgets('kit sans prix : la fiche s’ouvre sans prix ni colisage', (
    tester,
  ) async {
    await ouvrirFiche(tester, Role.dir, 'kitKIT91265');
    expect(find.text('HP-KIT 0,50M GH'), findsOneWidget);
    expect(valeur(tester, 'Famille'), 'Kit');
    expect(valeur(tester, 'Code article'), 'KIT91265');
    expect(find.textContaining('HT (prix indicatif)'), findsNothing);
    expect(ligne('Marque'), findsNothing);
    expect(ligne('EAN'), findsNothing);
    expect(ligne('Colisage'), findsNothing);
    expect(ligne('Stock'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kit du catalogue avec prix (« Kit racines brun »)', (
    tester,
  ) async {
    await ouvrirFiche(tester, Role.cs, 'a5');
    expect(find.text('20,81 € HT (prix indicatif)'), findsOneWidget);
    expect(valeur(tester, 'Marque'), 'Jean Louis David');
    expect(valeur(tester, 'Colisage'), '12 unités par colis');
  });

  testWidgets('produit en promotion : ligne « Promotion : En cours »', (
    tester,
  ) async {
    const promo = Produit(
      id: 'x1',
      nom: 'Produit d’essai',
      marque: 'MB Milano',
      cat: 'MB Milano',
      famille: 'Rouges à lèvres',
      code: '900099',
      ean: '376123450099',
      prix: 9.9,
      stock: NiveauStock.stockBas,
      promo: '-20 %',
      pcb: 12,
    );
    await pumpEcran(
      tester,
      const Scaffold(body: FicheProduitContenu(produit: promo)),
    );
    expect(find.text('9,90 € HT (prix indicatif)'), findsOneWidget);
    expect(valeur(tester, 'Promotion'), 'En cours');
    expect(valeur(tester, 'Stock'), 'Stock bas');
  });

  testWidgets(
    'toutes les références du référentiel ont une fiche qui s’affiche',
    (tester) async {
      for (final p in tousProduits()) {
        await pumpEcran(
          tester,
          Scaffold(body: FicheProduitContenu(produit: p)),
        );
        expect(find.text(p.nom), findsOneWidget, reason: p.id);
        expect(tester.takeException(), isNull, reason: p.id);
      }
    },
  );

  testWidgets('identifiant inconnu : feuille vide, sans erreur', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      const Scaffold(body: FicheProduitSheet(produitId: 'inconnu')),
    );
    expect(find.byType(LigneFeuille), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
