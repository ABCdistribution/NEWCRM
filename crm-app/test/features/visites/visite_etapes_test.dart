import 'package:crm_app/core/data/referentiels_visite.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/referentiels_visite_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/commandes/prise_commande_screen.dart';
import 'package:crm_app/features/visites/compte_rendu_screen.dart';
import 'package:crm_app/features/visites/kit_detail_sheet.dart';
import 'package:crm_app/features/visites/kits_sheet.dart';
import 'package:crm_app/features/visites/state/actions_visite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_visites.dart';

/// Ferme le dialogue de kilométrage de départ proposé au promoteur.
Future<void> fermerKilometrage(WidgetTester tester) async {
  await tester.tap(find.text('Plus tard'));
  await tester.pumpAndSettle();
}

/// Le brouillon du client `magasinId`, kilométrage de départ déjà écarté (promoteur).
Future<String> brouillonPromoteur(
  WidgetTester tester,
  String magasinId, {
  List<Override> overrides = const [],
}) async {
  final id = await demarrerVisiteChez(
    tester,
    Role.promoteur,
    magasinId,
    overrides: overrides,
  );
  await fermerKilometrage(tester);
  return id;
}

Visite visite(WidgetTester tester, String id) =>
    storeApp(tester).visites.firstWhere((v) => v.id == id);

ActionsVisite actionsDe(WidgetTester tester, String id) =>
    ActionsVisite(conteneurApp(tester).read(crmProvider.notifier), id);

/// Démarre un brouillon chez m1 (promoteur), horodate les étapes qui précèdent `etape` et rouvre la visite : le
/// parcours s'ouvre sur la première étape non faite, soit `etape`. `preparer` ajuste la visite avant la réouverture.
Future<String> ouvrirALEtape(
  WidgetTester tester,
  EtapeDph etape, {
  List<Override> overrides = const [],
  Visite Function(Visite v)? preparer,
}) async {
  final id = await brouillonPromoteur(tester, 'm1', overrides: overrides);
  conteneurApp(tester).read(crmProvider.notifier).majVisite(id, (v) {
    final prepare = v.copyWith(
      chrono: {
        ...v.chrono,
        for (final e in EtapeDph.parcours.takeWhile((e) => e != etape))
          e: '04/11/2026 14h30',
      },
    );
    return preparer == null ? prepare : preparer(prepare);
  });
  await tester.pumpAndSettle();
  AppRoutes.retourRacine(contexteCoquille(tester));
  await tester.pumpAndSettle();
  AppRoutes.demarrerVisite(contexteCoquille(tester), 'm1');
  await tester.pumpAndSettle();
  return id;
}

Future<void> suivant(WidgetTester tester) async {
  await toucher(tester, find.text('Suivant ›'));
}

/// « Suivant » refuse l'étape : le message s'affiche et on reste sur `etape` (rang à partir de 1).
Future<void> attendreRefus(
  WidgetTester tester,
  String message,
  int etape,
) async {
  await suivant(tester);
  expect(find.text(message), findsOneWidget);
  expect(find.text('Étape $etape / 8'), findsOneWidget);
  await attendreToast(tester);
}

const questions = [
  QuestionFin(
    id: 'q1',
    libelle: 'Rayon propre ?',
    type: TypeQuestionFin.caseACocher,
    obligatoire: true,
  ),
  QuestionFin(
    id: 'q2',
    libelle: 'Note du rayon',
    type: TypeQuestionFin.note,
    obligatoire: false,
  ),
  QuestionFin(
    id: 'q3',
    libelle: 'Remarque',
    type: TypeQuestionFin.texte,
    obligatoire: false,
  ),
  QuestionFin(
    id: 'q4',
    libelle: 'Nombre de facings',
    type: TypeQuestionFin.nombre,
    obligatoire: false,
  ),
];

const raisons = [
  RaisonAbsence(id: 'r1', libelle: 'Stock suffisant'),
  RaisonAbsence(id: 'r2', libelle: 'Gérant absent'),
];

const promos = [
  PromoOp(id: 'p1', libelle: '2 pour 1 shampoings', article: 'Shampoing 250 ml'),
  PromoOp(id: 'p2', libelle: 'Lot masque'),
];

final ovQuestions = questionnaireProvider.overrideWith(
  (ref) => Stream.value(questions),
);
final ovRaisons = raisonsAbsenceProvider.overrideWith(
  (ref) => Stream.value(raisons),
);
final ovPromos = promosOpProvider.overrideWith((ref) => Stream.value(promos));

void main() {
  group('Visite en cours : parcours « Précédent / Suivant »', () {
    testWidgets('démarrer une visite crée un brouillon sur la première étape', (
      tester,
    ) async {
      final id = await brouillonPromoteur(tester, 'm1');
      expect(id, 'v218093');
      final v = storeApp(tester).visites.first;
      expect(v.etat, EtatVisite.brouillon);
      expect(v.magasinId, 'm1');
      expect(v.par, 'Julien M.');
      expect(v.commandeEnRayon, isNull);
      expect(v.colis, isEmpty);

      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(
        find.text('Visite #218093 · début 04/11/2026 14h23'),
        findsOneWidget,
      );
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Visite'), findsOneWidget);
      expect(find.text('Étape 1 / 8'), findsOneWidget);
      expect(find.text("Photo d'arrivée sur site"), findsOneWidget);
      expect(find.text('📷 Prendre une photo'), findsOneWidget);
      expect(find.text('Aucune photo pour cette étape.'), findsOneWidget);
      // première étape : pas de « Précédent » ; plus d'anciens boutons séparés
      expect(find.text('‹ Précédent'), findsNothing);
      expect(find.text('Suivant ›'), findsOneWidget);
      expect(find.text('✓ Terminer la visite'), findsNothing);
      expect(find.text('🛒 Commander'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'le promoteur se voit proposer le kilométrage de départ une seule fois',
      (tester) async {
        await demarrerVisiteChez(tester, Role.promoteur, 'm1');
        expect(find.text('Kilométrage de départ'), findsOneWidget);
        await fermerKilometrage(tester);
        expect(find.text('Kilométrage de départ'), findsNothing);
        // reprendre le même brouillon ne repose pas la question
        AppRoutes.retourRacine(contexteCoquille(tester));
        await tester.pumpAndSettle();
        AppRoutes.demarrerVisite(contexteCoquille(tester), 'm1');
        await tester.pumpAndSettle();
        expect(
          storeApp(tester).visites.where((v) => v.magasinId == 'm1').length,
          1,
        );
        expect(find.text('Kilométrage de départ'), findsNothing);
        // un autre client : nouveau brouillon, toujours pas de dialogue
        AppRoutes.retourRacine(contexteCoquille(tester));
        await tester.pumpAndSettle();
        AppRoutes.demarrerVisite(contexteCoquille(tester), 'm8');
        await tester.pumpAndSettle();
        expect(find.text('Kilométrage de départ'), findsNothing);
        expect(storeApp(tester).visites.length, 3);
      },
    );

    for (final role in [Role.cs, Role.dir]) {
      testWidgets('${role.profil.libelle} : pas de kilométrage', (tester) async {
        await demarrerVisiteChez(tester, role, 'm1');
        expect(find.text('Kilométrage de départ'), findsNothing);
        expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
        expect(
          find.text('Visite #218093 · début 04/11/2026 14h23'),
          findsOneWidget,
        );
        expect(find.text('Étape 1 / 8'), findsOneWidget);
        expect(find.text('Suivant ›'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('« Suivant » sans photo d’arrivée affiche l’erreur et reste', (
      tester,
    ) async {
      final id = await brouillonPromoteur(tester, 'm1');
      await attendreRefus(tester, "Prenez la photo d'arrivée sur site.", 1);
      // l'étape n'est pas horodatée
      expect(visite(tester, id).etapeFaite(EtapeDph.arrivee), isFalse);
      expect(find.text("Photo d'arrivée sur site"), findsOneWidget);
    });

    testWidgets('une photo horodate l’étape et ouvre « Suivant » (v-etape)', (
      tester,
    ) async {
      final id = await brouillonPromoteur(tester, 'm1');
      // la prise de photo (caméra) est simulée par l'action qui suit chaque capture
      final actions = actionsDe(tester, id);
      actions.ajouterPhoto(EtapeDph.arrivee);
      await tester.pumpAndSettle();
      var v = visite(tester, id);
      expect(v.photos[EtapeDph.arrivee], 1);
      expect(v.chrono[EtapeDph.arrivee], '04/11/2026 14h27');

      // une deuxième photo s'ajoute sans changer l'horodatage
      actions.ajouterPhoto(EtapeDph.arrivee);
      await tester.pumpAndSettle();
      v = visite(tester, id);
      expect(v.photos[EtapeDph.arrivee], 2);
      expect(v.chrono[EtapeDph.arrivee], '04/11/2026 14h27');

      // supprimer une photo en retire une, jamais sous zéro
      actions.retirerPhoto(EtapeDph.arrivee);
      expect(visite(tester, id).photos[EtapeDph.arrivee], 1);
      actions.retirerPhoto(EtapeDph.arrivee);
      actions.retirerPhoto(EtapeDph.arrivee);
      expect(visite(tester, id).photos[EtapeDph.arrivee], 0);
      actions.ajouterPhoto(EtapeDph.arrivee);
      await tester.pumpAndSettle();

      await suivant(tester);
      expect(find.text('Étape 2 / 8'), findsOneWidget);
      expect(find.text('Photo du rayon'), findsOneWidget);
      expect(find.text('‹ Précédent'), findsOneWidget);
      // la photo du rayon est exigée à son tour, et horodatée plus tard : 14:23 + 9 min
      await attendreRefus(tester, 'Prenez la photo du rayon.', 2);
      actions.ajouterPhoto(EtapeDph.rayonArrivee);
      await tester.pumpAndSettle();
      expect(
        visite(tester, id).chrono[EtapeDph.rayonArrivee],
        '04/11/2026 14h32',
      );
      await suivant(tester);
      expect(find.text('Étape 3 / 8'), findsOneWidget);
    });

    testWidgets('« Précédent » revient sans rien valider', (tester) async {
      final id = await ouvrirALEtape(tester, EtapeDph.colis);
      expect(find.text('Étape 3 / 8'), findsOneWidget);
      await tester.tap(find.text('‹ Précédent'));
      await tester.pumpAndSettle();
      expect(find.text('Étape 2 / 8'), findsOneWidget);
      expect(find.text('Photo du rayon'), findsOneWidget);
      await tester.tap(find.text('‹ Précédent'));
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 / 8'), findsOneWidget);
      expect(find.text('‹ Précédent'), findsNothing);
      // revenir ne horodate pas l'étape qui n'a pas été validée
      expect(visite(tester, id).etapeFaite(EtapeDph.colis), isFalse);
    });

    testWidgets('rouvrir une visite reprend à la première étape non faite', (
      tester,
    ) async {
      await ouvrirALEtape(tester, EtapeDph.dn);
      expect(find.text('Étape 4 / 8'), findsOneWidget);
      expect(find.text('Distribution numérique par kit'.toUpperCase()), findsOneWidget);
    });
  });

  group('Étape « Commande à mettre en rayon »', () {
    testWidgets('il faut répondre, « Non » efface les colis', (tester) async {
      final id = await ouvrirALEtape(tester, EtapeDph.colis);
      expect(find.text('Commande à mettre en rayon'), findsOneWidget);
      expect(
        find.text('Y a-t-il une commande à mettre en rayon ?'),
        findsOneWidget,
      );
      await attendreRefus(
        tester,
        "Indiquez s'il y a une commande à mettre en rayon.",
        3,
      );
      expect(find.text('Ou saisir le code du colis'), findsNothing);

      await toucher(tester, find.text('Oui'));
      expect(visite(tester, id).commandeEnRayon, isTrue);
      expect(find.text('Ou saisir le code du colis'), findsOneWidget);
      expect(find.text('📷 Scanner un colis'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  COL-001 ');
      await toucher(tester, find.text('＋ Ajouter ce colis'));
      await tester.enterText(find.byType(TextField), 'COL-002');
      await toucher(tester, find.text('＋ Ajouter ce colis'));
      // un code déjà saisi ou vide n'est pas ajouté deux fois
      await tester.enterText(find.byType(TextField), 'COL-002');
      await toucher(tester, find.text('＋ Ajouter ce colis'));
      await tester.enterText(find.byType(TextField), '   ');
      await toucher(tester, find.text('＋ Ajouter ce colis'));
      expect(visite(tester, id).colis, ['COL-001', 'COL-002']);
      expect(find.text('COL-001'), findsOneWidget);

      // la croix retire un colis
      await tester.tap(find.text('✕').first);
      await tester.pumpAndSettle();
      expect(visite(tester, id).colis, ['COL-002']);

      // « Oui » avec colis : on avance
      await suivant(tester);
      expect(find.text('Étape 4 / 8'), findsOneWidget);
      expect(visite(tester, id).etapeFaite(EtapeDph.colis), isTrue);

      // « Non » efface les colis
      await tester.tap(find.text('‹ Précédent'));
      await tester.pumpAndSettle();
      await toucher(tester, find.text('Non'));
      expect(visite(tester, id).commandeEnRayon, isFalse);
      expect(visite(tester, id).colis, isEmpty);
      expect(find.text('Ou saisir le code du colis'), findsNothing);
    });
  });

  group('Étape « Vérification DN »', () {
    testWidgets('sans kit : consigne vide, « Suivant » passe', (tester) async {
      final id = await ouvrirALEtape(tester, EtapeDph.dn);
      expect(find.text('Vérification DN'), findsOneWidget);
      expect(find.text('DISTRIBUTION NUMÉRIQUE PAR KIT'), findsOneWidget);
      expect(find.text('Sélectionner les kits du rayon…'), findsOneWidget);
      expect(
        find.text(
          'Aucun kit sélectionné : choisissez les kits constatés en rayon.',
        ),
        findsOneWidget,
      );
      await suivant(tester);
      expect(find.text('Étape 5 / 8'), findsOneWidget);
      expect(visite(tester, id).etapeFaite(EtapeDph.dn), isTrue);
    });

    testWidgets('choisir des kits, ouvrir leur détail, en retirer un', (
      tester,
    ) async {
      final id = await ouvrirALEtape(tester, EtapeDph.dn);
      await tester.tap(find.text('Sélectionner les kits du rayon…'));
      await tester.pumpAndSettle();
      expect(find.byType(KitsSheet), findsOneWidget);
      expect(find.text('Valider (0)'), findsOneWidget);
      await tester.tap(find.textContaining('COSMIA ZIPPED PLANE KIT'));
      await tester.tap(find.textContaining('Kit racines brun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider (2)'));
      await tester.pumpAndSettle();

      expect(visite(tester, id).kits, ['COSMIA-01', '900024']);
      expect(visite(tester, id).dn, {'COSMIA-01': 0, '900024': 0});
      expect(
        find.text('2 kits sélectionnés · ajouter ou retirer…'),
        findsOneWidget,
      );
      expect(find.text('COSMIA ZIPPED PLANE KIT ›'), findsOneWidget);
      expect(find.text('Cosmia · Réf. COSMIA-01'), findsOneWidget);
      expect(find.text('Kit racines brun ›'), findsOneWidget);
      expect(find.text('✕'), findsNWidgets(2));

      // un appui sur le nom ouvre la composition du kit
      await tester.tap(find.text('COSMIA ZIPPED PLANE KIT ›'));
      await tester.pumpAndSettle();
      expect(find.byType(KitDetailSheet), findsOneWidget);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      // la croix retire le kit et sa distribution
      await tester.tap(find.text('✕').first);
      await tester.pumpAndSettle();
      expect(visite(tester, id).kits, ['900024']);
      expect(visite(tester, id).dn.keys, ['900024']);
      expect(
        find.text('1 kit sélectionné · ajouter ou retirer…'),
        findsOneWidget,
      );
    });
  });

  group('Étape « Commande liée à la visite »', () {
    testWidgets('sans raison proposée par le CRM, « Suivant » passe', (
      tester,
    ) async {
      final id = await ouvrirALEtape(tester, EtapeDph.commande);
      expect(find.text('Commande liée à la visite'), findsOneWidget);
      expect(
        find.text('Une commande est-elle liée à cette visite ?'),
        findsOneWidget,
      );
      await suivant(tester);
      expect(find.text('Étape 6 / 8'), findsOneWidget);
      expect(visite(tester, id).etapeFaite(EtapeDph.commande), isTrue);
    });

    testWidgets('avec des raisons : commande ou raison, jamais les deux', (
      tester,
    ) async {
      final id = await ouvrirALEtape(
        tester,
        EtapeDph.commande,
        overrides: [ovRaisons],
      );
      const refus =
          "Prenez la commande, ou choisissez la raison de l'absence de commande.";
      await attendreRefus(tester, refus, 5);

      // « Non » propose les raisons ; « Suivant » exige d'en choisir une
      await toucher(tester, find.text('Non'));
      expect(find.text("Raison de l'absence de commande :"), findsOneWidget);
      expect(find.text('Stock suffisant'), findsOneWidget);
      expect(find.text('Gérant absent'), findsOneWidget);
      await attendreRefus(tester, refus, 5);
      await toucher(tester, find.text('Gérant absent'));
      expect(visite(tester, id).raisonAbsenceId, 'r2');
      expect(visite(tester, id).raisonAbsence, 'Gérant absent');
      await toucher(tester, find.text('Stock suffisant'));
      expect(visite(tester, id).raisonAbsenceId, 'r1');

      // « Oui » efface la raison, et sans commande prise « Suivant » refuse encore
      await toucher(tester, find.text('Oui'));
      expect(visite(tester, id).raisonAbsenceId, isNull);
      expect(visite(tester, id).raisonAbsence, '');
      expect(find.text('Aucune commande prise pour le moment.'), findsOneWidget);
      expect(find.text('🛒 Prendre la commande'), findsOneWidget);
      await attendreRefus(tester, refus, 5);

      // retour à « Non » avec une raison : on avance
      await toucher(tester, find.text('Non'));
      await toucher(tester, find.text('Stock suffisant'));
      await suivant(tester);
      expect(find.text('Étape 6 / 8'), findsOneWidget);
      expect(visite(tester, id).etapeFaite(EtapeDph.commande), isTrue);
    });

    testWidgets('« Prendre la commande » ouvre la prise de commande liée', (
      tester,
    ) async {
      final id = await ouvrirALEtape(tester, EtapeDph.commande);
      await toucher(tester, find.text('Oui'));
      await toucher(tester, find.text('🛒 Prendre la commande'));
      final ecran = tester.widget<PriseCommandeScreen>(
        find.byType(PriseCommandeScreen),
      );
      expect(ecran.magasinId, 'm1');
      expect(ecran.visiteId, id);
    });

    testWidgets('la commande liée s’affiche et permet d’avancer', (
      tester,
    ) async {
      final id = await ouvrirALEtape(
        tester,
        EtapeDph.commande,
        overrides: [ovRaisons],
        preparer: (v) => v.copyWith(
          cmd: const CommandeLiee(
            id: '2042',
            ht: '1 540,00 €',
            liv: '06/11/2026',
          ),
        ),
      );
      expect(
        find.text('Commande #2042 : 1 540,00 € - 06/11/2026'),
        findsOneWidget,
      );
      expect(find.text('🛒 Modifier la commande'), findsOneWidget);
      expect(find.text('Aucune commande prise pour le moment.'), findsNothing);
      await suivant(tester);
      expect(find.text('Étape 6 / 8'), findsOneWidget);
      expect(visite(tester, id).etapeFaite(EtapeDph.commande), isTrue);
    });
  });

  group('Étape « Questionnaire de fin de visite »', () {
    testWidgets('sans question dans le CRM : message vide, « Suivant » passe', (
      tester,
    ) async {
      await ouvrirALEtape(tester, EtapeDph.questionnaire);
      expect(
        find.text("Aucune question n'est définie dans le CRM."),
        findsOneWidget,
      );
      await suivant(tester);
      expect(find.text('Étape 7 / 8'), findsOneWidget);
    });

    testWidgets('questions obligatoires : réponses de chaque type', (
      tester,
    ) async {
      final id = await ouvrirALEtape(
        tester,
        EtapeDph.questionnaire,
        overrides: [ovQuestions],
      );
      expect(find.text('Rayon propre ? *'), findsOneWidget);
      expect(find.text('Note du rayon'), findsOneWidget);
      expect(find.text('Remarque'), findsOneWidget);
      expect(find.text('Nombre de facings'), findsOneWidget);
      await attendreRefus(tester, 'Répondez aux questions obligatoires.', 6);

      await toucher(tester, find.text('Non'));
      expect(visite(tester, id).reponses['q1'], 'false');
      await toucher(tester, find.text('Oui'));
      expect(visite(tester, id).reponses['q1'], 'true');
      await toucher(tester, find.text('4'));
      expect(visite(tester, id).reponses['q2'], '4');

      await tester.enterText(find.byType(TextField).at(0), 'RAS');
      await tester.enterText(find.byType(TextField).at(1), '12');
      await tester.pumpAndSettle();
      expect(visite(tester, id).reponses['q3'], 'RAS');
      expect(visite(tester, id).reponses['q4'], '12');
      // vider un champ retire la réponse
      await tester.enterText(find.byType(TextField).at(0), '');
      await tester.pumpAndSettle();
      expect(visite(tester, id).reponses.containsKey('q3'), isFalse);

      await suivant(tester);
      expect(find.text('Étape 7 / 8'), findsOneWidget);
      expect(visite(tester, id).etapeFaite(EtapeDph.questionnaire), isTrue);
    });
  });

  group('Étape « Pointage OP »', () {
    testWidgets('sans promotion : message vide, « Suivant » passe', (
      tester,
    ) async {
      await ouvrirALEtape(tester, EtapeDph.op);
      expect(
        find.text('Aucune opération promotionnelle en cours.'),
        findsOneWidget,
      );
      await suivant(tester);
      expect(find.text('Étape 8 / 8'), findsOneWidget);
    });

    testWidgets('pointer chaque promotion : en place ou absente', (
      tester,
    ) async {
      final id = await ouvrirALEtape(tester, EtapeDph.op, overrides: [ovPromos]);
      expect(find.text('2 pour 1 shampoings'), findsOneWidget);
      expect(find.text('Shampoing 250 ml'), findsOneWidget);
      expect(find.text('Lot masque'), findsOneWidget);
      expect(visite(tester, id).op, isEmpty);

      await toucher(tester, find.text('En place').first);
      await toucher(tester, find.text('Absente').last);
      expect(visite(tester, id).op, {'p1': true, 'p2': false});
      // changer d'avis
      await toucher(tester, find.text('Absente').first);
      expect(visite(tester, id).op['p1'], isFalse);

      await suivant(tester);
      expect(find.text('Étape 8 / 8'), findsOneWidget);
      expect(visite(tester, id).etapeFaite(EtapeDph.op), isTrue);
    });
  });

  group('Dernière étape : « Terminer la visite »', () {
    testWidgets('remplace « Suivant » et n’exige pas de photo de fin', (
      tester,
    ) async {
      await ouvrirALEtape(tester, EtapeDph.rayonFin);
      expect(find.text('Étape 8 / 8'), findsOneWidget);
      expect(find.text('Photo du rayon de fin de visite'), findsOneWidget);
      expect(find.text('✓ Terminer la visite'), findsOneWidget);
      expect(find.text('Suivant ›'), findsNothing);
      expect(find.text('‹ Précédent'), findsOneWidget);
    });

    testWidgets('visite incomplète : la validation liste ce qui manque', (
      tester,
    ) async {
      final id = await ouvrirALEtape(tester, EtapeDph.rayonFin);
      await tester.tap(find.text('✓ Terminer la visite'));
      await tester.pumpAndSettle();
      expect(find.text('Visite incomplète'), findsOneWidget);
      expect(find.text('Il reste à faire :'), findsOneWidget);
      expect(find.byType(MessageErreur), findsNWidgets(3));
      expect(find.text('Valider'), findsNothing);
      expect(visite(tester, id).etapeFaite(EtapeDph.rayonFin), isTrue);
      expect(visite(tester, id).etat, EtatVisite.brouillon);
      await tester.tap(find.text('Corriger'));
      await tester.pumpAndSettle();
      expect(find.text('Visite incomplète'), findsNothing);
      expect(find.text('✓ Terminer la visite'), findsOneWidget);
    });

    testWidgets('le questionnaire du CRM compte dans la validation', (
      tester,
    ) async {
      final id = await ouvrirALEtape(
        tester,
        EtapeDph.rayonFin,
        overrides: [ovQuestions, ovRaisons],
        preparer: (v) => v.copyWith(
          photos: const {EtapeDph.arrivee: 1, EtapeDph.rayonArrivee: 1},
          commandeEnRayon: false,
        ),
      );
      await tester.tap(find.text('✓ Terminer la visite'));
      await tester.pumpAndSettle();
      expect(find.text('Visite incomplète'), findsOneWidget);
      expect(find.byType(MessageErreur), findsNWidgets(2));
      expect(
        find.text(
          "Prenez la commande, ou choisissez la raison de l'absence de commande.",
        ),
        findsOneWidget,
      );
      expect(find.text('Répondez aux questions obligatoires.'), findsOneWidget);
      // la liste suit la visite
      final actions = actionsDe(tester, id);
      actions.choisirRaisonAbsence('r1', 'Stock suffisant');
      actions.repondre('q1', 'true');
      await tester.pumpAndSettle();
      expect(find.text('Valider la visite ?'), findsOneWidget);
    });

    testWidgets('parcours complet : huit étapes puis la validation', (
      tester,
    ) async {
      final id = await brouillonPromoteur(
        tester,
        'm1',
        overrides: [ovQuestions, ovRaisons, ovPromos],
      );
      final actions = actionsDe(tester, id);

      actions.ajouterPhoto(EtapeDph.arrivee);
      await tester.pumpAndSettle();
      await suivant(tester);
      actions.ajouterPhoto(EtapeDph.rayonArrivee);
      await tester.pumpAndSettle();
      await suivant(tester);
      await toucher(tester, find.text('Non'));
      await suivant(tester);
      expect(find.text('Étape 4 / 8'), findsOneWidget);
      await suivant(tester); // DN
      await toucher(tester, find.text('Non'));
      await toucher(tester, find.text('Stock suffisant'));
      await suivant(tester);
      expect(find.text('Étape 6 / 8'), findsOneWidget);
      await toucher(tester, find.text('Oui'));
      await suivant(tester);
      expect(find.text('Étape 7 / 8'), findsOneWidget);
      await toucher(tester, find.text('En place').first);
      await suivant(tester);
      expect(find.text('Étape 8 / 8'), findsOneWidget);
      expect(find.text('Suivant ›'), findsNothing);

      await tester.tap(find.text('✓ Terminer la visite'));
      await tester.pumpAndSettle();
      expect(find.text('Valider la visite ?'), findsOneWidget);
      expect(find.byType(MessageErreur), findsNothing);
      final v = visite(tester, id);
      for (final e in EtapeDph.values) {
        expect(v.etapeFaite(e), isTrue, reason: e.cle);
      }
      expect(v.etat, EtatVisite.brouillon);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
    });
  });

  group('Autres écrans', () {
    testWidgets('une visite terminée s’ouvre en compte rendu', (tester) async {
      await lancerApp(tester, Role.promoteur);
      AppRoutes.visite(contexteCoquille(tester), 'd0');
      await tester.pumpAndSettle();
      expect(find.byType(CompteRenduScreen), findsOneWidget);
      expect(find.text('Visite #218082'), findsOneWidget);
      expect(find.text('Terminer la visite'), findsNothing);
      expect(find.text('Suivant ›'), findsNothing);
      expect(find.text('Kilométrage de départ'), findsNothing);
    });

    testWidgets(
      'en-tête : retour, barre de progression et univers de l’encadrement',
      (tester) async {
        await demarrerVisiteChez(tester, Role.dir, 'm1');
        expect(find.byType(BoutonRetour), findsOneWidget);
        expect(
          tester.widget<BoutonRetour>(find.byType(BoutonRetour)).taille,
          44,
        );
        await tester.tap(find.byType(BoutonRetour));
        await tester.pumpAndSettle();
        expect(find.text('Carrefour Market – Versailles'), findsNothing);
        // l'écran d'une visite inconnue reste affichable
        AppRoutes.visite(contexteCoquille(tester), 'inconnue');
        await tester.pumpAndSettle();
        expect(find.text('Visite introuvable.'), findsOneWidget);
      },
    );
  });
}
