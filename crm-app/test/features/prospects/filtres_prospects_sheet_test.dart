import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/prospects_screen.dart';
import 'package:crm_app/features/prospects/state/prospects_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Feuille « Filtres » du directeur : maquette `pv-filtres` l.1858-1864 et actions `pv-cs`, `pv-statut`, `pv-reset`.
Future<void> _ouvrirFeuille(WidgetTester tester) async {
  await pumpEcran(tester, const ProspectsScreen(), role: Role.dir);
  await tester.tap(find.text('👥 Tous les prospects'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BoutonFiltre));
  await tester.pumpAndSettle();
}

ProviderContainer _store(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ProspectsScreen)));

Finder _dansFeuille(String texte) =>
    find.descendant(of: find.byType(FeuilleBase), matching: find.text(texte));

void main() {
  testWidgets('chefs de secteur avec leur nombre, statuts et boutons', (
    tester,
  ) async {
    await _ouvrirFeuille(tester);
    expect(_dansFeuille('Filtres'), findsOneWidget);
    expect(_dansFeuille('CHEFS DE SECTEUR'), findsOneWidget);
    expect(_dansFeuille('Karim B. (11)'), findsOneWidget);
    expect(_dansFeuille('Nadia H. (12)'), findsOneWidget);
    expect(find.byType(Interrupteur), findsNWidgets(2));
    expect(_dansFeuille('STATUT'), findsOneWidget);
    for (final s in [
      'Tous les statuts',
      'À contacter',
      'RDV pris',
      'En négo',
      'Référencé',
    ]) {
      expect(_dansFeuille(s), findsOneWidget, reason: s);
    }
    expect(find.byType(OptionRadio), findsNWidgets(5));
    expect(_dansFeuille('Réinitialiser'), findsOneWidget);
    expect(_dansFeuille('Voir 23 prospects'), findsOneWidget);
    // « Tous les statuts » est coché au départ.
    final radios = tester
        .widgetList<OptionRadio>(find.byType(OptionRadio))
        .map((o) => o.selectionne)
        .toList();
    expect(radios, [true, false, false, false, false]);
  });

  testWidgets(
    'un interrupteur retient un chef de secteur et met à jour le total',
    (tester) async {
      await _ouvrirFeuille(tester);
      await tester.tap(find.byType(Interrupteur).first); // Karim B.
      await tester.pumpAndSettle();
      expect(_store(tester).read(chefsSecteurRetenusProvider), ['Karim B.']);
      expect(_dansFeuille('Voir 11 prospects'), findsOneWidget);
      expect(
        tester
            .widgetList<Interrupteur>(find.byType(Interrupteur))
            .map((i) => i.valeur),
        [true, false],
      );
      // Les deux : toute la région ; un second toucher sur le premier le retire.
      await tester.tap(find.byType(Interrupteur).last);
      await tester.pumpAndSettle();
      expect(_dansFeuille('Voir 23 prospects'), findsOneWidget);
      await tester.tap(find.byType(Interrupteur).first);
      await tester.pumpAndSettle();
      expect(_store(tester).read(chefsSecteurRetenusProvider), ['Nadia H.']);
      expect(_dansFeuille('Voir 12 prospects'), findsOneWidget);
    },
  );

  testWidgets(
    'le statut s’ajoute au chef de secteur ; « Voir 1 prospect » au singulier',
    (tester) async {
      await _ouvrirFeuille(tester);
      await tester.tap(_dansFeuille('En négo'));
      await tester.pumpAndSettle();
      expect(_store(tester).read(filtreGroupeProvider), GroupeProspect.enNego);
      expect(_dansFeuille('Voir 8 prospects'), findsOneWidget);
      await tester.tap(find.byType(Interrupteur).first); // Karim B.
      await tester.pumpAndSettle();
      expect(_dansFeuille('Voir 4 prospects'), findsOneWidget);
      await tester.tap(_dansFeuille('Référencé'));
      await tester.pumpAndSettle();
      expect(
        _store(tester).read(filtreGroupeProvider),
        GroupeProspect.reference,
      );
      expect(_dansFeuille('Voir 1 prospect'), findsOneWidget);
      // Un seul statut est coché à la fois.
      final radios = tester
          .widgetList<OptionRadio>(find.byType(OptionRadio))
          .map((o) => o.selectionne)
          .toList();
      expect(radios, [false, false, false, false, true]);
      await tester.tap(_dansFeuille('Tous les statuts'));
      await tester.pumpAndSettle();
      expect(_store(tester).read(filtreGroupeProvider), isNull);
    },
  );

  testWidgets('« Réinitialiser » efface chefs de secteur et statut', (
    tester,
  ) async {
    await _ouvrirFeuille(tester);
    await tester.tap(find.byType(Interrupteur).first);
    await tester.tap(_dansFeuille('RDV pris'));
    await tester.pumpAndSettle();
    await tester.tap(_dansFeuille('Réinitialiser'));
    await tester.pumpAndSettle();
    expect(_store(tester).read(chefsSecteurRetenusProvider), isEmpty);
    expect(_store(tester).read(filtreGroupeProvider), isNull);
    expect(_dansFeuille('Voir 23 prospects'), findsOneWidget);
    expect(
      find.byType(FeuilleBase),
      findsOneWidget,
    ); // la feuille reste ouverte
  });

  testWidgets('« Voir N prospects » ferme la feuille et la page suit les choix', (
    tester,
  ) async {
    await _ouvrirFeuille(tester);
    await tester.tap(find.byType(Interrupteur).first); // Karim B.
    await tester.tap(_dansFeuille('En négo'));
    await tester.pumpAndSettle();
    await tester.tap(_dansFeuille('Voir 4 prospects'));
    await tester.pumpAndSettle();
    expect(find.byType(FeuilleBase), findsNothing);
    expect(find.text('Karim B. · En négo'), findsOneWidget);
    // Karim B. : 4 prospects en négociation, dont E.Leclerc – Caen (140) et Carrefour HM – Mondeville (150).
    expect(find.text('Carrefour HM – Mondeville'), findsOneWidget);
    expect(
      find.text('Super U – Versailles'),
      findsNothing,
    ); // secteur de Nadia H.
    expect(
      find.text('11 points de vente · potentiel 995 k€/an'),
      findsOneWidget,
    );
  });
}
