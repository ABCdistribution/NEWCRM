import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/catalogue/fiche_produit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

Produit _produit(String ean) => Produit(
  id: 'p1',
  nom: 'Sérum éclat',
  marque: 'ABC',
  famille: 'Soin',
  code: '900008',
  ean: ean,
  prix: 12.5,
);

void main() {
  testWidgets('la fiche produit dessine le code-barres juste sous le titre', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      Scaffold(body: FicheProduitContenu(produit: _produit('3666085207382'))),
      role: Role.promoteur,
    );
    final titre = tester.getTopLeft(find.text('Sérum éclat')).dy;
    final barres = tester.getTopLeft(find.byType(CodeBarres)).dy;
    final prix = tester.getTopLeft(find.textContaining('prix indicatif')).dy;
    expect(barres, greaterThan(titre)); // sous le titre
    expect(barres, lessThan(prix)); // avant le prix et les caractéristiques
    expect(
      find.bySemanticsLabel('Code-barres EAN-13 3666085207382'),
      findsOneWidget,
    );
  });

  testWidgets('EAN de démonstration non valide : Code 128 du numéro exact', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      Scaffold(body: FicheProduitContenu(produit: _produit('376123450031'))),
      role: Role.promoteur,
    );
    expect(
      find.bySemanticsLabel('Code-barres Code 128 376123450031'),
      findsOneWidget,
    );
  });

  testWidgets('EAN vide : aucun code-barres', (tester) async {
    await pumpEcran(
      tester,
      Scaffold(body: FicheProduitContenu(produit: _produit(''))),
      role: Role.promoteur,
    );
    expect(find.byType(CodeBarres), findsNothing);
  });
}
