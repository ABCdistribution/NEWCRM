import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/equipe/data/equipe_demo.dart';
import 'package:crm_app/features/equipe/filtres_semaines_sheet.dart';
import 'package:crm_app/features/equipe/state/equipe_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Feuille « Filtrer les semaines » (maquette : modale `cs-filtres` l.1877-1882, `FILTRES_SEM` l.836).
Future<ProviderContainer> _ouvrir(WidgetTester tester, String csId) async {
  await pumpEcran(
    tester,
    const Scaffold(body: SizedBox.expand()),
    role: Role.dir,
  );
  AppRoutes.filtresSemainesChefSecteur(
    tester.element(find.byType(Scaffold)),
    csId,
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

Finder _option(String libelle) => find.descendant(
  of: find.byType(FiltresSemainesSheet),
  matching: find.text(libelle),
);

void main() {
  testWidgets('les cinq choix et le nombre de semaines retenues', (
    tester,
  ) async {
    await _ouvrir(tester, 'n');
    expect(find.text('Filtrer les semaines'), findsOneWidget);
    for (final f in FiltreSemaines.values) {
      expect(_option(f.libelle), findsOneWidget, reason: f.libelle);
    }
    expect(find.byType(OptionRadio), findsNWidgets(5));
    expect(find.text('Réinitialiser'), findsOneWidget);
    expect(find.text('Voir 7 semaines'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chaque choix met à jour l’état et le bouton du bas', (
    tester,
  ) async {
    final c = await _ouvrir(tester, 'n');
    final attendus = {
      'Semaine en cours': ('Voir 1 semaine', FiltreSemaines.enCours),
      'Semaines validées': ('Voir 6 semaines', FiltreSemaines.validees),
      'Avec des écarts': ('Voir 5 semaines', FiltreSemaines.ecarts),
      'Prévision non renseignée': ('Voir 1 semaine', FiltreSemaines.sans),
      'Toutes les semaines': ('Voir 7 semaines', FiltreSemaines.toutes),
    };
    for (final e in attendus.entries) {
      await tester.tap(_option(e.key));
      await tester.pumpAndSettle();
      expect(c.read(filtreSemainesProvider), e.value.$2, reason: e.key);
      expect(find.text(e.value.$1), findsOneWidget, reason: e.key);
      final radios = tester
          .widgetList<Radio20>(find.byType(Radio20))
          .where((r) => r.selectionne);
      expect(radios, hasLength(1));
    }
  });

  testWidgets('le décompte dépend du chef de secteur', (tester) async {
    await _ouvrir(tester, 's');
    await tester.tap(_option('Prévision non renseignée'));
    await tester.pumpAndSettle();
    expect(find.text('Voir 7 semaines'), findsOneWidget);
    await tester.tap(_option('Avec des écarts'));
    await tester.pumpAndSettle();
    expect(find.text('Voir 3 semaines'), findsOneWidget);
  });

  testWidgets(
    '« Réinitialiser » revient à toutes les semaines et laisse la feuille ouverte',
    (tester) async {
      final c = await _ouvrir(tester, 'k');
      await tester.tap(_option('Avec des écarts'));
      await tester.pumpAndSettle();
      expect(find.text('Voir 3 semaines'), findsOneWidget);
      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();
      expect(c.read(filtreSemainesProvider), FiltreSemaines.toutes);
      expect(find.byType(FiltresSemainesSheet), findsOneWidget);
      expect(find.text('Voir 7 semaines'), findsOneWidget);
    },
  );

  testWidgets('« Voir N semaines » ferme la feuille et garde le filtre', (
    tester,
  ) async {
    final c = await _ouvrir(tester, 'n');
    await tester.tap(_option('Semaines validées'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir 6 semaines'));
    await tester.pumpAndSettle();
    expect(find.byType(FiltresSemainesSheet), findsNothing);
    expect(c.read(filtreSemainesProvider), FiltreSemaines.validees);
  });
}
