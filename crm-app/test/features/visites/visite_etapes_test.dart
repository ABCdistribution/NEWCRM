import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/commandes/prise_commande_screen.dart';
import 'package:crm_app/features/visites/compte_rendu_screen.dart';
import 'package:crm_app/features/visites/photos_etape_screen.dart';
import 'package:crm_app/features/visites/saisie_etape_screen.dart';
import 'package:crm_app/features/visites/state/actions_visite.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_visites.dart';

/// Ferme le dialogue de kilométrage de départ proposé au promoteur.
Future<void> fermerKilometrage(WidgetTester tester) async {
  await tester.tap(find.text('Plus tard'));
  await tester.pumpAndSettle();
}

/// Le brouillon du client `magasinId`, kilométrage de départ déjà écarté (promoteur).
Future<String> brouillonPromoteur(WidgetTester tester, String magasinId) async {
  final id = await demarrerVisiteChez(tester, Role.promoteur, magasinId);
  await fermerKilometrage(tester);
  return id;
}

void main() {
  group(
    'Visite en cours : étapes DPH, visite PEM, commande liée (visiteEtapes l.1261-1280)',
    () {
      testWidgets('démarrer une visite crée un brouillon et en montre les étapes', (
        tester,
      ) async {
        final id = await brouillonPromoteur(tester, 'm1');
        expect(id, 'v218093');
        final v = storeApp(tester).visites.first;
        expect(v.etat, EtatVisite.brouillon);
        expect(v.magasinId, 'm1');
        expect(v.par, 'Julien M.');

        expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
        expect(
          find.text('Visite #218093 · début DPH 04/11/2026 14h23'),
          findsOneWidget,
        );
        expect(find.text('En cours'), findsOneWidget);
        expect(find.text('Visite DPH'), findsOneWidget);
        expect(find.text('1 / 9 étapes'), findsOneWidget);
        for (final t in [
          'Début visite DPH',
          "Photos d'arrivée sur site",
          "Photo(s) du rayon à l'arrivée",
          'Vérification DN',
          'Concurrence',
          'Vérification Promos',
          'Photos vue de face',
          'Photos du rayon de fin de visite DPH',
          'Bilan de visite',
        ]) {
          expect(find.text(t), findsOneWidget, reason: t);
        }
        // seule la prochaine étape est « à faire maintenant » ; le début est horodaté
        expect(find.text('À faire maintenant'), findsOneWidget);
        expect(find.text('04/11/2026 14h23'), findsOneWidget);
        // le début n'a pas de saisie ; les quatre photos, la DN, la concurrence, les promos et le bilan, si
        expect(find.text('＋ Photo'), findsNWidgets(4));
        expect(find.text('Saisir'), findsNWidgets(4));
        expect(find.text('Modifier'), findsNothing);
        expect(find.text('Visite PEM'), findsOneWidget);
        expect(find.text('Réalisée'), findsOneWidget);
        expect(find.text('Pas de visite PEM'), findsOneWidget);
        expect(find.text('Pas de visite PEM car :'), findsNothing);
        expect(find.text('Commande liée à la visite DPH'), findsOneWidget);
        expect(
          find.text('Aucune commande liée à cette visite.'),
          findsOneWidget,
        );
        expect(find.text('🛒 Commander'), findsOneWidget);
        expect(find.text('✓ Terminer la visite'), findsOneWidget);
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
        testWidgets('${role.profil.libelle} : pas de kilométrage', (
          tester,
        ) async {
          await demarrerVisiteChez(tester, role, 'm1');
          expect(find.text('Kilométrage de départ'), findsNothing);
          expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
          expect(
            find.text('Visite #218093 · début DPH 04/11/2026 14h23'),
            findsOneWidget,
          );
          expect(find.text('✓ Terminer la visite'), findsOneWidget);
          expect(find.text('Réalisée'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('une photo horodate l’étape et se compte (v-etape)', (
        tester,
      ) async {
        final id = await brouillonPromoteur(tester, 'm1');
        // toucher l'étape ouvre l'écran des photos (appareil photo, miniatures)
        await tester.tap(find.text("Photos d'arrivée sur site"));
        await tester.pumpAndSettle();
        expect(find.byType(PhotosEtapeScreen), findsOneWidget);
        expect(find.text('Aucune photo pour cette étape.'), findsOneWidget);
        expect(find.text('📷 Prendre une photo'), findsOneWidget);
        await tester.tap(find.text('Retour'));
        await tester.pumpAndSettle();

        // la prise de photo (caméra) est simulée par l'action qui suit chaque capture
        final actions = ActionsVisite(conteneurApp(tester).read(crmProvider.notifier), id);
        actions.ajouterPhoto(EtapeDph.arrivee);
        await tester.pumpAndSettle();
        var v = storeApp(tester).visites.firstWhere((x) => x.id == id);
        expect(v.photos[EtapeDph.arrivee], 1);
        expect(v.chrono[EtapeDph.arrivee], '04/11/2026 14h27');
        expect(find.text('04/11/2026 14h27 · 1 photo'), findsOneWidget);
        expect(find.text('2 / 9 étapes'), findsOneWidget);
        // la prochaine étape à faire a avancé
        expect(find.text('À faire maintenant'), findsOneWidget);

        // une deuxième photo s'ajoute sans changer l'horodatage
        actions.ajouterPhoto(EtapeDph.arrivee);
        await tester.pumpAndSettle();
        expect(find.text('04/11/2026 14h27 · 2 photos'), findsOneWidget);

        // supprimer une photo en retire une
        actions.retirerPhoto(EtapeDph.arrivee);
        await tester.pumpAndSettle();
        expect(find.text('04/11/2026 14h27 · 1 photo'), findsOneWidget);

        // l'étape suivante est horodatée plus tard : 14:23 + 9 min
        actions.ajouterPhoto(EtapeDph.rayonArrivee);
        await tester.pumpAndSettle();
        v = storeApp(tester).visites.firstWhere((x) => x.id == id);
        expect(v.chrono[EtapeDph.rayonArrivee], '04/11/2026 14h32');
        expect(find.text('3 / 9 étapes'), findsOneWidget);
        expect(find.text('＋ Photo'), findsNWidgets(4));
      });

      testWidgets(
        'visite PEM : réalisée, ou raison de l’absence (v-pem, v-raison)',
        (tester) async {
          final id = await brouillonPromoteur(tester, 'm1');
          VisitePem pem() =>
              storeApp(tester).visites.firstWhere((x) => x.id == id).pem;
          expect(pem().realisee, isNull);

          await toucher(tester, find.text('Pas de visite PEM'));
          await tester.pumpAndSettle();
          expect(pem().realisee, isFalse);
          expect(find.text('Pas de visite PEM car :'), findsOneWidget);
          for (final r in [
            'Pas de rayon PEM',
            'Rayon fermé ou en travaux',
            'Autre',
          ]) {
            expect(find.text(r), findsOneWidget, reason: r);
          }
          await toucher(tester, find.text('Rayon fermé ou en travaux'));
          await tester.pumpAndSettle();
          expect(pem().raison, 'Rayon fermé ou en travaux');

          await toucher(tester, find.text('Autre'));
          await tester.pumpAndSettle();
          expect(pem().raison, 'Autre');

          // « Réalisée » efface la raison et masque les puces
          await toucher(tester, find.text('Réalisée'));
          await tester.pumpAndSettle();
          expect(pem().realisee, isTrue);
          expect(pem().raison, '');
          expect(find.text('Pas de visite PEM car :'), findsNothing);

          // repasser à « Pas de visite PEM » repart sans raison
          await toucher(tester, find.text('Pas de visite PEM'));
          await tester.pumpAndSettle();
          expect(pem().realisee, isFalse);
          expect(pem().raison, '');
        },
      );

      testWidgets('la commande liée à la visite s’affiche', (tester) async {
        final id = await brouillonPromoteur(tester, 'm1');
        conteneurApp(tester)
            .read(crmProvider.notifier)
            .majVisite(
              id,
              (v) => v.copyWith(
                cmd: const CommandeLiee(
                  id: '2042',
                  ht: '1 540,00 €',
                  liv: '06/11/2026',
                ),
              ),
            );
        await tester.pumpAndSettle();
        expect(
          find.text('Commande #2042 : 1 540,00 € - 06/11/2026'),
          findsOneWidget,
        );
        expect(find.text('Aucune commande liée à cette visite.'), findsNothing);
      });

      testWidgets('« Commander » ouvre la prise de commande liée à la visite', (
        tester,
      ) async {
        final id = await brouillonPromoteur(tester, 'm1');
        await tester.tap(find.text('🛒 Commander'));
        await tester.pumpAndSettle();
        final ecran = tester.widget<PriseCommandeScreen>(
          find.byType(PriseCommandeScreen),
        );
        expect(ecran.magasinId, 'm1');
        expect(ecran.visiteId, id);
      });

      testWidgets(
        '« Terminer la visite » d’un brouillon vide liste ce qui manque',
        (tester) async {
          await brouillonPromoteur(tester, 'm1');
          await tester.tap(find.text('✓ Terminer la visite'));
          await tester.pumpAndSettle();
          expect(find.text('Visite incomplète'), findsOneWidget);
          expect(find.text('Il reste à faire :'), findsOneWidget);
          expect(find.text('Corriger'), findsOneWidget);
          expect(find.text('Valider'), findsNothing);
          // les 8 étapes à faire (hors début) puis la PEM : 9 lignes d'erreur
          expect(find.byType(MessageErreur), findsNWidgets(9));
          expect(
            find.text('Visite PEM (réalisée, ou raison de son absence)'),
            findsOneWidget,
          );
          await tester.tap(find.text('Corriger'));
          await tester.pumpAndSettle();
          expect(find.text('Visite incomplète'), findsNothing);
        },
      );

      testWidgets(
        'toucher une étape à saisir ouvre sa saisie, puis « Modifier »',
        (tester) async {
          final id = await brouillonPromoteur(tester, 'm1');
          await tester.tap(find.text('Vérification Promos'));
          await tester.pumpAndSettle();
          final ecran = tester.widget<SaisieEtapeScreen>(
            find.byType(SaisieEtapeScreen),
          );
          expect(ecran.etape, EtapeDph.promos);
          expect(ecran.visiteId, id);
          await tester.tap(find.byType(BoutonRetour));
          await tester.pumpAndSettle();
          conteneurApp(tester)
              .read(crmProvider.notifier)
              .majVisite(
                id,
                (v) => v.copyWith(
                  chrono: {...v.chrono, EtapeDph.promos: '04/11/2026 14h27'},
                ),
              );
          await tester.pumpAndSettle();
          expect(find.text('Modifier'), findsOneWidget);
          expect(find.text('04/11/2026 14h27'), findsOneWidget);
          expect(find.text('Saisir'), findsNWidgets(3));
        },
      );

      testWidgets('une visite terminée s’ouvre en compte rendu', (
        tester,
      ) async {
        await lancerApp(tester, Role.promoteur);
        AppRoutes.visite(contexteCoquille(tester), 'd0');
        await tester.pumpAndSettle();
        expect(find.byType(CompteRenduScreen), findsOneWidget);
        expect(find.text('Visite #218082'), findsOneWidget);
        expect(find.text('Terminer la visite'), findsNothing);
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
    },
  );
}
