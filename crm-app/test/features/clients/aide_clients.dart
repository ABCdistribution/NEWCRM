import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/features/clients/widgets/carte_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Noms des écrans empilés posés par `AppRoutes` (`RouteSettings.name` : « magasin », « visite », « cmd »…).
class RoutesPoussees extends NavigatorObserver {
  final List<String> noms = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final nom = route.settings.name;
    if (nom != null) noms.add(nom);
  }
}

/// Comme `pumpEcran`, avec un observateur qui note les écrans empilés.
Future<RoutesPoussees> pumpEcranObserve(
  WidgetTester tester,
  Widget ecran, {
  required Role role,
}) async {
  utiliserTelephone(tester);
  final routes = RoutesPoussees();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [roleProvider.overrideWith(() => RoleNotifier(role))],
      child: MaterialApp(
        theme: AppTheme.pour(role.univers),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorObservers: [routes],
        home: ecran,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return routes;
}

/// Conteneur Riverpod de l'application montée (pour lire le store ou les filtres).
ProviderContainer conteneurDe(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Noms des clients affichés dans la liste, dans l'ordre.
List<String> nomsClients(WidgetTester tester) => [
  for (final c in tester.widgetList<CarteClient>(find.byType(CarteClient)))
    c.magasin.nom,
];

/// Ferme les toasts en attente (le toast dure 2,6 s).
Future<void> laisserPasserToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));
