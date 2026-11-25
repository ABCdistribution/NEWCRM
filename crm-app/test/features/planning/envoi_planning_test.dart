import 'dart:async';

import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/equipe_serveur.dart';
import 'package:crm_app/core/data/magasins_demo.dart';
import 'package:crm_app/core/data/prospects_serveur.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/planning/formulaire_rdv_sheet.dart';
import 'package:crm_app/features/planning/logic/envoi_planning.dart';
import 'package:crm_app/features/planning/planning_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../../support/faux_ecriture.dart';

/// Envoi d'une ligne de planning au CRM : `POST /tournees` (son planning) et `POST /plannings` (visite pour un
/// promoteur). Connecté seulement : la démonstration garde le store local.

const _client = '11111111-1111-4111-8111-111111111111';
const _prospect = '22222222-2222-4222-8222-222222222222';
const _promoteur = '33333333-3333-4333-8333-333333333333';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Utilisateur _moi(String role) => Utilisateur(
  id: 'moi',
  identifiant: 'x',
  nomAffiche: 'Jean DUPONT',
  email: null,
  roleApi: role,
);

const _magasin = Magasin(
  id: _client,
  nom: 'Carrefour – Ivry',
  statut: 'Client actif',
  classe: 'B',
  adresse: '1 rue A',
  ca: '—',
  evo: '',
  cde: '—',
  cdeDate: '',
  visites: 0,
  objectif: 0,
  reel: true,
);

final _prospectReel = Prospect(
  id: _prospect,
  nom: 'Auchan – Rouen',
  raison: 'AUCHAN SAS',
  classe: 'C',
  cp: '76000 Rouen',
  statut: StatutProspect.nouveau,
  pot: 10,
  proba: 10,
  timeline: const [],
);

/// Monte « Mon planning » connecté (mercredi 4 novembre 2026) avec le faux serveur.
Future<(FauxEcriture, PlanningSynchroFaux)> _monter(
  WidgetTester tester, {
  Role role = Role.cs,
  String roleApi = 'CHEF_SECTEUR',
  bool avecEquipe = false,
}) async {
  DemoTemps.maintenant = () => DateTime(2026, 11, 4, 10);
  DemoTemps.reel = true;
  definirClientsServeur([_magasin]);
  definirProspectsServeur([_prospectReel]);
  if (avecEquipe) {
    definirEquipeServeur(
      EquipeServeur(
        chefs: const [],
        parChef: {
          'cs1': [
            Promoteur(
              nom: 'Alice MARTIN',
              ini: 'AM',
              mag: 1,
              v: 0,
              p: 0,
              real: 0,
              cible: 0,
              jour: const [],
              reel: true,
              userId: _promoteur,
            ),
          ],
        },
        total: const TotalObjectif(0, 0),
        visites: 0,
        commandes: 0,
      ),
    );
  }
  addTearDown(() {
    DemoTemps.maintenant = DateTime.now;
    DemoTemps.reel = false;
    definirClientsServeur(null);
    definirProspectsServeur(null);
    definirEquipeServeur(null);
  });
  final ecriture = FauxEcriture();
  final planning = PlanningSynchroFaux();
  await pumpEcran(
    tester,
    const PlanningScreen(),
    role: role,
    overrides: [
      sessionProvider.overrideWith(() => SessionNotifier(_moi(roleApi))),
      apiEcritureProvider.overrideWithValue(ecriture),
      planningSynchroProvider.overrideWith(() => planning),
    ],
  );
  return (ecriture, planning);
}

Future<void> _ouvrir(
  WidgetTester tester, {
  CiblePlanning? cible,
  String? ref,
  bool depuisFiche = false,
  String? planCible,
}) async {
  final ctx = tester.element(find.byType(PlanningScreen, skipOffstage: false));
  AppRoutes.formulaireRdv(
    ctx,
    cible: cible,
    ref: ref,
    depuisFiche: depuisFiche,
    planCible: planCible,
  );
  await tester.pumpAndSettle();
}

Finder _dans(String texte) => find.descendant(
  of: find.byType(FormulaireRdvSheet),
  matching: find.text(texte),
);

Future<void> _toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _choisir(WidgetTester tester, String actuel, String option) async {
  await _toucher(tester, _dans(actuel));
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _ecrire(WidgetTester tester, String label, String texte) async {
  final colonne = find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .first;
  final champ = find.descendant(
    of: colonne,
    matching: find.byType(TextFormField),
  );
  await tester.ensureVisible(champ);
  await tester.enterText(champ, texte);
  await tester.pump();
}

Future<void> _ajouter(
  WidgetTester tester, [
  String bouton = 'Ajouter la ligne',
]) => _toucher(tester, find.text(bouton));

void main() {
  group('fonctions pures', () {
    test('idApk : un UUID v4, différent à chaque tirage', () {
      final a = genererIdApkUuid();
      expect(a, matches(_uuid));
      expect(genererIdApkUuid(), isNot(a));
    });

    test('datePassage : date seule ou date et heure sans fuseau', () {
      final lundi = DateTime(2026, 11, 2);
      expect(datePassageApi(lundi: lundi, semaine: 0, jour: 2), '2026-11-04');
      expect(
        datePassageApi(lundi: lundi, semaine: 0, jour: 2, heure: '09:30'),
        '2026-11-04T09:30',
      );
      expect(
        datePassageApi(lundi: lundi, semaine: 0, jour: 2, heure: '9:05'),
        '2026-11-04T09:05',
      );
      // Semaine suivante, à cheval sur deux mois ; l'heure est ignorée pour une visite de promoteur.
      expect(
        datePassageApi(
          lundi: lundi,
          semaine: 4,
          jour: 4,
          heure: '14:00',
          avecHeure: false,
        ),
        '2026-12-04',
      );
      expect(
        datePassageApi(lundi: DateTime(2026, 12, 28), semaine: 0, jour: 4),
        '2027-01-01',
      );
    });

    test('corps de /tournees : une seule cible, types de visite et soirée', () {
      const base = EtapePlanning(
        id: 'e',
        jour: 0,
        heure: '',
        cible: CiblePlanning.client,
        ref: _client,
        titre: 'x',
        visite: false,
        acc: true,
        soiree: true,
        soireeLieu: ' Hôtel ',
        soireeAdr: '2 rue B',
        note: ' À voir ',
      );
      final client = corpsTournee(
        base,
        idApk: 'I',
        datePassage: '2026-11-02T08:00',
        adresse: ' 3 rue C ',
      );
      expect(client, {
        'idApk': 'I',
        'datePassage': '2026-11-02T08:00',
        'clientId': _client,
        'adresse': '3 rue C',
        'note': 'À voir',
        'visiteSimple': false,
        'accompagnement': true,
        'rdv': false,
        'appel': false,
        'remplacement': false,
        'soireeEtape': true,
        'soireeLieu': 'Hôtel',
        'soireeAdresse': '2 rue B',
      });
      final prospect = corpsTournee(
        base.copyWith(cible: CiblePlanning.prospect, ref: _prospect),
        idApk: 'I',
        datePassage: '2026-11-02',
      );
      expect(prospect['prospectId'], _prospect);
      expect(prospect.containsKey('clientId'), isFalse);
      final libre = corpsTournee(
        base.copyWith(cible: CiblePlanning.libre, titre: ' Chez Marcel '),
        idApk: 'I',
        datePassage: '2026-11-02',
      );
      expect(libre['libelle'], 'Chez Marcel');
      expect(libre.keys, isNot(containsAll(['clientId', 'prospectId'])));
      final adm = corpsTournee(
        base.copyWith(cible: CiblePlanning.adm),
        idApk: 'I',
        datePassage: '2026-11-02',
        adresse: 'ignorée',
      );
      expect(adm, {
        'idApk': 'I',
        'datePassage': '2026-11-02',
        'adm': true,
        'note': 'À voir',
      });
    });

    test('corps de /plannings : promoteur, client, jour, consigne', () {
      expect(
        corpsPlanning(
          idApk: 'I',
          promoteurId: _promoteur,
          clientId: _client,
          datePassage: '2026-11-04',
          note: ' Refaire le rayon ',
        ),
        {
          'idApk': 'I',
          'promoteurId': _promoteur,
          'clientId': _client,
          'datePassage': '2026-11-04',
          'note': 'Refaire le rayon',
        },
      );
      expect(
        corpsPlanning(
          idApk: 'I',
          promoteurId: _promoteur,
          clientId: _client,
          datePassage: '2026-11-04',
        ).containsKey('note'),
        isFalse,
      );
    });

    test('messages : celui de l\'API, sinon un texte selon le statut', () {
      expect(
        messageErreurPlanning(
          const ErreurApi(
            TypeErreurApi.inattendue,
            statut: 409,
            detail: 'Semaine validée.',
          ),
          pourPromoteur: false,
        ),
        'Semaine validée.',
      );
      expect(
        messageErreurPlanning(
          const ErreurApi(TypeErreurApi.inattendue, statut: 409),
          pourPromoteur: true,
        ),
        'Une visite est déjà planifiée ce jour chez ce client.',
      );
      expect(
        messageErreurPlanning(
          const ErreurApi(TypeErreurApi.reseau),
          pourPromoteur: false,
        ),
        'Serveur injoignable. Vérifiez votre connexion.',
      );
    });
  });

  group('son propre planning : POST /tournees', () {
    testWidgets(
      'client par défaut : corps, fermeture et relecture du planning',
      (tester) async {
        final (ecriture, planning) = await _monter(tester);
        await _ouvrir(tester);
        expect(find.byType(FormulaireRdvSheet), findsOneWidget);
        await _ajouter(tester);
        expect(ecriture.appels, hasLength(1));
        expect(ecriture.appels.single.methode, 'POST');
        expect(ecriture.appels.single.chemin, '/tournees');
        final c = ecriture.corps(0);
        expect(c['idApk'], matches(_uuid));
        expect(c['datePassage'], '2026-11-04');
        expect(c['clientId'], _client);
        expect(c['visiteSimple'], isTrue);
        expect(c['accompagnement'], isFalse);
        expect(c['soireeEtape'], isFalse);
        expect(c.keys, isNot(contains('prospectId')));
        expect(c.keys, isNot(contains('libelle')));
        expect(c.keys, isNot(contains('adm')));
        expect(c.keys, isNot(contains('note')));
        expect(planning.rafraichis, 1);
        expect(find.byType(FormulaireRdvSheet), findsNothing);
        // Rien n'est ajouté au store local : la ligne viendra du CRM.
        final conteneur = ProviderScope.containerOf(
          tester.element(find.byType(PlanningScreen)),
        );
        expect(conteneur.read(crmProvider).etapes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('le jour choisi et la semaine affichée font la date', (
      tester,
    ) async {
      final (ecriture, _) = await _monter(tester);
      await tester.tap(find.bySemanticsLabel('Semaine suivante'));
      await tester.pumpAndSettle();
      await _ouvrir(tester);
      // La liste des jours propose les dates de la semaine affichée.
      expect(_dans('Mer 11 nov.'), findsOneWidget);
      await _choisir(tester, 'Mer 11 nov.', 'Ven 13 nov.');
      await _ajouter(tester);
      expect(ecriture.corps(0)['datePassage'], '2026-11-13');
    });

    testWidgets('prospect, type RDV et observations', (tester) async {
      final (ecriture, _) = await _monter(tester);
      await _ouvrir(tester);
      await _toucher(tester, _dans('Prospect'));
      await _choisir(tester, 'Visite simple', 'RDV');
      await _ecrire(tester, 'Observations', 'Apporter le catalogue');
      await _ajouter(tester);
      final c = ecriture.corps(0);
      expect(c['prospectId'], _prospect);
      expect(c.keys, isNot(contains('clientId')));
      expect(c['rdv'], isTrue);
      expect(c['visiteSimple'], isFalse);
      expect(c['note'], 'Apporter le catalogue');
    });

    testWidgets('chaque type de visite pose son indicateur', (tester) async {
      final attendu = {
        'Accompagnement': 'accompagnement',
        'Appel téléphonique': 'appel',
        'Visite de remplacement': 'remplacement',
      };
      for (final e in attendu.entries) {
        final (ecriture, _) = await _monter(tester);
        await _ouvrir(tester);
        await _choisir(tester, 'Visite simple', e.key);
        await _ajouter(tester);
        final c = ecriture.corps(0);
        for (final k in [
          'visiteSimple',
          'accompagnement',
          'rdv',
          'appel',
          'remplacement',
        ]) {
          expect(c[k], k == e.value, reason: '${e.key} : $k');
        }
      }
    });

    testWidgets('ligne libre avec adresse : libellé, sans client ni prospect', (
      tester,
    ) async {
      final (ecriture, _) = await _monter(tester);
      await _ouvrir(tester);
      await _toucher(tester, _dans('Libre'));
      await _ecrire(tester, 'Client ou lieu', 'Chez Marcel');
      await _ecrire(tester, 'Adresse (facultatif)', '4 rue D, Lyon');
      await _ajouter(tester);
      final c = ecriture.corps(0);
      expect(c['libelle'], 'Chez Marcel');
      expect(c['adresse'], '4 rue D, Lyon');
      expect(c.keys, isNot(contains('clientId')));
      expect(c.keys, isNot(contains('prospectId')));
      expect(c.keys, isNot(contains('adm')));
    });

    testWidgets('ligne administrative : adm sans cible ni type', (
      tester,
    ) async {
      final (ecriture, _) = await _monter(tester);
      await _ouvrir(tester);
      await _toucher(tester, _dans('ADM'));
      await _ajouter(tester);
      final c = ecriture.corps(0);
      expect(c['adm'], isTrue);
      for (final k in ['clientId', 'prospectId', 'libelle', 'visiteSimple']) {
        expect(c.keys, isNot(contains(k)), reason: k);
      }
    });

    testWidgets('soirée étape : lieu et adresse envoyés', (tester) async {
      final (ecriture, _) = await _monter(tester);
      await _ouvrir(tester);
      await _toucher(tester, _dans('Soirée étape'));
      await _ecrire(
        tester,
        'Lieu de la soirée étape (obligatoire)',
        'Hôtel du Parc',
      );
      await _ecrire(
        tester,
        'Adresse de la soirée étape (obligatoire)',
        '5 avenue E',
      );
      await _ajouter(tester);
      final c = ecriture.corps(0);
      expect(c['soireeEtape'], isTrue);
      expect(c['soireeLieu'], 'Hôtel du Parc');
      expect(c['soireeAdresse'], '5 avenue E');
    });

    testWidgets('soirée sans lieu : refusée avant tout envoi', (tester) async {
      final (ecriture, _) = await _monter(tester);
      await _ouvrir(tester);
      await _toucher(tester, _dans('Soirée étape'));
      await _ajouter(tester);
      expect(
        find.text("Soirée étape : le lieu et l'adresse sont obligatoires."),
        findsOneWidget,
      );
      expect(ecriture.appels, isEmpty);
    });

    testWidgets('observations trop longues : refusées avant tout envoi', (
      tester,
    ) async {
      final (ecriture, _) = await _monter(tester);
      await _ouvrir(tester);
      await _ecrire(tester, 'Observations', 'x' * 501);
      await _ajouter(tester);
      expect(
        find.text('Observations : 500 caractères au plus.'),
        findsOneWidget,
      );
      expect(ecriture.appels, isEmpty);
    });

    testWidgets(
      'erreur de l\'API : la feuille reste ouverte, même idApk au nouvel essai',
      (tester) async {
        final (ecriture, planning) = await _monter(tester);
        ecriture.pannes.add(
          const ErreurApi(
            TypeErreurApi.inattendue,
            statut: 409,
            detail: 'La semaine est déjà validée.',
          ),
        );
        await _ouvrir(tester);
        await _ajouter(tester);
        expect(find.text('La semaine est déjà validée.'), findsOneWidget);
        expect(find.byType(FormulaireRdvSheet), findsOneWidget);
        expect(planning.rafraichis, 0);
        // Le bouton est de nouveau actif : second essai, qui réussit.
        await _ajouter(tester);
        expect(ecriture.appels, hasLength(2));
        expect(ecriture.corps(1)['idApk'], ecriture.corps(0)['idApk']);
        expect(find.byType(FormulaireRdvSheet), findsNothing);
        expect(planning.rafraichis, 1);
      },
    );

    testWidgets('hors connexion : message sobre, feuille ouverte', (
      tester,
    ) async {
      final (ecriture, planning) = await _monter(tester);
      ecriture.pannes.add(const ErreurApi(TypeErreurApi.reseau));
      await _ouvrir(tester);
      await _ajouter(tester);
      expect(
        find.text('Serveur injoignable. Vérifiez votre connexion.'),
        findsOneWidget,
      );
      expect(find.byType(FormulaireRdvSheet), findsOneWidget);
      expect(planning.rafraichis, 0);
    });

    testWidgets('bouton désactivé pendant l\'envoi : un seul appel', (
      tester,
    ) async {
      final (ecriture, planning) = await _monter(tester);
      ecriture.attente = Completer<void>();
      await _ouvrir(tester);
      await tester.ensureVisible(find.text('Ajouter la ligne'));
      await tester.tap(find.text('Ajouter la ligne'));
      await tester.pump();
      await tester.tap(find.text('Ajouter la ligne'), warnIfMissed: false);
      await tester.pump();
      expect(ecriture.appels, hasLength(1));
      expect(
        tester
            .widget<AppBouton>(
              find.widgetWithText(AppBouton, 'Ajouter la ligne'),
            )
            .onPressed,
        isNull,
      );
      ecriture.attente!.complete();
      await tester.pumpAndSettle();
      expect(ecriture.appels, hasLength(1));
      expect(planning.rafraichis, 1);
      expect(find.byType(FormulaireRdvSheet), findsNothing);
    });

    testWidgets('démonstration : store local, aucun envoi', (tester) async {
      final ecriture = FauxEcriture();
      await pumpEcran(
        tester,
        const PlanningScreen(),
        role: Role.cs,
        overrides: [apiEcritureProvider.overrideWithValue(ecriture)],
      );
      final avant = ProviderScope.containerOf(
        tester.element(find.byType(PlanningScreen)),
      ).read(crmProvider).etapes.length;
      await _ouvrir(tester);
      await _ajouter(tester);
      expect(ecriture.appels, isEmpty);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(PlanningScreen)),
        ).read(crmProvider).etapes.length,
        avant + 1,
      );
    });
  });

  group('visite pour un promoteur : POST /plannings', () {
    testWidgets(
      'depuis la fiche : promoteur choisi, jour sans heure, consigne',
      (tester) async {
        final (ecriture, planning) = await _monter(tester, avecEquipe: true);
        await _ouvrir(
          tester,
          cible: CiblePlanning.client,
          ref: _client,
          depuisFiche: true,
        );
        expect(_dans('Pour'), findsOneWidget);
        expect(_dans('Mon planning'), findsOneWidget);
        await _choisir(tester, 'Mon planning', 'Alice MARTIN');
        // Visite d'un promoteur : ni heure, ni type de visite.
        expect(_dans('Heure'), findsNothing);
        expect(_dans('Type de visite'), findsNothing);
        await _ecrire(
          tester,
          'Consigne pour le promoteur (facultatif)',
          'Refaire le linéaire',
        );
        await _ajouter(tester);
        expect(ecriture.appels.single.chemin, '/plannings');
        expect(ecriture.appels.single.methode, 'POST');
        final c = ecriture.corps(0);
        expect(c, {
          'idApk': c['idApk'],
          'promoteurId': _promoteur,
          'clientId': _client,
          'datePassage': '2026-11-04',
          'note': 'Refaire le linéaire',
        });
        expect(c['idApk'], matches(_uuid));
        expect(planning.rafraichis, 1);
        expect(find.byType(FormulaireRdvSheet), findsNothing);
      },
    );

    testWidgets('sans choisir de promoteur : son propre planning', (
      tester,
    ) async {
      final (ecriture, _) = await _monter(tester, avecEquipe: true);
      await _ouvrir(
        tester,
        cible: CiblePlanning.client,
        ref: _client,
        depuisFiche: true,
      );
      await _ajouter(tester);
      expect(ecriture.appels.single.chemin, '/tournees');
      expect(ecriture.corps(0)['clientId'], _client);
    });

    testWidgets('fiche prospect ou équipe vide : aucun choix de promoteur', (
      tester,
    ) async {
      await _monter(tester, avecEquipe: true);
      await _ouvrir(
        tester,
        cible: CiblePlanning.prospect,
        ref: _prospect,
        depuisFiche: true,
      );
      expect(_dans('Pour'), findsNothing);
    });

    testWidgets(
      'déjà planifié le même jour (409) : message clair, feuille ouverte',
      (tester) async {
        final (ecriture, planning) = await _monter(tester, avecEquipe: true);
        ecriture.pannes.add(
          const ErreurApi(TypeErreurApi.inattendue, statut: 409),
        );
        await _ouvrir(
          tester,
          cible: CiblePlanning.client,
          ref: _client,
          depuisFiche: true,
        );
        await _choisir(tester, 'Mon planning', 'Alice MARTIN');
        await _ajouter(tester);
        expect(
          find.text('Une visite est déjà planifiée ce jour chez ce client.'),
          findsOneWidget,
        );
        expect(find.byType(FormulaireRdvSheet), findsOneWidget);
        expect(planning.rafraichis, 0);
        // Nouvel essai : même idApk.
        await _ajouter(tester);
        expect(ecriture.corps(1)['idApk'], ecriture.corps(0)['idApk']);
        expect(find.byType(FormulaireRdvSheet), findsNothing);
      },
    );

    testWidgets('planning ouvert pour un promoteur : même route, sans heure', (
      tester,
    ) async {
      final (ecriture, planning) = await _monter(tester, avecEquipe: true);
      await _ouvrir(tester, planCible: 'Alice MARTIN');
      expect(_dans('Heure'), findsNothing);
      await _ajouter(tester, 'Ajouter la visite');
      expect(ecriture.appels.single.chemin, '/plannings');
      final c = ecriture.corps(0);
      expect(c['promoteurId'], _promoteur);
      expect(c['clientId'], _client);
      expect(c['datePassage'], '2026-11-04');
      expect(planning.rafraichis, 1);
      expect(find.byType(FormulaireRdvSheet), findsNothing);
    });

    testWidgets('404 hors périmètre : message de l\'API', (tester) async {
      final (ecriture, _) = await _monter(tester, avecEquipe: true);
      ecriture.pannes.add(
        const ErreurApi(
          TypeErreurApi.inattendue,
          statut: 404,
          detail: 'Client introuvable',
        ),
      );
      await _ouvrir(
        tester,
        cible: CiblePlanning.client,
        ref: _client,
        depuisFiche: true,
      );
      await _choisir(tester, 'Mon planning', 'Alice MARTIN');
      await _ajouter(tester);
      expect(find.text('Client introuvable'), findsOneWidget);
    });
  });

  testWidgets('démonstration : pas de choix de promoteur sur la fiche', (
    tester,
  ) async {
    await pumpEcran(tester, const PlanningScreen(), role: Role.cs);
    final ctx = tester.element(
      find.byType(PlanningScreen, skipOffstage: false),
    );
    AppRoutes.formulaireRdv(
      ctx,
      cible: CiblePlanning.client,
      ref: magasinsDemo.first.id,
      depuisFiche: true,
    );
    await tester.pumpAndSettle();
    expect(_dans('Pour'), findsNothing);
    expect(promoteursDeMonEquipe(), isNotEmpty);
  });

  testWidgets(
    'le promoteur connecté ne peut pas ouvrir de ligne depuis son planning',
    (tester) async {
      await _monter(tester, role: Role.promoteur, roleApi: 'COMMERCIAL');
      expect(find.bySemanticsLabel('Ajouter un RDV'), findsNothing);
    },
  );
}
