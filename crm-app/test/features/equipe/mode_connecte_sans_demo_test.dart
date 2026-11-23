import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/data/equipe_serveur.dart';
import 'package:crm_app/core/data/planning_serveur.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/crm_etat.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/accueil/accueil_screen.dart';
import 'package:crm_app/features/catalogue/data/news_serveur.dart';
import 'package:crm_app/features/equipe/chef_secteur_screen.dart';
import 'package:crm_app/features/equipe/equipe_screen.dart';
import 'package:crm_app/features/equipe/promoteur_screen.dart';
import 'package:crm_app/features/equipe/secteur_screen.dart';
import 'package:crm_app/features/planning/planning_screen.dart';
import 'package:crm_app/features/prospects/logic/vue_prospects.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Session réelle : aucune donnée de démonstration là où le CRM n'a rien (encore) donné ; la démonstration reste intacte.

final _utilisateur = Utilisateur(
  id: 'moi',
  identifiant: 'x',
  nomAffiche: 'Jean DUPONT',
  email: null,
  roleApi: 'CHEF_SECTEUR',
);

Map<String, dynamic> _carte() => {
  'regions': [
    {
      'nom': 'Nord',
      'stats': {'visites': 3, 'commandes': 2, 'ca': 900, 'objectif': 1500},
      'chefsSecteur': [
        {
          'id': 'cs1',
          'displayName': 'Jean DUPONT',
          'secteur': {'nom': 'Picardie'},
          'visites': 3,
          'commandes': 2,
          'ca': 900,
          'objectif': 1500,
          'promoteurs': [
            {
              'id': 'p1',
              'displayName': 'Marie CURIE',
              'nbClients': 4,
              'visites': 3,
              'commandes': 2,
              'ca': 900,
              'objectif': 1500,
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  setUp(() {
    DemoTemps.maintenant = () => DateTime(2026, 11, 4, 10);
  });

  tearDown(() {
    DemoTemps.maintenant = DateTime.now;
    DemoTemps.reel = false;
    definirEquipeServeur(null);
  });

  group('accesseurs de l’équipe', () {
    test('démonstration : l’équipe fictive est servie', () {
      expect(chefsActuels().map((c) => c.id), ['n', 'k', 's']);
      expect(promoteursDuChef('n'), isNotEmpty);
      expect(promoteursTous(), isNotEmpty);
      expect(promoteursDeMonEquipe(), isNotEmpty);
      expect(totalEquipe(chefSecteur: false).cible, greaterThan(0));
    });

    test('session réelle sans équipe téléchargée : tout est vide', () {
      DemoTemps.reel = true;
      expect(chefsActuels(), isEmpty);
      expect(promoteursDuChef('n'), isEmpty);
      expect(promoteursTous(), isEmpty);
      expect(promoteursDeMonEquipe(), isEmpty);
      expect(promoteurActuelParNom('Julien M.'), isNull);
      expect(chefActuelParId('n'), isNull);
      expect(totalEquipe(chefSecteur: true).real, 0);
      expect(totalEquipe(chefSecteur: false).cible, 0);
    });

    test('session réelle avec équipe téléchargée : celle du CRM', () {
      DemoTemps.reel = true;
      definirEquipeServeur(equipeDepuisJson(_carte()));
      expect(chefsActuels().map((c) => c.id), ['cs1']);
      expect(promoteursDeMonEquipe().single.nom, 'Marie CURIE');
      expect(totalEquipe(chefSecteur: true).real, 900);
    });
  });

  group('état du store', () {
    test('démonstration : les données fictives du profil', () {
      final e = CrmEtat.initial(Role.dir);
      expect(e.magasins, isNotEmpty);
      expect(e.tousMagasins, isNotEmpty);
      expect(e.prospects, isNotEmpty);
      expect(e.commandes, isNotEmpty);
      expect(e.visites, isNotEmpty);
      expect(e.etapes, isNotEmpty);
      expect(e.nomProfil, 'Cindy R.');
      expect(e.magasinParId(autresClients.first.id), isNotNull);
      expect(autresClientsActuels(), isNotEmpty);
    });

    test('session réelle, rien de téléchargé : aucune donnée fictive', () {
      DemoTemps.reel = true;
      final e = CrmEtat.initial(Role.dir, nomUtilisateur: 'Jean DUPONT');
      expect(e.magasins, isEmpty);
      expect(e.tousMagasins, isEmpty);
      expect(e.prospects, isEmpty);
      expect(e.commandes, isEmpty);
      expect(e.visites, isEmpty);
      expect(e.visitesAutres, isEmpty);
      expect(e.etapes, isEmpty);
      expect(e.tournee, isEmpty);
      expect(e.plansEquipe, isEmpty);
      expect(e.magasinParId(autresClients.first.id), isNull);
      expect(autresClientsActuels(), isEmpty);
      expect(e.nomProfil, 'Jean DUPONT');
      expect(e.copyWith().nomProfil, 'Jean DUPONT');
    });
  });

  group('autres référentiels', () {
    test('actualités, catalogue et kits', () {
      expect(newsActuelles(), isNotEmpty);
      expect(tousProduits(), isNotEmpty);
      expect(produitsCommandables(), isNotEmpty);
      expect(marquesCatalogueActuelles(), isNotEmpty);
      DemoTemps.reel = true;
      expect(newsActuelles(), isEmpty);
      expect(tousProduits(), isEmpty);
      expect(produitsCommandables(), isEmpty);
      expect(marquesCatalogueActuelles(), isEmpty);
    });

    test(
      'auteur d’une commande : celui du CRM, jamais le promoteur de démo',
      () {
        const sansAuteur = Commande(
          id: 'C1',
          magasinId: 'm1',
          date: '3 nov.',
          ht: '10,00 €',
          lignes: 1,
          statut: StatutLivraison.pasLivree,
          eta: '',
          colis: 0,
          evenements: [],
        );
        expect(auteurCommande(sansAuteur), 'Julien M.');
        DemoTemps.reel = true;
        expect(auteurCommande(sansAuteur), isNull);
        expect(
          auteurCommande(
            Commande(
              id: 'C2',
              magasinId: 'm1',
              date: '3 nov.',
              ht: '10,00 €',
              lignes: 1,
              statut: StatutLivraison.pasLivree,
              eta: '',
              colis: 0,
              evenements: const [],
              auteurNom: 'Marie CURIE',
            ),
          ),
          'Marie CURIE',
        );
      },
    );

    test('« mes prospects » : confiés à l’utilisateur du CRM', () {
      final p = Prospect(
        id: 'p',
        nom: 'Auchan',
        raison: 'Auchan',
        classe: 'B',
        cp: '80000 Amiens',
        statut: StatutProspect.nouveau,
        pot: 10,
        proba: 10,
        timeline: const [],
        cs: 'Jean DUPONT',
      );
      expect(estMonProspect(p, 'Jean DUPONT'), isFalse);
      expect(estMonProspect(p, 'Jean DUPONT', responsableCrm: true), isTrue);
      expect(estMonProspect(p, 'Autre', responsableCrm: true), isFalse);
    });
  });

  group('écrans en session réelle', () {
    // L'application lit la session dès le lancement : ici, on pose le mode réel avant de monter l'écran.
    setUp(() => DemoTemps.reel = true);

    final session = [
      sessionProvider.overrideWith(() => SessionNotifier(_utilisateur)),
    ];

    testWidgets('Mon équipe (chef de secteur) : aucun promoteur de démo', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const EquipeScreen(),
        role: Role.cs,
        overrides: session,
      );
      expect(find.textContaining('0 promoteurs'), findsOneWidget);
      expect(find.text('Julien M.'), findsNothing);
      expect(find.text('Léa P.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mon équipe (directeur) : aucun chef de secteur de démo', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const EquipeScreen(),
        role: Role.dir,
        overrides: session,
      );
      expect(
        find.text('Aucun chef de secteur pour ce filtre.'),
        findsOneWidget,
      );
      expect(find.text('Nadia H.'), findsNothing);
      expect(find.text('Karim B.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mon équipe (directeur) : équipe du CRM', (tester) async {
      definirEquipeServeur(equipeDepuisJson(_carte()));
      await pumpEcran(
        tester,
        const EquipeScreen(),
        role: Role.dir,
        overrides: session,
      );
      expect(find.text('Jean DUPONT'), findsOneWidget);
      expect(find.text('Nadia H.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Visites du secteur : aucune visite de démo', (tester) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.visites),
        role: Role.cs,
        overrides: session,
      );
      expect(find.text('Aucun résultat avec ces filtres.'), findsOneWidget);
      expect(find.textContaining('· Julien M.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Commandes du secteur : aucune commande de démo', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.commandes),
        role: Role.cs,
        overrides: session,
      );
      expect(find.text('Aucun résultat avec ces filtres.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('page d’un chef de secteur ou d’un promoteur inconnu', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const ChefSecteurScreen(csId: 'n'),
        role: Role.dir,
        overrides: session,
      );
      expect(find.text('Chef de secteur introuvable.'), findsOneWidget);
      await pumpEcran(
        tester,
        const PromoteurScreen(csId: 'n', nom: 'Julien M.'),
        role: Role.dir,
        overrides: session,
      );
      expect(find.text('Promoteur introuvable.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accueil du chef de secteur : CA et objectif à zéro', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const AccueilScreen(),
        role: Role.cs,
        overrides: session,
      );
      final demo = totalObjectif(promoteursParChef['n']!);
      expect(find.text(eur(demo.real)), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Tuile &&
              w.libelle.startsWith('CA / objectif') &&
              w.valeur == eur(0),
        ),
        findsOneWidget,
      );
      expect(find.text('Carrefour – Paris'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('planning en session réelle', () {
    setUp(() => DemoTemps.reel = true);
    tearDown(() {
      definirPlanningServeur(null);
      definirRapportsServeur(null);
    });

    testWidgets('prévision sans date du CRM : aucune date ni heure inventée', (
      tester,
    ) async {
      final lundi = DateTime(2026, 11, 2);
      definirPlanningServeur(planningDepuisJson(const [], lundi));
      definirRapportsServeur(
        rapportsDepuisJson({
          'semaine': {
            'semaine': '2026-11-02',
            'phase': 'RAPPORT',
            'prevuAt': null,
            'verrouillee': false,
          },
          'prevue': {
            'prevue': [
              {
                'jour': '2026-11-03',
                'heure': '10:00',
                'adm': false,
                'clientId': 'c1',
                'prospectId': null,
                'libelle': null,
                'titre': 'Carrefour',
                'ville': 'Ivry',
                'adresse': null,
                'visiteSimple': true,
                'accompagnement': false,
                'rdv': false,
                'soireeEtape': false,
                'soireeLieu': null,
                'soireeAdresse': null,
                'note': null,
                'fait': false,
              },
            ],
          },
          'historique': {'semaines': const <Object>[]},
        }, lundi),
      );
      await pumpEcran(
        tester,
        const PlanningScreen(),
        role: Role.cs,
        overrides: [
          sessionProvider.overrideWith(() => SessionNotifier(_utilisateur)),
        ],
      );
      expect(find.text('Prévision figée (1 ligne).'), findsOneWidget);
      expect(find.textContaining('09:10'), findsNothing);
      expect(find.textContaining('lun. 2 nov.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('démonstration inchangée', () {
    testWidgets('Mon équipe (chef de secteur) : Nadia H. et ses promoteurs', (
      tester,
    ) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.cs);
      expect(find.text('3 promoteurs · Île-de-France'), findsOneWidget);
      expect(find.text('Julien M.'), findsOneWidget);
    });
  });
}
