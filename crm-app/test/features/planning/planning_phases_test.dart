import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/planning/planning_screen.dart';
import 'package:crm_app/features/planning/state/planning_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Phases de la semaine (prévision, rapport en cours, validé) : maquette `pageTournee` l.1010-1039, `A.prevision`
/// l.2072-2076, `verrou` l.526, gestionnaire `data-phase` l.2162-2167.

ProviderContainer conteneur(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(PlanningScreen, skipOffstage: false)),
);

Future<void> monter(WidgetTester tester, Role role, PhasePlanning phase) async {
  await pumpEcran(tester, const PlanningScreen(), role: role);
  if (phase != PhasePlanning.rapport) {
    conteneur(tester).read(planningProvider.notifier).choisirPhase(phase);
    await tester.pumpAndSettle();
  }
}

Future<void> attendreToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

void main() {
  group('phase « prévision »', () {
    testWidgets(
      'prévision à saisir : bandeau, bouton, pas de « Prévu vs réalisé »',
      (tester) async {
        await monter(tester, Role.cs, PhasePlanning.prevision);
        expect(find.text('📝'), findsOneWidget);
        expect(find.text('Prévision à saisir'), findsOneWidget);
        expect(
          find.text(
            "Planifiez vos RDV de la semaine avec le « + », puis enregistrez votre prévision. Elle reste modifiable jusqu'au lundi soir, puis se fige.",
          ),
          findsOneWidget,
        );
        expect(find.text('Enregistrer la prévision'), findsOneWidget);
        expect(find.text('Prévu vs réalisé'), findsNothing);
        expect(find.byType(AppFab), findsOneWidget);
        // Pendant la saisie de la prévision, les lignes faites ne sont pas grisées en vert.
        await tester.tap(find.text('Lun'));
        await tester.pumpAndSettle();
        expect(find.text('Fait ✓'), findsNothing);
        expect(find.text('Client'), findsOneWidget);
      },
    );

    testWidgets('enregistrer la prévision : toast, titre, bouton désactivé', (
      tester,
    ) async {
      await monter(tester, Role.cs, PhasePlanning.prevision);
      await tester.tap(find.text('Enregistrer la prévision'));
      await tester.pump();
      expect(find.text('Prévision enregistrée.'), findsOneWidget);
      await attendreToast(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Prévision enregistrée le lun. 2 nov. à 09:10 (5 lignes)'),
        findsOneWidget,
      );
      expect(find.text('✅'), findsOneWidget);
      expect(
        find.text(
          "Modifiable jusqu'au lundi soir, puis figée dès le mardi. Le rapport sera validé automatiquement en fin de semaine.",
        ),
        findsOneWidget,
      );
      expect(find.text('Mettre à jour la prévision'), findsOneWidget);
      // Le bouton est désactivé : un appui ne fait rien.
      await tester.tap(find.text('Mettre à jour la prévision'));
      await tester.pump();
      expect(find.text('Prévision enregistrée.'), findsNothing);

      final plan = conteneur(tester).read(planningProvider);
      expect(plan.prevision!.length, 5);
      expect(plan.prevision!.every((e) => !e.fait), isTrue);
      expect(plan.ecartsOuverts, isTrue);
    });

    testWidgets(
      'une ligne ajoutée après l’enregistrement demande une mise à jour',
      (tester) async {
        await monter(tester, Role.cs, PhasePlanning.prevision);
        await tester.tap(find.text('Enregistrer la prévision'));
        await tester.pump();
        await attendreToast(tester);
        conteneur(tester)
            .read(crmProvider.notifier)
            .ajouterEtape(
              const EtapePlanning(
                id: 'x1',
                jour: 4,
                heure: '10:00',
                cible: CiblePlanning.libre,
                titre: 'Salon',
              ),
            );
        await tester.pumpAndSettle();
        expect(find.text('📝'), findsOneWidget);
        expect(
          find.text(
            "⚠ Des lignes ont changé depuis l'enregistrement : mettez la prévision à jour.",
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Mettre à jour la prévision'));
        await tester.pump();
        expect(find.text('Prévision enregistrée.'), findsOneWidget);
        await attendreToast(tester);
        await tester.pumpAndSettle();
        expect(
          find.text('Prévision enregistrée le lun. 2 nov. à 09:10 (6 lignes)'),
          findsOneWidget,
        );
      },
    );

    testWidgets('une prévision d’une seule ligne : « 1 ligne »', (
      tester,
    ) async {
      await monter(tester, Role.cs, PhasePlanning.prevision);
      final store = conteneur(tester).read(crmProvider.notifier);
      for (final id in ['e1', 'e4', 'e6', 'e7']) {
        store.supprimerEtape(id);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer la prévision'));
      await tester.pump();
      await attendreToast(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Prévision enregistrée le lun. 2 nov. à 09:10 (1 ligne)'),
        findsOneWidget,
      );
    });

    testWidgets('la prévision ne peut pas être vide', (tester) async {
      await monter(tester, Role.cs, PhasePlanning.prevision);
      final store = conteneur(tester).read(crmProvider.notifier);
      for (final id in ['e1', 'e4', 'e6', 'e7', 'e8']) {
        store.supprimerEtape(id);
      }
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Aucune étape ce jour. Touchez le « + » pour ajouter une ligne.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Enregistrer la prévision'));
      await tester.pump();
      expect(find.text('La prévision ne peut pas être vide.'), findsOneWidget);
      expect(conteneur(tester).read(planningProvider).prevision, isNull);
      await attendreToast(tester);
    });

    testWidgets('une soirée étape sans lieu bloque la prévision', (
      tester,
    ) async {
      await monter(tester, Role.cs, PhasePlanning.prevision);
      conteneur(tester)
          .read(crmProvider.notifier)
          .majEtape('e8', (e) => e.copyWith(soireeLieu: ''));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer la prévision'));
      await tester.pump();
      expect(
        find.text("Soirée étape : le lieu et l'adresse sont obligatoires."),
        findsOneWidget,
      );
      expect(conteneur(tester).read(planningProvider).prevision, isNull);
      await attendreToast(tester);
    });

    testWidgets('le directeur enregistre sa prévision de 8 lignes', (
      tester,
    ) async {
      await monter(tester, Role.dir, PhasePlanning.prevision);
      await tester.tap(find.text('Enregistrer la prévision'));
      await tester.pump();
      await attendreToast(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Prévision enregistrée le lun. 2 nov. à 09:10 (8 lignes)'),
        findsOneWidget,
      );
    });
  });

  group('phase « rapport en cours »', () {
    testWidgets('sans prévision : message et carte de comparaison impossible', (
      tester,
    ) async {
      await monter(tester, Role.cs, PhasePlanning.prevision);
      conteneur(
        tester,
      ).read(planningProvider.notifier).choisirPhase(PhasePlanning.rapport);
      await tester.pumpAndSettle();
      expect(find.text('Rapport en cours'), findsOneWidget);
      expect(
        find.text('Prévision non renseignée cette semaine.'),
        findsOneWidget,
      );
      expect(find.text('Prévu vs réalisé'), findsOneWidget);
      expect(
        find.text(
          "Prévision non renseignée cette semaine : il n'y a pas de comparaison possible.",
        ),
        findsOneWidget,
      );
      expect(find.text('▼'), findsNothing);
    });

    testWidgets('le bouton de prévision n’existe plus', (tester) async {
      await monter(tester, Role.cs, PhasePlanning.rapport);
      expect(find.text('Enregistrer la prévision'), findsNothing);
      expect(find.text('Mettre à jour la prévision'), findsNothing);
    });
  });

  group('phase « validé »', () {
    testWidgets('semaine verrouillée : bandeau, pas de « + »', (tester) async {
      await monter(tester, Role.cs, PhasePlanning.valide);
      expect(find.text('🔒'), findsOneWidget);
      expect(find.text('Validé auto le lun. 9 nov. à 04:00'), findsOneWidget);
      expect(
        find.text("La semaine est verrouillée : plus rien n'est modifiable."),
        findsOneWidget,
      );
      expect(find.byType(AppFab), findsNothing);
      expect(find.text('Enregistrer la prévision'), findsNothing);
      // Jour vide : texte sans invitation à utiliser le « + ».
      await tester.tap(find.text('Ven'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune ligne ce jour.'), findsOneWidget);
      expect(find.textContaining('Touchez le'), findsNothing);
    });

    testWidgets(
      'écarts figés : les lignes non faites deviennent « non réalisées »',
      (tester) async {
        await monter(tester, Role.cs, PhasePlanning.valide);
        expect(find.text('25 %'), findsOneWidget);
        await tester.tap(find.text('Prévu vs réalisé'));
        await tester.pumpAndSettle();
        expect(find.text('1 ajoutée'), findsOneWidget);
        expect(find.text('1 déplacée'), findsOneWidget);
        expect(find.text('2 non réalisées'), findsOneWidget);
        expect(find.text('Non réalisé · Mer 11:30'), findsOneWidget);
        expect(find.text('Non réalisé · Jeu 10:00'), findsOneWidget);
        expect(
          find.text(
            "Rapport figé : voici ce qui s'est réellement passé par rapport à la prévision.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('toucher une ligne ADM : message, pas de formulaire', (
      tester,
    ) async {
      await monter(tester, Role.cs, PhasePlanning.valide);
      await tester.tap(find.text('Administratif'));
      await tester.pump();
      expect(
        find.text("Rapport validé : plus rien n'est modifiable."),
        findsOneWidget,
      );
      expect(find.text('Modifier la ligne'), findsNothing);
      await attendreToast(tester);
    });

    testWidgets('le crayon est verrouillé aussi', (tester) async {
      await monter(tester, Role.cs, PhasePlanning.valide);
      await tester.tap(find.text('✎'));
      await tester.pump();
      expect(
        find.text("Rapport validé : plus rien n'est modifiable."),
        findsOneWidget,
      );
      await attendreToast(tester);
    });
  });

  group('lecture seule du promoteur', () {
    testWidgets('la phase ne change pas son bandeau', (tester) async {
      await monter(tester, Role.promoteur, PhasePlanning.valide);
      expect(find.text('👁'), findsOneWidget);
      expect(find.text('Planning de la semaine'), findsOneWidget);
      expect(find.text('🔒'), findsNothing);
      expect(find.text('Aucune ligne ce jour.'), findsNothing);
    });
  });
}
