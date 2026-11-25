import 'package:crm_app/core/data/planning_serveur.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:crm_app/features/clients/fiche_magasin_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../../support/faux_ecriture.dart';

/// Conteneur dont la synchro du planning est factice : elle laisserait sinon le planning de test à null.
ProviderContainer _conteneur(Role role) {
  final c = ProviderContainer(
    overrides: [
      roleProvider.overrideWith(() => RoleNotifier(role)),
      planningSynchroProvider.overrideWith(PlanningSynchroFaux.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Visite lancée hors de « Ma tournée du jour » (fiche magasin…) : rattachée à l'étape prévue du jour chez ce magasin.

const _p1 = '66666666-6666-4666-8666-666666666661';
const _p2 = '66666666-6666-4666-8666-666666666662';
const _p3 = '66666666-6666-4666-8666-666666666663';

TourneeVisite _t(String id, String magasin, [String heure = '09:00']) =>
    TourneeVisite(id: id, magasinId: magasin, heure: heure, type: 'Planifiée');

EtapePlanning _e(String id, String magasin, {bool fait = false}) =>
    EtapePlanning(
      id: id,
      jour: 2,
      heure: '',
      cible: CiblePlanning.client,
      ref: magasin,
      titre: 'Client',
      fait: fait,
      sem: 0,
    );

void main() {
  group('planningIdDuJour', () {
    test('étape du CRM chez ce magasin, pas encore faite', () {
      expect(
        planningIdDuJour(
          tournee: [_t(_p1, 'm1')],
          lignes: [_e(_p1, 'm1')],
          magasinId: 'm1',
        ),
        _p1,
      );
    });

    test('un autre magasin, ou aucune étape : rien', () {
      expect(
        planningIdDuJour(
          tournee: [_t(_p1, 'm2')],
          lignes: [_e(_p1, 'm2')],
          magasinId: 'm1',
        ),
        isNull,
      );
      expect(
        planningIdDuJour(tournee: const [], lignes: const [], magasinId: 'm1'),
        isNull,
      );
    });

    test('étape déjà faite : ignorée', () {
      expect(
        planningIdDuJour(
          tournee: [_t(_p1, 'm1')],
          lignes: [_e(_p1, 'm1', fait: true)],
          magasinId: 'm1',
        ),
        isNull,
      );
    });

    test('plusieurs étapes : la première non faite', () {
      final tournee = [_t(_p1, 'm1', '08:00'), _t(_p2, 'm1', '10:00')];
      expect(
        planningIdDuJour(
          tournee: tournee,
          lignes: [_e(_p1, 'm1'), _e(_p2, 'm1')],
          magasinId: 'm1',
        ),
        _p1,
      );
      expect(
        planningIdDuJour(
          tournee: tournee,
          lignes: [_e(_p1, 'm1', fait: true), _e(_p2, 'm1')],
          magasinId: 'm1',
        ),
        _p2,
      );
    });

    test('identifiant de démonstration (pas un UUID) : aucun lien', () {
      expect(
        planningIdDuJour(
          tournee: [_t('v2', 'm1')],
          lignes: const [],
          magasinId: 'm1',
        ),
        isNull,
      );
    });

    test('une étape de la tournée absente des lignes compte comme à faire', () {
      expect(
        planningIdDuJour(
          tournee: [_t(_p3, 'm1')],
          lignes: const [],
          magasinId: 'm1',
        ),
        _p3,
      );
    });
  });

  group('demarrerVisite', () {
    setUp(() {
      definirPlanningServeur(
        PlanningServeur(
          etapes: [_e(_p1, 'm1', fait: true), _e(_p2, 'm1'), _e(_p3, 'm2')],
          tournee: [_t(_p1, 'm1', '08:00'), _t(_p2, 'm1'), _t(_p3, 'm2')],
        ),
      );
    });
    tearDown(() => definirPlanningServeur(null));

    String? lien(ProviderContainer c, String visite) => c
        .read(crmProvider)
        .visites
        .firstWhere((v) => v.id == visite)
        .planningId;

    test('sans planningId : l\'étape du jour du magasin est retrouvée', () {
      final c = _conteneur(Role.promoteur);
      final n = c.read(crmProvider.notifier);
      expect(lien(c, n.demarrerVisite('m1')), _p2);
      expect(lien(c, n.demarrerVisite('m2')), _p3);
    });

    test('magasin sans étape du jour : pas de lien', () {
      final c = _conteneur(Role.promoteur);
      final n = c.read(crmProvider.notifier);
      expect(lien(c, n.demarrerVisite('m5')), isNull);
    });

    test('un planningId donné (tournée du jour) l\'emporte', () {
      final c = _conteneur(Role.promoteur);
      final n = c.read(crmProvider.notifier);
      expect(lien(c, n.demarrerVisite('m1', planningId: _p1)), _p1);
    });

    test('démonstration : aucune étape à identifiant UUID, aucun lien', () {
      definirPlanningServeur(null);
      final c = _conteneur(Role.promoteur);
      final n = c.read(crmProvider.notifier);
      expect(lien(c, n.demarrerVisite('m1')), isNull);
      expect(lien(c, n.demarrerVisite('m4')), isNull);
    });
  });

  testWidgets('« Démarrer une visite » de la fiche magasin rattache l\'étape', (
    tester,
  ) async {
    definirPlanningServeur(
      PlanningServeur(etapes: [_e(_p2, 'm1')], tournee: [_t(_p2, 'm1')]),
    );
    addTearDown(() => definirPlanningServeur(null));
    await pumpEcran(
      tester,
      const FicheMagasinScreen(magasinId: 'm1'),
      overrides: [
        planningSynchroProvider.overrideWith(PlanningSynchroFaux.new),
      ],
    );
    final c = ProviderScope.containerOf(
      tester.element(find.byType(FicheMagasinScreen)),
    );
    await tester.tap(find.text('Démarrer une visite'));
    await tester.pumpAndSettle();
    final brouillons = c
        .read(crmProvider)
        .visites
        .where((v) => v.etat == EtatVisite.brouillon && v.magasinId == 'm1');
    expect(brouillons.map((v) => v.planningId), contains(_p2));
  });
}
