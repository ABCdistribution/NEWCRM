import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/planning/formulaire_rdv_sheet.dart';
import 'package:crm_app/features/planning/planning_screen.dart';
import 'package:crm_app/features/planning/state/planning_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Onglet « Mon planning » : maquette `pageTournee` l.1010-1039, `salesPlanning` l.1052 (promoteur, lecture seule).

ProviderContainer conteneur(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(PlanningScreen, skipOffstage: false)),
);

/// Laisse passer la durée d'un toast (2,6 s) pour qu'il disparaisse.
Future<void> attendreToast(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

void main() {
  group('promoteur : planning en lecture seule', () {
    testWidgets('en-tête, jours et lignes du planning composé par l’encadrement', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.promoteur);
      expect(find.text('Mon planning'), findsOneWidget);
      expect(find.text('Semaine 45 · 2 – 6 novembre'), findsOneWidget);
      expect(find.text('‹'), findsOneWidget);
      expect(find.text('›'), findsOneWidget);
      for (final j in ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven']) {
        expect(find.text(j), findsOneWidget);
      }
      for (final n in ['2', '3', '4', '5', '6']) {
        expect(find.text(n), findsOneWidget);
      }
      // Lundi 1, mardi 1, mercredi 2, jeudi 1, vendredi 1.
      expect(find.text('1 RDV'), findsNWidgets(4));
      expect(find.text('2 RDV'), findsOneWidget);

      // Bandeau en lecture seule : œil, pas de phase, pas de « Prévu vs réalisé », pas de bouton.
      expect(find.text('👁'), findsOneWidget);
      expect(find.text('Planning de la semaine'), findsOneWidget);
      expect(find.text('Rapport en cours'), findsNothing);
      expect(find.text('Prévu vs réalisé'), findsNothing);
      expect(find.text('Enregistrer la prévision'), findsNothing);

      // Mercredi : deux visites chez des clients, la première déjà faite ; aucun « Visite simple » en lecture seule.
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsOneWidget);
      expect(find.text('Fait ✓'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Visite simple'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ni bouton « + », ni crayon, ni ouverture au toucher', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.promoteur);
      expect(find.byType(AppFab), findsNothing);
      expect(find.text('✎'), findsNothing);
      await tester.tap(find.text('Carrefour Market – Versailles'));
      await tester.pumpAndSettle();
      expect(find.byType(FormulaireRdvSheet), findsNothing);
      expect(
        ModalRoute.of(tester.element(find.byType(PlanningScreen)))!.isCurrent,
        isTrue,
      );
    });

    testWidgets('changer de jour change aussi le jour de l’accueil', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.promoteur);
      await tester.tap(find.text('Jeu'));
      await tester.pumpAndSettle();
      expect(conteneur(tester).read(jourPlanningProvider), 3);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('U Express – Boulogne-Billancourt'), findsOneWidget);
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsNothing);
    });

    testWidgets('jour sans ligne : « Aucune ligne ce jour. »', (tester) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.promoteur);
      final c = conteneur(tester);
      final vendredi = c
          .read(crmProvider)
          .planDe('Julien M.')
          .where((e) => e.jour == 4)
          .single;
      c
          .read(crmProvider.notifier)
          .supprimerEtape(vendredi.id, pour: 'Julien M.');
      await tester.tap(find.text('Ven'));
      await tester.pumpAndSettle();
      expect(find.text('0 RDV'), findsOneWidget);
      expect(find.text('Aucune ligne ce jour.'), findsOneWidget);
      expect(find.textContaining('Touchez le'), findsNothing);
    });

    testWidgets('flèches de semaine : message de la démo', (tester) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.promoteur);
      await tester.tap(find.text('›'));
      await tester.pump();
      expect(
        find.text('Navigation entre semaines : non détaillée dans la démo.'),
        findsOneWidget,
      );
      await attendreToast(tester);
      await tester.tap(find.text('‹'));
      await tester.pump();
      expect(
        find.text('Navigation entre semaines : non détaillée dans la démo.'),
        findsOneWidget,
      );
      await attendreToast(tester);
    });
  });

  group('chef de secteur', () {
    testWidgets('bandeau « Rapport en cours » et jours', (tester) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      expect(find.text('Mon planning'), findsOneWidget);
      expect(find.text('Semaine 45 · 2 – 6 novembre'), findsOneWidget);
      expect(find.text('⏳'), findsOneWidget);
      expect(find.text('Rapport en cours'), findsOneWidget);
      expect(
        find.text('Prévision figée le lun. 2 nov. (4 lignes).'),
        findsOneWidget,
      );
      // Lundi 1, mardi 1, mercredi 2, jeudi 1, vendredi 0.
      expect(find.text('1 RDV'), findsNWidgets(3));
      expect(find.text('2 RDV'), findsOneWidget);
      expect(find.text('0 RDV'), findsOneWidget);
      expect(find.byType(AppFab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mercredi : prospect (« Visite simple · RDV ») et ADM', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      expect(find.text('11:30'), findsOneWidget);
      expect(find.text('Carrefour – Paris'), findsOneWidget);
      expect(find.text('Prospect'), findsOneWidget);
      expect(find.text('Visite simple · RDV'), findsOneWidget);
      expect(find.text('16:00'), findsOneWidget);
      expect(find.text('Administratif'), findsOneWidget);
      expect(find.text('ADM'), findsOneWidget);
      expect(find.text('Compte rendu'), findsOneWidget);
      // Le crayon n'existe que sur les clients et les prospects.
      expect(find.text('✎'), findsOneWidget);
    });

    testWidgets('jeudi : prospect en négociation avec soirée étape', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      await tester.tap(find.text('Jeu'));
      await tester.pumpAndSettle();
      expect(find.text('Super U – Versailles'), findsOneWidget);
      expect(find.text('Négo'), findsOneWidget);
      expect(
        find.text(
          'Accompagnement · RDV · Soirée étape (Versailles) · Négociation',
        ),
        findsOneWidget,
      );
    });

    testWidgets('lundi : ligne déjà faite en vert', (tester) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      await tester.tap(find.text('Lun'));
      await tester.pumpAndSettle();
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsOneWidget);
      expect(find.text('Fait ✓'), findsOneWidget);
      expect(
        find.text('Visite simple · RDV · Point linéaire soin'),
        findsOneWidget,
      );
    });

    testWidgets('vendredi vide : invitation à utiliser le « + »', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      await tester.tap(find.text('Ven'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Aucune étape ce jour. Touchez le « + » pour ajouter une ligne.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('« Prévu vs réalisé » : 25 %, détail replié puis déplié', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      expect(find.text('Prévu vs réalisé'), findsOneWidget);
      expect(find.text('25 %'), findsOneWidget);
      expect(find.text('▼'), findsOneWidget);
      expect(find.text('4 prévues'), findsNothing);

      await tester.tap(find.text('Prévu vs réalisé'));
      await tester.pumpAndSettle();
      expect(find.text('▲'), findsOneWidget);
      expect(find.text('4 prévues'), findsOneWidget);
      expect(find.text('1 réalisées'), findsOneWidget);
      expect(find.text('1 ajoutée'), findsOneWidget);
      expect(find.text('1 déplacée'), findsOneWidget);
      expect(find.text('Aucun écart'), findsNothing);
      expect(
        find.text('Déplacé · prévu Mar 14:00 → planifié Mar 15:10'),
        findsOneWidget,
      );
      expect(find.text('Ajouté (non prévu) · Mer 16:00'), findsOneWidget);
      expect(find.text('Réalisé comme prévu · Lun 09:30'), findsOneWidget);
      expect(find.text('À faire · Mer 11:30'), findsOneWidget);
      expect(find.text('À faire · Jeu 10:00'), findsOneWidget);
      expect(
        find.text(
          'La prévision est figée depuis le mardi ; les écarts se mettent à jour au fil de la semaine.',
        ),
        findsOneWidget,
      );
      // L'état déplié est conservé dans le store du lot : il survit au changement d'onglet.
      expect(conteneur(tester).read(planningProvider).ecartsOuverts, isTrue);

      await tester.tap(find.text('Prévu vs réalisé'));
      await tester.pumpAndSettle();
      expect(find.text('▼'), findsOneWidget);
      expect(find.text('4 prévues'), findsNothing);
    });

    testWidgets('le pourcentage suit les lignes faites', (tester) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      conteneur(tester)
          .read(crmProvider.notifier)
          .majEtape('e6', (e) => e.copyWith(fait: true));
      await tester.pumpAndSettle();
      expect(find.text('50 %'), findsOneWidget);
    });

    testWidgets(
      'toucher une ligne client ouvre sa fiche, sans changer d’onglet',
      (tester) async {
        await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
        await tester.tap(find.text('Mar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Carrefour Market – Versailles'));
        await tester.pumpAndSettle();
        tester
            .takeException(); // la fiche est l'écran d'un autre lot : seule l'ouverture compte ici
        expect(
          ModalRoute.of(
            tester.element(find.byType(PlanningScreen, skipOffstage: false)),
          )!.isCurrent,
          isFalse,
        );
        expect(find.byType(FormulaireRdvSheet), findsNothing);
        expect(conteneur(tester).read(ongletProvider), OngletApp.accueil);
      },
    );

    testWidgets(
      'toucher une ligne prospect ouvre sa fiche sur l’onglet Prospects',
      (tester) async {
        await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
        await tester.tap(find.text('Carrefour – Paris'));
        await tester.pumpAndSettle();
        tester
            .takeException(); // la fiche est l'écran d'un autre lot : seule l'ouverture compte ici
        expect(
          ModalRoute.of(
            tester.element(find.byType(PlanningScreen, skipOffstage: false)),
          )!.isCurrent,
          isFalse,
        );
        expect(conteneur(tester).read(ongletProvider), OngletApp.prospects);
      },
    );

    testWidgets('toucher une ligne ADM ouvre le formulaire de modification', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      await tester.tap(find.text('Administratif'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier la ligne'), findsOneWidget);
      expect(find.text('Supprimer la ligne'), findsOneWidget);
    });

    testWidgets('le crayon ouvre le formulaire de la ligne', (tester) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      await tester.tap(find.text('✎'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier la ligne'), findsOneWidget);
      expect(find.text('Carrefour – Paris'), findsWidgets);
    });

    testWidgets('le bouton « + » ouvre « Nouveau RDV »', (tester) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
      await tester.tap(find.byType(AppFab));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau RDV'), findsOneWidget);
      expect(find.text('Ajouter la ligne'), findsOneWidget);
    });
  });

  group('directeur', () {
    testWidgets('planning de toute la région : 8 lignes de prévision, 38 %', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.dir);
      expect(find.text('Rapport en cours'), findsOneWidget);
      expect(
        find.text('Prévision figée le lun. 2 nov. (8 lignes).'),
        findsOneWidget,
      );
      expect(find.text('38 %'), findsOneWidget);
      // Lundi 2, mardi 2, mercredi 3, jeudi 1, vendredi 0.
      expect(find.text('2 RDV'), findsNWidgets(2));
      expect(find.text('3 RDV'), findsOneWidget);
      expect(find.text('1 RDV'), findsOneWidget);
      expect(find.text('0 RDV'), findsOneWidget);
      // Mercredi : client, prospect, ADM.
      expect(find.text('Carrefour – Rouen'), findsOneWidget);
      expect(find.text('Carrefour – Paris'), findsOneWidget);
      expect(find.text('Administratif'), findsOneWidget);
      expect(find.byType(AppFab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('détail des écarts : une ligne retirée et trois non faites', (
      tester,
    ) async {
      await pumpEcran(tester, const PlanningScreen(), role: Role.dir);
      await tester.tap(find.text('Prévu vs réalisé'));
      await tester.pumpAndSettle();
      expect(find.text('8 prévues'), findsOneWidget);
      expect(find.text('3 réalisées'), findsOneWidget);
      expect(find.text('1 ajoutée'), findsOneWidget);
      expect(find.text('1 retirée'), findsOneWidget);
      expect(find.text('1 déplacée'), findsOneWidget);
      expect(
        find.text('Retiré du planning, non réalisé · prévu Jeu 14:00'),
        findsOneWidget,
      );
    });
  });
}
