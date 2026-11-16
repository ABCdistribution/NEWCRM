import 'package:crm_app/core/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nom de la route du dessus (`RouteSettings.name` posé par `AppRoutes` : « magasin », « prospect », « visite »,
/// « cmd »…) ; nul pour une feuille ou un dialogue. Ne retire aucune route.
String? routeCourante(WidgetTester tester) {
  String? nom;
  tester.state<NavigatorState>(find.byType(Navigator).first).popUntil((r) {
    nom = r.settings.name;
    return true;
  });
  return nom;
}

/// Conteneur Riverpod de l'application montée (pour lire ou modifier le store depuis un test).
ProviderContainer conteneurMonte(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Le store partagé de l'application montée.
CrmNotifier storeMonte(WidgetTester tester) =>
    conteneurMonte(tester).read(crmProvider.notifier);

/// Laisse expirer un toast (2,6 s).
Future<void> laisserPasserToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

/// Fait défiler jusqu'au widget (la page de l'accueil dépasse l'écran de 780 dp), le touche, puis laisse finir les
/// animations.
Future<void> toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}
