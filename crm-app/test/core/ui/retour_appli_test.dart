import 'package:crm_app/core/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void etat(WidgetTester tester, AppLifecycleState e) =>
      tester.binding.handleAppLifecycleStateChanged(e);

  testWidgets('sans cycle de vie connu, le retour n\'est pas détectable', (
    tester,
  ) async {
    expect(WidgetsBinding.instance.lifecycleState, isNull);
    expect(const SurveillantCycleDeVie().surveiller(), isNull);
  });

  group('observateur de cycle de vie', () {
    testWidgets('aboutit au retour au premier plan, après être parti', (
      tester,
    ) async {
      etat(tester, AppLifecycleState.resumed);
      final attente = const SurveillantCycleDeVie().surveiller()!;
      var fini = false;
      attente.retour.then((_) => fini = true);

      // Un `resumed` sans être parti ne compte pas.
      etat(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(fini, isFalse);

      etat(tester, AppLifecycleState.paused);
      await tester.pump();
      expect(fini, isFalse);

      etat(tester, AppLifecycleState.resumed);
      expect(await attente.retour, isTrue);
    });

    testWidgets('inactive suffit pour être parti', (tester) async {
      etat(tester, AppLifecycleState.resumed);
      final attente =
          const SurveillantCycleDeVie().surveiller()! as ObservateurRetour;
      attente.didChangeAppLifecycleState(AppLifecycleState.inactive);
      attente.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(await attente.retour, isTrue);
    });

    testWidgets('délai de sécurité : faux, l\'observateur est retiré', (
      tester,
    ) async {
      etat(tester, AppLifecycleState.resumed);
      final attente = const SurveillantCycleDeVie(
        delai: Duration(minutes: 30),
      ).surveiller()!;
      var fini = false;
      attente.retour.then((_) => fini = true);
      await tester.pump(const Duration(minutes: 29));
      expect(fini, isFalse);
      await tester.pump(const Duration(minutes: 2));
      expect(await attente.retour, isFalse);
      // Retiré : un retour tardif ne change rien et n'échoue pas.
      etat(tester, AppLifecycleState.paused);
      etat(tester, AppLifecycleState.resumed);
    });

    testWidgets('annuler retire l\'observateur et libère le minuteur', (
      tester,
    ) async {
      etat(tester, AppLifecycleState.resumed);
      final attente = const SurveillantCycleDeVie().surveiller()!;
      attente.annuler();
      expect(await attente.retour, isFalse);
    });
  });
}
