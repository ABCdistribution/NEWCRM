import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Parcours de bout en bout dans la coquille (barre de navigation, menu « + », feuilles) : planning et rapports.

Finder dansNav(String libelle) =>
    find.descendant(of: find.byType(AppNavBar), matching: find.text(libelle));

final boutonPlus = find.descendant(
  of: find.byType(AppNavBar),
  matching: find.bySemanticsLabel('Plus'),
);

ProviderContainer conteneur(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ShellScreen, skipOffstage: false)),
);

Future<void> allerAuPlanning(WidgetTester tester, Role role) async {
  await lancerApp(tester, role);
  await tester.tap(dansNav('Planning'));
  await tester.pumpAndSettle();
}

Future<void> ouvrirMesRapports(WidgetTester tester) async {
  await tester.tap(boutonPlus);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(MenuPlus),
      matching: find.text('Mes rapports'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('promoteur : onglet Planning en lecture seule', (tester) async {
    await allerAuPlanning(tester, Role.promoteur);
    expect(find.text('Mon planning'), findsOneWidget);
    expect(find.text('Planning de la semaine'), findsOneWidget);
    expect(find.byType(AppFab), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chef de secteur : « + », ajout d’une ligne, retour au planning',
    (tester) async {
      await allerAuPlanning(tester, Role.cs);
      expect(find.text('Rapport en cours'), findsOneWidget);
      expect(find.text('2 RDV'), findsOneWidget);

      await tester.tap(find.byType(AppFab));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau RDV'), findsOneWidget);
      await tester.tap(find.text('Ajouter la ligne'));
      await tester.pump();
      expect(find.text('Ligne ajoutée au planning.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Nouveau RDV'), findsNothing);
      expect(find.text('Mon planning'), findsOneWidget);
      expect(find.text('3 RDV'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(conteneur(tester).read(ongletProvider), OngletApp.planning);
    },
  );

  testWidgets('le jour choisi dans le planning est celui de l’accueil', (
    tester,
  ) async {
    await allerAuPlanning(tester, Role.cs);
    await tester.tap(find.text('Jeu'));
    await tester.pumpAndSettle();
    expect(conteneur(tester).read(jourPlanningProvider), 3);
  });

  testWidgets(
    'directeur : Mes rapports par le menu « + », détail puis planning',
    (tester) async {
      await lancerApp(tester, Role.dir);
      await ouvrirMesRapports(tester);
      expect(find.text('Mes rapports'), findsWidgets);
      expect(find.text('Semaine 45 · en cours'), findsOneWidget);

      await tester.tap(find.text('Semaine 43'));
      await tester.pumpAndSettle();
      expect(find.text('Semaine 43 · 19 – 23 octobre'), findsOneWidget);
      await tester.tapAt(const Offset(195, 20)); // le voile ferme la feuille
      await tester.pumpAndSettle();
      expect(find.text('Semaine 43 · 19 – 23 octobre'), findsNothing);

      await tester.tap(find.text('Semaine 45 · en cours'));
      await tester.pumpAndSettle();
      expect(find.text('Mon planning'), findsOneWidget);
      expect(
        find.text('Prévision figée le lun. 2 nov. (8 lignes).'),
        findsOneWidget,
      );
    },
  );

  testWidgets('chef de secteur : Mes rapports est dans le menu « + »', (
    tester,
  ) async {
    await lancerApp(tester, Role.cs);
    await ouvrirMesRapports(tester);
    expect(find.text('Rapports précédents'), findsOneWidget);
    expect(find.text('Semaine 44'), findsOneWidget);
  });

  testWidgets('planifier depuis une fiche : retour sur le planning', (
    tester,
  ) async {
    await lancerApp(tester, Role.cs);
    final ctx = tester.element(find.byType(ShellScreen));
    AppRoutes.formulaireRdv(
      ctx,
      cible: CiblePlanning.client,
      ref: 'm4',
      depuisFiche: true,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Planifier · Carrefour – Ivry-sur-Seine · Classe F'),
      findsOneWidget,
    );
    await tester.tap(find.text('Ajouter la ligne'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Mon planning'), findsOneWidget);
    expect(conteneur(tester).read(crmProvider).etapes.last.ref, 'm4');
  });
}
