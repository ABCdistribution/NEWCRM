import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Contexte de la coquille de l'application lancée par `lancerApp` : sert à appeler `AppRoutes.xxx(ctx(), …)`.
BuildContext contexteCoquille(WidgetTester tester) =>
    tester.element(find.byType(ShellScreen, skipOffstage: false));

/// Conteneur Riverpod de l'application lancée.
ProviderContainer conteneurApp(WidgetTester tester) =>
    ProviderScope.containerOf(contexteCoquille(tester));

/// Le store partagé de l'application lancée.
CrmEtat storeApp(WidgetTester tester) => conteneurApp(tester).read(crmProvider);

/// Onglet de la barre de navigation par son libellé.
Finder ongletNav(String libelle) =>
    find.descendant(of: find.byType(AppNavBar), matching: find.text(libelle));

/// Laisse passer les messages éphémères (2,6 s) et les animations.
Future<void> attendreToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// Lance l'application avec `role`, puis démarre une visite chez `magasinId` ; renvoie l'id du brouillon.
/// Le dialogue de kilométrage de départ (promoteur) est laissé ouvert.
Future<String> demarrerVisiteChez(
  WidgetTester tester,
  Role role,
  String magasinId,
) async {
  await lancerApp(tester, role);
  AppRoutes.demarrerVisite(contexteCoquille(tester), magasinId);
  await tester.pumpAndSettle();
  return storeApp(tester).visites.first.id;
}

/// Horodate toutes les étapes DPH d'un brouillon et renseigne les autres rubriques, pour pouvoir le valider.
void completerVisite(WidgetTester tester, String id) {
  conteneurApp(tester)
      .read(crmProvider.notifier)
      .majVisite(
        id,
        (v) => v.copyWith(
          chrono: {for (final e in EtapeDph.values) e: '04/11/2026 14h30'},
          kits: const ['COSMIA-01'],
          promosConformes: true,
          bilanValide: true,
          pem: const VisitePem(realisee: true),
        ),
      );
}

/// Fait défiler jusqu'à l'élément puis le touche (la page de la visite dépasse la hauteur de l'écran).
Future<void> toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}
