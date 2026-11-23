import 'package:crm_app/core/data/fiche_client.dart';
import 'package:crm_app/core/data/referentiels_visite.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/fiche_client_provider.dart';
import 'package:crm_app/core/sync/referentiels_visite_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/visites/state/briefing_magasin.dart';
import 'package:crm_app/features/visites/widgets/briefing_visite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'aide_visites.dart';

const _alerteRetard = Alerte(
  niveau: NiveauAlerte.haut,
  magasinId: 'm1',
  icone: '🚚',
  titre: 'Carrefour Market – Versailles',
  classe: 'A++',
  detail: 'Livraison en retard : commande CDE-7 prévue le 12 nov.',
  rang: 1,
);

final _complet = BriefingMagasin(
  objectif: const ObjectifMois(ca: 1500, objectif: 2000),
  operations: const [
    OperationPromo('Remise -20 % soin', '2 nov.', '30 nov.', EtatOp.enCours),
    OperationPromo('Tête de gondole Noël', '1 déc.', '24 déc.', EtatOp.aVenir),
  ],
  alertes: const [_alerteRetard],
);

Override _briefing(BriefingMagasin b) =>
    briefingMagasinProvider.overrideWith((ref, id) => b);

/// Démarre une visite chez m1 (promoteur), écarte le kilométrage de départ.
Future<String> _demarrer(WidgetTester tester, List<Override> overrides) async {
  final id = await demarrerVisiteChez(
    tester,
    Role.promoteur,
    'm1',
    overrides: overrides,
  );
  await tester.tap(find.text('Plus tard'));
  await tester.pumpAndSettle();
  return id;
}

/// Valide la première étape et rouvre la visite : elle s'ouvre sur la deuxième.
Future<void> _rouvrirEtape2(WidgetTester tester, String id) async {
  conteneurApp(tester)
      .read(crmProvider.notifier)
      .majVisite(
        id,
        (v) => v.copyWith(
          chrono: {...v.chrono, EtapeDph.arrivee: '04/11/2026 14h30'},
        ),
      );
  await tester.pumpAndSettle();
  AppRoutes.retourRacine(contexteCoquille(tester));
  await tester.pumpAndSettle();
  AppRoutes.demarrerVisite(contexteCoquille(tester), 'm1');
  await tester.pumpAndSettle();
}

final _bloc = find.byType(BlocBriefing);

Finder _dansBloc(String texte) =>
    find.descendant(of: _bloc, matching: find.text(texte));

void main() {
  group('Briefing à l’ouverture de la visite', () {
    testWidgets(
      'déplié sur la première étape : objectifs, opérations, alertes',
      (tester) async {
        await _demarrer(tester, [_briefing(_complet)]);
        expect(find.text('Étape 1 / 7'), findsOneWidget);
        expect(_dansBloc('Briefing'), findsOneWidget);
        expect(_dansBloc('OBJECTIFS'), findsOneWidget);
        expect(_dansBloc('CA du mois / objectif mensuel'), findsOneWidget);
        expect(_dansBloc('75 %'), findsOneWidget);
        expect(_dansBloc('${eur(1500)} / ${eur(2000)}'), findsOneWidget);
        expect(_dansBloc('OPÉRATIONS À PROPOSER'), findsOneWidget);
        expect(_dansBloc('Remise -20 % soin'), findsOneWidget);
        expect(_dansBloc('2 nov. → 30 nov.'), findsOneWidget);
        expect(_dansBloc('En cours'), findsOneWidget);
        expect(_dansBloc('Tête de gondole Noël'), findsOneWidget);
        expect(_dansBloc('À venir'), findsOneWidget);
        expect(_dansBloc('ALERTES DU MAGASIN'), findsOneWidget);
        expect(_dansBloc(_alerteRetard.detail), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('replié après la première étape, il se rouvre au toucher', (
      tester,
    ) async {
      final id = await _demarrer(tester, [_briefing(_complet)]);
      await _rouvrirEtape2(tester, id);
      expect(find.text('Étape 2 / 7'), findsOneWidget);
      expect(_dansBloc('Briefing'), findsOneWidget);
      expect(_dansBloc('1 alerte'), findsOneWidget);
      expect(_dansBloc('OBJECTIFS'), findsNothing);

      await tester.tap(_dansBloc('Briefing'));
      await tester.pumpAndSettle();
      expect(_dansBloc('OBJECTIFS'), findsOneWidget);
      expect(_dansBloc('1 alerte'), findsNothing);

      // un toucher sur l'en-tête du bloc le replie
      await tester.tap(_dansBloc('Briefing'));
      await tester.pumpAndSettle();
      expect(_dansBloc('OBJECTIFS'), findsNothing);
    });

    testWidgets('« Suivant » replie le briefing de la première étape', (
      tester,
    ) async {
      final id = await _demarrer(tester, [_briefing(_complet)]);
      conteneurApp(tester)
          .read(crmProvider.notifier)
          .majVisite(
            id,
            (v) => v.copyWith(photos: const {EtapeDph.arrivee: 1}),
          );
      await tester.pumpAndSettle();
      expect(_dansBloc('OBJECTIFS'), findsOneWidget);
      await toucher(tester, find.text('Suivant ›'));
      expect(find.text('Étape 2 / 7'), findsOneWidget);
      expect(_dansBloc('OBJECTIFS'), findsNothing);
    });

    testWidgets('le bouton de l’en-tête ouvre la feuille à toute étape', (
      tester,
    ) async {
      final id = await _demarrer(tester, [_briefing(_complet)]);
      await _rouvrirEtape2(tester, id);
      // le bloc et la pastille de l'en-tête
      expect(find.text('Briefing'), findsNWidgets(2));
      await tester.tap(find.widgetWithText(Pastille, 'Briefing'));
      await tester.pumpAndSettle();
      expect(find.text('OBJECTIFS'), findsOneWidget);
      expect(find.text('Remise -20 % soin'), findsOneWidget);
      expect(find.text(_alerteRetard.detail), findsOneWidget);
      // fermer la feuille
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.text('OBJECTIFS'), findsNothing);
    });

    testWidgets('une rubrique sans contenu n’est pas affichée', (tester) async {
      await _demarrer(tester, [
        _briefing(
          const BriefingMagasin(
            objectif: ObjectifMois(ca: 500, objectif: 2000),
          ),
        ),
      ]);
      expect(_dansBloc('OBJECTIFS'), findsOneWidget);
      expect(_dansBloc('25 %'), findsOneWidget);
      expect(_dansBloc('OPÉRATIONS À PROPOSER'), findsNothing);
      expect(_dansBloc('ALERTES DU MAGASIN'), findsNothing);
    });

    testWidgets('sans objectif ni opération : seules les alertes', (
      tester,
    ) async {
      await _demarrer(tester, [
        _briefing(const BriefingMagasin(alertes: [_alerteRetard])),
      ]);
      expect(_dansBloc('ALERTES DU MAGASIN'), findsOneWidget);
      expect(_dansBloc('OBJECTIFS'), findsNothing);
      expect(_dansBloc('OPÉRATIONS À PROPOSER'), findsNothing);
    });

    testWidgets('tout vide : ni bloc ni bouton, le parcours reste normal', (
      tester,
    ) async {
      await _demarrer(tester, [_briefing(const BriefingMagasin())]);
      expect(_bloc, findsOneWidget);
      expect(find.text('Briefing'), findsNothing);
      expect(find.text("Photo d'arrivée sur site"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('démonstration : données fictives du magasin', (tester) async {
      await _demarrer(tester, []);
      expect(_dansBloc('OBJECTIFS'), findsOneWidget);
      expect(_dansBloc('OPÉRATIONS À PROPOSER'), findsOneWidget);
      expect(_dansBloc('ALERTES DU MAGASIN'), findsOneWidget);
      expect(
        _dansBloc('Client en baisse : CA -14 % sur un an'),
        findsOneWidget,
      );
    });
  });

  group('briefingMagasinProvider (magasin du CRM)', () {
    const reel = Magasin(
      id: 'c1',
      nom: 'Auchan – Rouen',
      statut: 'Client actif',
      classe: 'A',
      adresse: '',
      ca: '—',
      evo: '',
      cde: '—',
      cdeDate: '',
      visites: 0,
      objectif: 0,
      reel: true,
    );

    setUp(() {
      DemoTemps.reel = true;
      DemoTemps.maintenant = () => DateTime(2026, 11, 16);
    });
    tearDown(() {
      DemoTemps.reel = false;
      DemoTemps.maintenant = DateTime.now;
    });

    final fiche = FicheClient(
      contacts: const [],
      notes: const [],
      visites: const [],
      commandes: const [],
      visitesMois: 0,
      objectifAnnuel: 24000,
      caMois: 1500,
      derniereVisite: DateTime(2026, 10, 1),
      periodicite: '2 semaines',
      livraisons: [
        LivraisonAttendue(numero: 'CDE-9', prevue: DateTime(2026, 11, 16)),
      ],
      variationCaPct: -12,
    );

    /// Garde les providers vivants (ils se libèrent sans écouteur) pendant que le test attend leurs données.
    void garder(ProviderContainer c) {
      c.listen(briefingMagasinProvider('c1'), (_, _) {});
      c.listen(ficheClientProvider('c1'), (_, _) {});
      c.listen(promosBriefingProvider, (_, _) {});
    }

    ProviderContainer conteneur({
      Stream<FicheClient?>? fiches,
      List<PromoOp> promos = const [],
      List<Alerte> cloche = const [],
    }) {
      final c = ProviderContainer(
        overrides: [
          magasinParIdProvider.overrideWith((ref, id) => reel),
          alertesProvider.overrideWithValue(cloche),
          ficheClientProvider.overrideWith(
            (ref, id) => fiches ?? Stream<FicheClient?>.value(fiche),
          ),
          promosBriefingProvider.overrideWith((ref) => Stream.value(promos)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'objectif mensuel = annuel / 12, promotions triées, alertes du CRM',
      () async {
        final c = conteneur(
          promos: [
            PromoOp(id: 'b', libelle: 'À venir', debut: DateTime(2026, 12, 1)),
            PromoOp(id: 'a', libelle: 'En cours', fin: DateTime(2026, 12, 15)),
          ],
          cloche: [
            const Alerte(
              niveau: NiveauAlerte.haut,
              icone: '💬',
              titre: 'Relance visite',
              classe: '',
              detail: 'Julie · AUCHAN — ROUEN : visite non effectuée',
              rang: 5,
            ),
          ],
        );
        garder(c);
        await c.read(ficheClientProvider('c1').future);
        await c.read(promosBriefingProvider.future);
        final b = c.read(briefingMagasinProvider('c1'));
        expect(b.objectif!.objectif, 2000);
        expect(b.objectif!.ca, 1500);
        expect(b.objectif!.taux, 75);
        expect(b.operations.map((o) => o.nom), ['En cours', 'À venir']);
        expect(b.operations.map((o) => o.etat), [
          EtatOp.enCours,
          EtatOp.aVenir,
        ]);
        expect(b.alertes.map((a) => a.icone), ['💬', '📍', '🚚', '📉']);
        expect(b.vide, isFalse);
      },
    );

    test(
      'rien de chargé (hors ligne, sans copie) : briefing vide, pas d’erreur',
      () async {
        final c = conteneur(
          fiches: Stream<FicheClient?>.error(Exception('réseau')),
        );
        garder(c);
        await c.read(promosBriefingProvider.future);
        expect(c.read(briefingMagasinProvider('c1')).vide, isTrue);
        await Future<void>.delayed(Duration.zero);
        final b = c.read(briefingMagasinProvider('c1'));
        expect(b.objectif, isNull);
        expect(b.operations, isEmpty);
        expect(b.alertes, isEmpty);
        expect(b.vide, isTrue);
      },
    );

    test('magasin sans objectif de CA : pas de rubrique Objectifs', () async {
      final c = conteneur(
        fiches: Stream.value(
          FicheClient(
            contacts: const [],
            notes: const [],
            visites: const [],
            commandes: const [],
            visitesMois: 0,
            caMois: 800,
          ),
        ),
      );
      garder(c);
      await c.read(ficheClientProvider('c1').future);
      expect(c.read(briefingMagasinProvider('c1')).objectif, isNull);
    });
  });
}
