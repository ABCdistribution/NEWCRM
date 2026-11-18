import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/planning_serveur.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/features/planning/mes_rapports_screen.dart';
import 'package:crm_app/features/planning/planning_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Écrans de planning alimentés par le CRM : « Mon planning » semaine par semaine, lecture seule, « Mes rapports ».

final _lundi = DateTime(2026, 11, 2);

Map<String, dynamic> _etape(
  String id,
  String date,
  Map<String, dynamic> cible, {
  bool prospect = false,
  bool fait = false,
}) => {
  'id': id,
  'adm': false,
  'libelle': null,
  'adresse': null,
  'datePassage': date,
  'fait': fait,
  'note': null,
  'visiteSimple': true,
  'accompagnement': false,
  'rdv': false,
  'soireeEtape': false,
  'client': prospect ? null : cible,
  'prospect': prospect ? cible : null,
};

final _utilisateur = Utilisateur(
  id: 'moi',
  identifiant: 'x',
  nomAffiche: 'Jean DUPONT',
  email: null,
  roleApi: 'CHEF_SECTEUR',
);

void main() {
  setUp(() {
    DemoTemps.maintenant = () => DateTime(2026, 11, 4, 10);
    DemoTemps.reel = true;
    definirPlanningServeur(
      planningDepuisJson([
        _etape('e1', '2026-11-04T11:00:00.000Z', {
          'id': 'c1',
          'enseigne': 'Carrefour',
          'ville': 'Ivry',
        }, fait: true),
        _etape('e2', '2026-11-09T14:00:00.000Z', {
          'id': 'p1',
          'enseigne': 'Auchan',
          'ville': 'Rouen',
        }, prospect: true),
      ], _lundi),
    );
    definirRapportsServeur(
      rapportsDepuisJson({
        'semaine': {
          'semaine': '2026-11-02',
          'phase': 'RAPPORT',
          'prevuAt': '2026-11-02T08:10:00.000Z',
          'verrouillee': false,
        },
        'prevue': {'prevue': const <Object>[]},
        'historique': {
          'semaines': [
            {
              'semaine': '2026-10-26',
              'numero': 44,
              'statut': 'VALIDE_AUTO',
              'valideAt': '2026-11-02T03:00:00.000Z',
              'valideAuto': true,
              'nbPrevues': 15,
              'nbLignes': 14,
              'visites': 14,
              'rdv': 4,
              'pourcentPrevu': 93,
            },
          ],
        },
      }, _lundi),
    );
  });

  tearDown(() {
    DemoTemps.maintenant = DateTime.now;
    DemoTemps.reel = false;
    definirPlanningServeur(null);
    definirRapportsServeur(null);
  });

  final surcharges = [
    sessionProvider.overrideWith(() => SessionNotifier(_utilisateur)),
  ];

  testWidgets('Mon planning : semaine courante du CRM, lecture seule', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      const PlanningScreen(),
      role: Role.cs,
      overrides: surcharges,
    );
    expect(find.text('Semaine 45 · 2 – 6 novembre'), findsOneWidget);
    expect(find.text('Rapport en cours'), findsOneWidget);
    // Mercredi : la ligne du CRM, faite ; aucune ligne de la démonstration.
    expect(find.text('Carrefour – Ivry'), findsOneWidget);
    expect(find.text('Fait ✓'), findsOneWidget);
    expect(find.text('Administratif'), findsNothing);
    // Rien ne repart vers le CRM : ni bouton « + », ni prévision à enregistrer.
    expect(find.bySemanticsLabel('Ajouter un RDV'), findsNothing);
    expect(find.text('Enregistrer la prévision'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mon planning : la flèche passe à la semaine suivante', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      const PlanningScreen(),
      role: Role.cs,
      overrides: surcharges,
    );
    await tester.tap(find.bySemanticsLabel('Semaine suivante'));
    await tester.pumpAndSettle();
    expect(find.text('Semaine 46 · 9 – 13 novembre'), findsOneWidget);
    expect(find.text('Planning de la semaine'), findsOneWidget);
    expect(find.text('Carrefour – Ivry'), findsNothing);
    await tester.tap(find.text('Lun'));
    await tester.pumpAndSettle();
    expect(find.text('Auchan – Rouen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mes rapports : l’historique du CRM', (tester) async {
    await pumpEcran(
      tester,
      const MesRapportsScreen(),
      role: Role.cs,
      overrides: surcharges,
    );
    expect(find.text('Semaine 45 · en cours'), findsOneWidget);
    expect(find.text('Semaine 44'), findsOneWidget);
    expect(find.text('26 – 30 octobre'), findsOneWidget);
    expect(find.text('14 visites'), findsOneWidget);
    expect(find.text('93 % du prévu'), findsOneWidget);
    expect(find.text('Validé auto'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    // Les semaines de la démonstration ne s'y mêlent pas.
    expect(find.text('Semaine 43'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
