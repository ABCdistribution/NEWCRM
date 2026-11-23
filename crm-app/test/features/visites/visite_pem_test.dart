import 'package:crm_app/core/data/referentiels_visite.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/referentiels_visite_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/visites/state/actions_visite.dart';
import 'package:crm_app/features/visites/widgets/badge_visite.dart';
import 'package:crm_app/features/visites/widgets/briefing_visite.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_visites.dart';

/// Parcours d'une visite PEM : photo d'arrivée, photo du rayon avant, articles PEM, questionnaire, photo du rayon après.
const articles = [
  ArticlePem(
    articleId: 'a1',
    libelle: 'Titanium 2',
    code: '20015',
    marque: 'Titanium',
  ),
  ArticlePem(articleId: 'a2', libelle: 'Salon Series', code: '20007'),
  ArticlePem(articleId: 'a3', libelle: 'Elixir de brillance', code: '20020'),
];

const questions = [
  QuestionFin(
    id: 'q1',
    libelle: 'Rayon propre ?',
    type: TypeQuestionFin.caseACocher,
    obligatoire: true,
  ),
];

final ovArticles = articlesPemProvider.overrideWith(
  (ref) => Stream.value(articles),
);
final ovSansArticle = articlesPemProvider.overrideWith(
  (ref) => Stream.value(const <ArticlePem>[]),
);
final ovQuestions = questionnaireProvider.overrideWith(
  (ref) => Stream.value(questions),
);

/// Démarre la visite PEM de la proposition de démonstration chez U Express – Paris (m5), kilométrage écarté.
Future<String> demarrerPem(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await lancerApp(tester, Role.promoteur, overrides: overrides);
  AppRoutes.demarrerVisitePem(contexteCoquille(tester), 'm5', 'pem-d1');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Plus tard'));
  await tester.pumpAndSettle();
  return storeApp(tester).visites.first.id;
}

Visite visite(WidgetTester tester, String id) =>
    storeApp(tester).visites.firstWhere((v) => v.id == id);

ActionsVisite actionsDe(WidgetTester tester, String id) =>
    ActionsVisite(conteneurApp(tester).read(crmProvider.notifier), id);

Future<void> suivant(WidgetTester tester) =>
    toucher(tester, find.text('Suivant ›'));

/// « Suivant » refuse l'étape : le message s'affiche et on reste sur l'étape `etape` (rang à partir de 1).
Future<void> attendreRefus(
  WidgetTester tester,
  String message,
  int etape, {
  int total = 5,
}) async {
  await suivant(tester);
  expect(find.text(message), findsOneWidget);
  expect(find.text('Étape $etape / $total'), findsOneWidget);
  await attendreToast(tester);
}

/// Interrupteurs « Mis en avant » affichés, dans l'ordre.
Finder get interrupteurs => find.byType(Interrupteur);

void main() {
  group('parcours PEM', () {
    testWidgets('en-tête : pastille PEM, cinq étapes, briefing du magasin', (
      tester,
    ) async {
      final id = await demarrerPem(tester, overrides: [ovArticles]);
      expect(id, 'v218093');
      final v = visite(tester, id);
      expect(
        (v.estPem, v.propositionPemId, v.magasinId),
        (true, 'pem-d1', 'm5'),
      );
      expect(find.text('U Express – Paris'), findsOneWidget);
      expect(
        find.text('Visite #218093 · début 04/11/2026 14h23'),
        findsOneWidget,
      );
      expect(find.byType(BadgePem), findsOneWidget);
      expect(
        find.descendant(of: find.byType(BadgePem), matching: find.text('PEM')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(BadgeVisite),
          matching: find.text('En cours'),
        ),
        findsOneWidget,
      );
      expect(find.text('Visite PEM'), findsOneWidget);
      expect(find.text('Étape 1 / 5'), findsOneWidget);
      expect(find.text(EtapeDph.arrivee.libelle), findsOneWidget);
      expect(find.byType(BlocBriefing), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('parcours complet : cinq étapes puis la validation', (
      tester,
    ) async {
      final id = await demarrerPem(
        tester,
        overrides: [ovArticles, ovQuestions],
      );
      final actions = actionsDe(tester, id);

      // 1. Photo d'arrivée : exigée.
      await attendreRefus(tester, "Prenez la photo d'arrivée sur site.", 1);
      actions.ajouterPhoto(EtapeDph.arrivee);
      await tester.pumpAndSettle();
      await suivant(tester);

      // 2. Photo du rayon avant : exigée.
      expect(find.text('Étape 2 / 5'), findsOneWidget);
      expect(find.text('Photo du rayon avant'), findsOneWidget);
      await attendreRefus(tester, 'Prenez la photo du rayon.', 2);
      actions.ajouterPhoto(EtapeDph.rayonArrivee);
      await tester.pumpAndSettle();
      await suivant(tester);

      // 3. Articles PEM : rien de présélectionné, « Suivant » bloqué tant que tout n'est pas relevé.
      expect(find.text('Étape 3 / 5'), findsOneWidget);
      expect(find.text('Vérification des articles PEM'), findsOneWidget);
      expect(find.text('0/3 relevés'), findsOneWidget);
      expect(find.text('Titanium 2'), findsOneWidget);
      expect(find.text('Titanium · 20015'), findsOneWidget);
      expect(find.text('Salon Series'), findsOneWidget);
      expect(find.text('20007'), findsOneWidget);
      expect(find.text('Présent'), findsNWidgets(3));
      expect(find.text('Absent'), findsNWidgets(3));
      expect(find.text('Mis en avant'), findsNothing);
      expect(visite(tester, id).articlesPem, isEmpty);
      await attendreRefus(
        tester,
        "Indiquez pour chaque article PEM s'il est présent ou absent.",
        3,
      );

      // Premier article présent : l'interrupteur « Mis en avant » apparaît, éteint.
      await toucher(tester, find.text('Présent').at(0));
      expect(find.text('1/3 relevés'), findsOneWidget);
      expect(find.text('Mis en avant'), findsOneWidget);
      expect(tester.widget<Interrupteur>(interrupteurs.first).valeur, isFalse);
      expect(visite(tester, id).articlesPem['a1'], (
        present: true,
        misEnAvant: false,
      ));
      await toucher(tester, interrupteurs.first);
      expect(tester.widget<Interrupteur>(interrupteurs.first).valeur, isTrue);
      expect(visite(tester, id).articlesPem['a1'], (
        present: true,
        misEnAvant: true,
      ));

      // Deuxième absent : pas d'interrupteur.
      await toucher(tester, find.text('Absent').at(1));
      expect(find.text('2/3 relevés'), findsOneWidget);
      expect(interrupteurs, findsOneWidget);
      expect(visite(tester, id).articlesPem['a2'], (
        present: false,
        misEnAvant: false,
      ));
      await attendreRefus(
        tester,
        "Indiquez pour chaque article PEM s'il est présent ou absent.",
        3,
      );

      // Troisième présent, non mis en avant.
      await toucher(tester, find.text('Présent').at(2));
      expect(find.text('3/3 relevés'), findsOneWidget);
      expect(interrupteurs, findsNWidgets(2));
      await suivant(tester);

      // 4. Questionnaire : question obligatoire.
      expect(find.text('Étape 4 / 5'), findsOneWidget);
      expect(find.text('Rayon propre ? *'), findsOneWidget);
      await attendreRefus(tester, 'Répondez aux questions obligatoires.', 4);
      actions.repondre('q1', 'true');
      await tester.pumpAndSettle();
      await suivant(tester);

      // 5. Photo du rayon après : pas exigée ; « Terminer la visite » remplace « Suivant ».
      expect(find.text('Étape 5 / 5'), findsOneWidget);
      expect(find.text('Photo du rayon après'), findsOneWidget);
      expect(find.text('Suivant ›'), findsNothing);
      await tester.tap(find.text('✓ Terminer la visite'));
      await tester.pumpAndSettle();
      expect(find.text('Valider la visite ?'), findsOneWidget);
      expect(find.byType(MessageErreur), findsNothing);
      final v = visite(tester, id);
      for (final e in EtapeDph.parcoursPem) {
        expect(v.etapeFaite(e), isTrue, reason: e.cle);
      }
      // Ni commande, ni DN, ni produits indispensables dans une visite PEM.
      for (final e in [
        EtapeDph.colis,
        EtapeDph.dn,
        EtapeDph.indispensables,
        EtapeDph.commande,
      ]) {
        expect(v.etapeFaite(e), isFalse, reason: e.cle);
      }

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      final fin = visite(tester, id);
      expect(fin.etat, EtatVisite.terminee);
      expect((fin.articlesPemAbsents, fin.articlesPemMisEnAvant), (1, 1));
      expect(
        find.text('Visite #218093 validée. Envoi dès que le réseau le permet.'),
        findsOneWidget,
      );
      await attendreToast(tester);

      // Accueil : la visite faite n'est plus proposée, l'autre proposition reste.
      expect(find.text('Visites PEM'), findsOneWidget);
      expect(find.text('U Express – Paris'), findsNothing);
      expect(find.text('Obligatoire'), findsOneWidget);

      // Liste des visites : pastille « PEM ».
      await tester.tap(ongletNav('Visites'));
      await tester.pumpAndSettle();
      expect(find.text('PEM'), findsOneWidget);

      // Compte rendu : rubrique articles PEM, sans commande ni DN.
      AppRoutes.compteRendu(contexteCoquille(tester), id);
      await tester.pumpAndSettle();
      expect(find.text('Visite #218093'), findsOneWidget);
      expect(
        find.text('Compte rendu de la visite PEM'.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(BadgePem), matching: find.text('PEM')),
        findsOneWidget,
      );
      expect(find.text('ARTICLES PEM'), findsOneWidget);
      expect(find.text('Articles absents'), findsOneWidget);
      expect(find.text('1 sur 3'), findsOneWidget);
      expect(find.text('Articles mis en avant'), findsOneWidget);
      expect(find.text('1 sur 2'), findsOneWidget);
      // Libellés : ceux de la liste PEM du CRM.
      expect(find.text('Salon Series'), findsOneWidget);
      expect(find.text('Titanium 2'), findsOneWidget);
      expect(find.text('Elixir de brillance'), findsNothing);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('Mis en avant'), findsOneWidget);
      expect(find.text('COMMANDE LIÉE À LA VISITE'), findsNothing);
      expect(find.text('DISTRIBUTION NUMÉRIQUE PAR KIT'), findsNothing);
      expect(find.text('PRODUITS INDISPENSABLES'), findsNothing);
      // Timing : les étapes PEM, avec leurs libellés « avant » et « après ».
      expect(find.text('TIMING DE VISITE'), findsOneWidget);
      for (final t in [
        'Début de visite',
        "Photo d'arrivée sur site",
        'Photo du rayon avant',
        'Vérification des articles PEM',
        'Questionnaire de fin de visite',
        'Photo du rayon après',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (final t in [
        'Commande à mettre en rayon',
        'Vérification DN',
        'Commande liée à la visite',
        'Photo du rayon',
      ]) {
        expect(find.text(t), findsNothing, reason: t);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'liste des articles PEM inconnue : l’étape n’est pas proposée',
      (tester) async {
        final id = await demarrerPem(
          tester,
          overrides: [ovSansArticle, ovQuestions],
        );
        final actions = actionsDe(tester, id);
        expect(find.text('Étape 1 / 4'), findsOneWidget);
        actions.ajouterPhoto(EtapeDph.arrivee);
        await tester.pumpAndSettle();
        await suivant(tester);
        actions.ajouterPhoto(EtapeDph.rayonArrivee);
        await tester.pumpAndSettle();
        await suivant(tester);
        expect(find.text('Étape 3 / 4'), findsOneWidget);
        expect(find.text('Rayon propre ? *'), findsOneWidget);
        expect(find.text('Vérification des articles PEM'), findsNothing);
      },
    );

    testWidgets('la visite reprend sur la première étape non faite', (
      tester,
    ) async {
      final id = await demarrerPem(tester, overrides: [ovArticles]);
      conteneurApp(tester)
          .read(crmProvider.notifier)
          .majVisite(
            id,
            (v) => v.copyWith(
              chrono: {
                ...v.chrono,
                EtapeDph.arrivee: '04/11/2026 14h30',
                EtapeDph.rayonArrivee: '04/11/2026 14h35',
              },
            ),
          );
      await tester.pumpAndSettle();
      AppRoutes.retourRacine(contexteCoquille(tester));
      await tester.pumpAndSettle();
      AppRoutes.demarrerVisitePem(contexteCoquille(tester), 'm5', 'pem-d1');
      await tester.pumpAndSettle();
      expect(find.text('Étape 3 / 5'), findsOneWidget);
      expect(find.text('Vérification des articles PEM'), findsOneWidget);
      expect(storeApp(tester).visites.where((v) => v.estPem), hasLength(1));
    });

    testWidgets('« Précédent » revient d’une étape à l’autre', (tester) async {
      final id = await demarrerPem(tester, overrides: [ovArticles]);
      final actions = actionsDe(tester, id);
      actions.ajouterPhoto(EtapeDph.arrivee);
      await tester.pumpAndSettle();
      await suivant(tester);
      expect(find.text('Étape 2 / 5'), findsOneWidget);
      await tester.tap(find.text('‹ Précédent'));
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 / 5'), findsOneWidget);
      expect(find.text("Photo d'arrivée sur site"), findsOneWidget);
    });
  });
}
