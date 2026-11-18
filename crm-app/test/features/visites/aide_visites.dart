import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
/// `overrides` : providers à remplacer (questionnaire, raisons d'absence, promotions).
Future<String> demarrerVisiteChez(
  WidgetTester tester,
  Role role,
  String magasinId, {
  List<Override> overrides = const [],
}) async {
  await lancerApp(tester, role, overrides: overrides);
  AppRoutes.demarrerVisite(contexteCoquille(tester), magasinId);
  await tester.pumpAndSettle();
  return storeApp(tester).visites.first.id;
}

/// Horodate toutes les étapes d'un brouillon et renseigne les rubriques exigées (photos, réponse « commande à mettre
/// en rayon », kits), pour pouvoir le valider.
void completerVisite(WidgetTester tester, String id) {
  conteneurApp(tester)
      .read(crmProvider.notifier)
      .majVisite(
        id,
        (v) => v.copyWith(
          chrono: {for (final e in EtapeDph.values) e: '04/11/2026 14h30'},
          photos: const {
            EtapeDph.arrivee: 1,
            EtapeDph.rayonArrivee: 1,
            EtapeDph.rayonFin: 1,
          },
          commandeEnRayon: false,
          kits: const ['COSMIA-01'],
        ),
      );
}

/// Parcourt le brouillon affiché avec « Suivant » jusqu'à la dernière étape, puis touche « ✓ Terminer la visite ».
/// Chaque étape doit être valide (voir `completerVisite`), sinon « Suivant » reste sur place et le test échoue.
Future<void> terminerLeParcours(WidgetTester tester) async {
  for (var i = 0; i < EtapeDph.parcours.length; i++) {
    final suivant = find.text('Suivant ›');
    if (suivant.evaluate().isEmpty) break;
    await tester.tap(suivant);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('✓ Terminer la visite'));
  await tester.pumpAndSettle();
}

/// Fait défiler jusqu'à l'élément puis le touche (la page de la visite dépasse la hauteur de l'écran).
Future<void> toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}
