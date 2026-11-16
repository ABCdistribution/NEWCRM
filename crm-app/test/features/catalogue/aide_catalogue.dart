import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Texte du message du bouton scan (`bientot-scan`, maquette l.1494).
const String messageScan =
    "Scan du code-barres : bientôt disponible. Saisissez l'EAN dans la recherche.";

/// Lance l'application avec `role`, puis ouvre le menu « + » et l'entrée `onglet` (Catalogue ou News), comme un
/// utilisateur.
Future<void> ouvrirOngletPlus(
  WidgetTester tester,
  Role role,
  OngletApp onglet,
) async {
  await lancerApp(tester, role);
  await allerOngletPlus(tester, onglet);
}

/// Ouvre le menu « + » de l'application déjà lancée puis l'entrée `onglet`.
Future<void> allerOngletPlus(WidgetTester tester, OngletApp onglet) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AppNavBar),
      matching: find.bySemanticsLabel('Plus'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(MenuPlus),
      matching: find.text(onglet.libelle),
    ),
  );
  await tester.pumpAndSettle();
}

/// Conteneur Riverpod de l'application lancée.
ProviderContainer conteneurApp(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ShellScreen)));

/// Conteneur Riverpod d'un écran monté seul avec `pumpEcran` (le premier widget de type `T` trouvé).
ProviderContainer conteneurEcran<T extends Widget>(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(T)));

/// Amène un élément dans la zone visible de son défilement, puis l'appuie.
Future<void> toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

/// Appuie sur le bouton filtre (loupe de la barre de recherche).
Future<void> toucherFiltres(WidgetTester tester) async {
  await tester.tap(find.byType(BoutonFiltre));
  await tester.pumpAndSettle();
}

/// Laisse passer la durée d'un toast (2,6 s) pour ne laisser aucun minuteur en attente.
Future<void> laisserPasserToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
}
