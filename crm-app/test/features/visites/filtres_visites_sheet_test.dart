import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/visites/filtres_visites_sheet.dart';
import 'package:crm_app/features/visites/state/filtres_visites.dart';
import 'package:crm_app/features/visites/visites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Monte l'onglet « Visites » puis ouvre la feuille par le bouton de filtres.
Future<void> ouvrirFeuille(WidgetTester tester, Role role) async {
  await pumpEcran(tester, const VisitesScreen(), role: role);
  await tester.tap(find.byType(BoutonFiltre));
  await tester.pumpAndSettle();
}

FiltresVisites filtres(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(VisitesScreen)),
).read(filtresVisitesProvider);

void main() {
  group('Feuille « Filtres » des visites (vfiltres l.1388-1396)', () {
    testWidgets('contenu et valeurs par défaut du promoteur', (tester) async {
      await ouvrirFeuille(tester, Role.promoteur);
      expect(find.byType(FiltresVisitesSheet), findsOneWidget);
      expect(find.text('Filtres'), findsOneWidget);
      for (final t in ['AFFICHER', 'ÉTAT', 'PÉRIODE']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (final t in [
        'Mes visites',
        'Toutes les visites (sur vos clients)',
        'Tous les états',
        'Brouillon',
        'À envoyer',
        'Envoyée',
        'Toutes les dates',
        "Aujourd'hui",
        '7 derniers jours',
        'Réinitialiser',
        'Voir 4 visites',
      ]) {
        // les pastilles de la liste derrière la feuille portent les mêmes libellés d'état
        expect(
          find.descendant(
            of: find.byType(FiltresVisitesSheet),
            matching: find.text(t),
          ),
          findsOneWidget,
          reason: t,
        );
      }
      // une option choisie par groupe : Mes visites, Tous les états, Toutes les dates
      expect(
        tester
            .widgetList<Radio20>(find.byType(Radio20))
            .where((r) => r.selectionne)
            .length,
        3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('la portée suit le rôle', (tester) async {
      await ouvrirFeuille(tester, Role.cs);
      expect(
        find.text('Toutes les visites (de votre secteur)'),
        findsOneWidget,
      );
      expect(find.text('Voir 2 visites'), findsOneWidget);
    });

    testWidgets('la portée du directeur', (tester) async {
      await ouvrirFeuille(tester, Role.dir);
      expect(find.text('Toutes les visites (de votre région)'), findsOneWidget);
    });

    testWidgets(
      '« Toutes les visites » met à jour le compte et la liste derrière',
      (tester) async {
        await ouvrirFeuille(tester, Role.promoteur);
        await tester.tap(find.text('Toutes les visites (sur vos clients)'));
        await tester.pumpAndSettle();
        expect(filtres(tester).portee, PorteeVisites.toutes);
        expect(find.text('Voir 5 visites'), findsOneWidget);
        expect(
          find.text('Toutes les visites sur vos clients · 5 résultats'),
          findsOneWidget,
        );
        expect(
          tester.widget<BoutonFiltre>(find.byType(BoutonFiltre)).nbFiltres,
          1,
        );
      },
    );

    testWidgets('l’état et la période se choisissent', (tester) async {
      await ouvrirFeuille(tester, Role.promoteur);
      await tester.tap(find.text('À envoyer'));
      await tester.pumpAndSettle();
      expect(filtres(tester).etat, EtatVisite.terminee);
      expect(find.text('Voir 0 visite'), findsOneWidget);
      await tester.tap(find.text('Envoyée'));
      await tester.pumpAndSettle();
      expect(filtres(tester).etat, EtatVisite.envoyee);
      expect(find.text('Voir 4 visites'), findsOneWidget);
      await tester.tap(find.text("Aujourd'hui"));
      await tester.pumpAndSettle();
      expect(filtres(tester).periode, PeriodeVisites.jour);
      expect(find.text('Voir 1 visite'), findsOneWidget);
      await tester.tap(find.text('7 derniers jours'));
      await tester.pumpAndSettle();
      expect(filtres(tester).periode, PeriodeVisites.semaine);
      expect(find.text('Voir 2 visites'), findsOneWidget);
      await tester.tap(find.text('Tous les états'));
      await tester.pumpAndSettle();
      expect(filtres(tester).etat, isNull);
      expect(
        tester.widget<BoutonFiltre>(find.byType(BoutonFiltre)).nbFiltres,
        1,
      );
    });

    testWidgets('« Réinitialiser » garde la recherche', (tester) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
      await tester.enterText(find.byType(TextFormField), 'ivry');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BoutonFiltre));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toutes les visites (sur vos clients)'));
      await tester.tap(find.text('Brouillon'));
      await tester.pumpAndSettle();
      expect(filtres(tester).nbActifs, 2);
      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();
      final f = filtres(tester);
      expect(f.portee, PorteeVisites.mes);
      expect(f.etat, isNull);
      expect(f.periode, PeriodeVisites.toutes);
      expect(f.q, 'ivry');
      expect(find.text('Voir 2 visites'), findsOneWidget);
    });

    testWidgets('« Voir N visites » ferme la feuille', (tester) async {
      await ouvrirFeuille(tester, Role.promoteur);
      await tester.tap(find.text('Voir 4 visites'));
      await tester.pumpAndSettle();
      expect(find.byType(FiltresVisitesSheet), findsNothing);
      expect(find.text('Mes visites · 4 résultats'), findsOneWidget);
    });
  });
}
