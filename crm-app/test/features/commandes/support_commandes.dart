import 'package:crm_app/core/ui/ui.dart';
import 'package:flutter_test/flutter_test.dart';

// `chargerInter` (police Inter des tests) est dans le support commun.
export '../../support/app_test_support.dart' show chargerInter;

/// Les cartes de livraison affichées, dans l'ordre.
List<String> idsCartes(WidgetTester tester) => [
  for (final c in tester.widgetList<CarteLivraison>(
    find.byType(CarteLivraison),
  ))
    c.commande.id,
];

/// Un texte écrit dans un `Text.rich` (un libellé suivi d'un détail gris, par exemple).
Finder texteRiche(String texte) =>
    find.textContaining(texte, findRichText: true);

/// Cherche un texte à l'intérieur de la feuille ouverte (pour ne pas le confondre avec celui de la page dessous).
Finder dansFeuille(Finder f) =>
    find.descendant(of: find.byType(FeuilleBase), matching: f);

/// Fait défiler jusqu'à l'élément (page ou feuille), le touche, puis laisse finir les animations.
Future<void> toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pump();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}
