import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/accueil/accueil_encadrement.dart';
import 'package:crm_app/features/accueil/accueil_promoteur.dart';
import 'package:crm_app/features/accueil/accueil_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// `AccueilScreen` choisit la page selon le rôle (une page = un écran, affichage selon le profil) :
/// `salesAccueil` pour le promoteur, `pageAccueil` pour le chef de secteur et le directeur.
void main() {
  testWidgets('promoteur : accueil du promoteur, univers bleu', (tester) async {
    await pumpEcran(tester, const AccueilScreen(), role: Role.promoteur);
    expect(find.byType(AccueilPromoteur), findsOneWidget);
    expect(find.byType(AccueilEncadrement), findsNothing);
    expect(find.text('Bonjour Julien'), findsOneWidget);
    expect(
      tester.element(find.byType(AccueilScreen)).univers.univers,
      Univers.sales,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chef de secteur : accueil de l’encadrement, univers violet', (
    tester,
  ) async {
    await pumpEcran(tester, const AccueilScreen(), role: Role.cs);
    expect(find.byType(AccueilEncadrement), findsOneWidget);
    expect(find.byType(AccueilPromoteur), findsNothing);
    expect(find.text('Bonjour Nadia'), findsOneWidget);
    expect(
      tester.element(find.byType(AccueilScreen)).univers.univers,
      Univers.pilot,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('directeur : accueil de l’encadrement, univers violet', (
    tester,
  ) async {
    await pumpEcran(tester, const AccueilScreen(), role: Role.dir);
    expect(find.byType(AccueilEncadrement), findsOneWidget);
    expect(find.byType(AccueilPromoteur), findsNothing);
    expect(find.text('Bonjour Cindy'), findsOneWidget);
    expect(
      tester.element(find.byType(AccueilScreen)).univers.univers,
      Univers.pilot,
    );
    expect(tester.takeException(), isNull);
  });

  for (final role in Role.values) {
    testWidgets('${role.profil.libelle} : l’accueil s’affiche sans erreur', (
      tester,
    ) async {
      await pumpEcran(tester, const AccueilScreen(), role: role);
      expect(find.text('Bonjour ${role.profil.prenom}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('le bandeau Bonjour du socle est présent pour chaque rôle', (
    tester,
  ) async {
    for (final role in Role.values) {
      await pumpEcran(tester, const AccueilScreen(), role: role);
      expect(find.byType(BandeauBonjour), findsOneWidget);
      expect(find.byType(Cloche), findsOneWidget);
    }
  });
}
