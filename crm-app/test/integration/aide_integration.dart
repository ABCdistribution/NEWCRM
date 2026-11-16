import 'dart:async';

import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Outils des tests qui traversent plusieurs lots (application complète lancée par `lancerApp`).

/// Contexte de la coquille : sert à appeler `AppRoutes.xxx(ctx(tester), …)`.
BuildContext ctx(WidgetTester tester) =>
    tester.element(find.byType(ShellScreen, skipOffstage: false));

ProviderContainer conteneur(WidgetTester tester) =>
    ProviderScope.containerOf(ctx(tester));

/// Le store partagé de l'application lancée.
CrmEtat store(WidgetTester tester) => conteneur(tester).read(crmProvider);

/// Onglet courant de la coquille.
OngletApp ongletCourant(WidgetTester tester) =>
    conteneur(tester).read(ongletProvider);

/// Entrée de la barre de navigation par son libellé.
Finder nav(String libelle) =>
    find.descendant(of: find.byType(AppNavBar), matching: find.text(libelle));

/// Ouvre l'écran voulu par `AppRoutes` sans attendre sa fermeture.
Future<void> ouvrir(WidgetTester tester, Future<void> Function() action) async {
  unawaited(action());
  await tester.pumpAndSettle();
}

/// Ferme le dialogue du kilométrage de départ (appui sur le voile) et vérifie qu'il était ouvert.
Future<void> fermerKilometrage(WidgetTester tester) async {
  expect(find.text('Kilométrage de départ'), findsOneWidget);
  await tester.tapAt(const Offset(195, 20));
  await tester.pumpAndSettle();
  expect(find.text('Kilométrage de départ'), findsNothing);
}
