import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/planning/mes_rapports_screen.dart';
import 'package:crm_app/features/planning/state/planning_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Onglet « Mes rapports » : maquette `pageRapportsMes` l.1054-1068 et `S.rapports` l.487-492.

ProviderContainer conteneur(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MesRapportsScreen, skipOffstage: false)),
);

void main() {
  for (final role in [Role.cs, Role.dir]) {
    group(role.profil.libelle, () {
      testWidgets('semaine en cours et rapports précédents', (tester) async {
        await pumpEcran(tester, const MesRapportsScreen(), role: role);
        expect(find.text('Mes rapports'), findsOneWidget);
        expect(find.text('📄'), findsOneWidget);
        expect(find.text('Semaine 45 · en cours'), findsOneWidget);
        expect(
          find.text(
            '${role == Role.cs ? 4 : 8} lignes prévues · validation automatique lundi à 4 h',
          ),
          findsOneWidget,
        );
        expect(find.text('Auto'), findsOneWidget);
        expect(find.text('Rapports précédents'), findsOneWidget);
        expect(find.text('2026'), findsOneWidget);
        for (final n in [44, 43, 42, 41]) {
          expect(find.text('Semaine $n'), findsOneWidget);
        }
        expect(find.text('Validé auto'), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('chiffres, pieds et écarts de chaque rapport', (tester) async {
    await pumpEcran(tester, const MesRapportsScreen(), role: Role.cs);
    // Semaine 44.
    expect(find.text('26 – 30 octobre'), findsOneWidget);
    expect(find.text('14 visites'), findsOneWidget);
    expect(find.text('93 % du prévu'), findsOneWidget);
    expect(find.text('4 RDV obtenus'), findsOneWidget);
    expect(
      find.text('Validé automatiquement le lun. 2 nov. à 04:00'),
      findsOneWidget,
    );
    expect(
      find.text('Écarts avec la prévision : +1 ajoutée · 1 retirée'),
      findsOneWidget,
    );
    // Semaine 43.
    expect(find.text('19 – 23 octobre'), findsOneWidget);
    expect(find.text('12 visites'), findsOneWidget);
    expect(find.text('86 % du prévu'), findsOneWidget);
    expect(find.text('2 RDV obtenus'), findsOneWidget);
    expect(
      find.text('Écarts avec la prévision : 2 retirées · 1 déplacée'),
      findsOneWidget,
    );
    // Semaine 42 : aucun écart.
    expect(find.text('12 – 16 octobre'), findsOneWidget);
    expect(find.text('15 visites'), findsOneWidget);
    expect(find.text('100 % du prévu'), findsOneWidget);
    expect(find.text('3 RDV obtenus'), findsOneWidget);
    expect(find.text('Écarts avec la prévision : aucun écart'), findsOneWidget);
    // Semaine 41.
    expect(find.text('5 – 9 octobre'), findsOneWidget);
    expect(find.text('11 visites'), findsOneWidget);
    expect(find.text('85 % du prévu'), findsOneWidget);
    expect(find.text('1 RDV obtenus'), findsOneWidget);
    expect(
      find.text('Écarts avec la prévision : 2 non réalisées'),
      findsOneWidget,
    );
  });

  testWidgets('toucher un rapport ouvre son détail', (tester) async {
    await pumpEcran(tester, const MesRapportsScreen(), role: Role.cs);
    await tester.tap(find.text('Semaine 44'));
    await tester.pumpAndSettle();
    expect(find.text('Semaine 44 · 26 – 30 octobre'), findsOneWidget);
    expect(find.text('Prévu 15 · Réalisé 14 (93 %)'), findsOneWidget);
  });

  testWidgets('la carte « en cours » ramène au planning', (tester) async {
    await pumpEcran(tester, const MesRapportsScreen(), role: Role.cs);
    await tester.tap(find.text('Semaine 45 · en cours'));
    await tester.pumpAndSettle();
    expect(conteneur(tester).read(ongletProvider), OngletApp.planning);
  });

  group('selon la phase de la semaine', () {
    testWidgets('prévision à saisir : badge « Prévision »', (tester) async {
      await pumpEcran(tester, const MesRapportsScreen(), role: Role.cs);
      conteneur(
        tester,
      ).read(planningProvider.notifier).choisirPhase(PhasePlanning.prevision);
      await tester.pumpAndSettle();
      expect(find.text('Prévision à saisir'), findsOneWidget);
      expect(find.text('Prévision'), findsOneWidget);
      expect(find.text('Auto'), findsNothing);
    });

    testWidgets('prévision enregistrée : nombre de lignes prévues', (
      tester,
    ) async {
      await pumpEcran(tester, const MesRapportsScreen(), role: Role.cs);
      final c = conteneur(tester);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.prevision);
      c
          .read(planningProvider.notifier)
          .enregistrerPrevision(c.read(crmProvider).etapes);
      await tester.pumpAndSettle();
      expect(
        find.text("5 lignes prévues · modifiable jusqu'au lundi soir"),
        findsOneWidget,
      );
      expect(find.text('Prévision'), findsOneWidget);
    });

    testWidgets('sans prévision : lignes « saisies »', (tester) async {
      await pumpEcran(tester, const MesRapportsScreen(), role: Role.cs);
      final c = conteneur(tester);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.prevision);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.rapport);
      await tester.pumpAndSettle();
      expect(
        find.text('5 lignes saisies · validation automatique lundi à 4 h'),
        findsOneWidget,
      );
      expect(find.text('Auto'), findsOneWidget);
    });

    testWidgets(
      'semaine validée : la carte jaune disparaît, la semaine 45 s’ajoute',
      (tester) async {
        await pumpEcran(tester, const MesRapportsScreen(), role: Role.cs);
        conteneur(
          tester,
        ).read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
        await tester.pumpAndSettle();
        expect(find.text('Semaine 45 · en cours'), findsNothing);
        expect(find.text('Semaine 45'), findsOneWidget);
        expect(find.text('2 – 6 novembre'), findsOneWidget);
        // 4 visites hors ADM, 25 % du prévu, 4 RDV.
        expect(find.text('4 visites'), findsOneWidget);
        expect(find.text('25 % du prévu'), findsOneWidget);
        expect(find.text('4 RDV obtenus'), findsNWidgets(2));
        expect(
          find.text('Validé automatiquement le lun. 9 nov. à 04:00'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Écarts avec la prévision : +1 ajoutée · 1 déplacée · 2 non réalisées',
          ),
          findsOneWidget,
        );
        expect(find.text('Validé auto'), findsNWidgets(5));
        // La semaine 45 est la première de la liste.
        final y45 = tester.getTopLeft(find.text('Semaine 45')).dy;
        final y44 = tester.getTopLeft(find.text('Semaine 44')).dy;
        expect(y45, lessThan(y44));
      },
    );

    testWidgets('semaine validée du directeur : écarts de toute la région', (
      tester,
    ) async {
      await pumpEcran(tester, const MesRapportsScreen(), role: Role.dir);
      conteneur(
        tester,
      ).read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
      await tester.pumpAndSettle();
      expect(find.text('7 visites'), findsOneWidget);
      expect(find.text('38 % du prévu'), findsOneWidget);
      expect(
        find.text(
          'Écarts avec la prévision : +1 ajoutée · 1 retirée · 1 déplacée · 3 non réalisées',
        ),
        findsOneWidget,
      );
    });

    testWidgets('semaine validée sans prévision : aucun pourcentage', (
      tester,
    ) async {
      await pumpEcran(tester, const MesRapportsScreen(), role: Role.cs);
      final c = conteneur(tester);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.prevision);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
      await tester.pumpAndSettle();
      expect(find.text('Semaine 45'), findsOneWidget);
      expect(find.textContaining('du prévu'), findsNWidgets(4));
      expect(
        find.text('Écarts avec la prévision : aucun écart'),
        findsNWidgets(2),
      );
    });
  });
}
