import 'dart:io';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/planning_serveur.dart';
import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:crm_app/core/sync/planning_equipe_provider.dart';
import 'package:crm_app/features/planning/logic/logique_planning.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _uuid = '11111111-2222-3333-4444-555555555555';

/// Mercredi 4 novembre 2026 : lundi 2 novembre, semaine 45.
final _lundi = DateTime(2026, 11, 2);

Map<String, dynamic> _etape(
  String id,
  String date, {
  bool adm = false,
  Map<String, dynamic>? client,
  Map<String, dynamic>? prospect,
  String? libelle,
  bool fait = false,
  bool rdv = false,
  String? note,
}) => {
  'id': id,
  'adm': adm,
  'libelle': libelle,
  'adresse': null,
  'datePassage': date,
  'fait': fait,
  'note': note,
  'visiteSimple': true,
  'accompagnement': false,
  'rdv': rdv,
  'soireeEtape': false,
  'soireeLieu': null,
  'soireeAdresse': null,
  'client': client,
  'prospect': prospect,
};

final _carrefour = {'id': 'c1', 'enseigne': 'Carrefour', 'ville': 'Ivry'};

List<Map<String, dynamic>> _tournee() => [
  _etape(
    'e1',
    '2026-11-02T09:30:00.000Z',
    client: _carrefour,
    fait: true,
    rdv: true,
    note: 'Point linéaire',
  ),
  _etape('e2', '2026-11-04T00:00:00.000Z', adm: true),
  _etape(
    'e3',
    '2026-11-09T14:00:00.000Z',
    prospect: {'id': 'p1', 'enseigne': 'Auchan', 'ville': 'Rouen'},
  ),
  // Un samedi : l'application n'a que cinq jours.
  _etape('e4', '2026-11-07T10:00:00.000Z', client: _carrefour),
  _etape('e5', '2026-10-27T10:00:00.000Z', libelle: 'Salon Cosmétique'),
];

Map<String, dynamic> _ligne(
  String jour,
  String? heure,
  String titre, {
  String? clientId,
  String? ville,
  bool fait = false,
}) => {
  'jour': jour,
  'heure': heure,
  'adm': false,
  'clientId': clientId,
  'prospectId': null,
  'libelle': null,
  'titre': titre,
  'ville': ville,
  'adresse': null,
  'visiteSimple': true,
  'accompagnement': false,
  'rdv': false,
  'soireeEtape': false,
  'soireeLieu': null,
  'soireeAdresse': null,
  'note': null,
  'fait': fait,
};

Map<String, dynamic> _semaine({bool verrouillee = false}) => {
  'semaine': '2026-11-02',
  'phase': 'RAPPORT',
  'prevuAt': '2026-11-02T08:10:00.000Z',
  'valideAt': null,
  'valideAuto': false,
  'nbEtapesPrevues': 2,
  'previsionNonRenseignee': false,
  'verrouillee': verrouillee,
  'statut': 'EN_COURS',
};

Map<String, dynamic> _prevue() => {
  'prevue': [
    _ligne('2026-11-02', '09:30', 'Carrefour', clientId: 'c1', ville: 'Ivry'),
    _ligne('2026-11-03', '10:00', 'Monoprix', clientId: 'c9', ville: 'Caen'),
  ],
};

Map<String, dynamic> _historique() => {
  'mois': '2026-11',
  'visitesMois': 3,
  'pourcentPrevuMois': 50,
  'references': 0,
  'semaines': [
    {
      'semaine': '2026-11-02',
      'numero': 45,
      'statut': 'EN_COURS',
      'valideAt': null,
      'valideAuto': false,
      'nbPrevues': 2,
      'nbLignes': 3,
      'visites': 1,
      'rdv': 1,
      'pourcentPrevu': 50,
    },
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
};

class _Api implements ApiLecture {
  final Map<String, Object?> reponses = {};
  final List<String> appels = [];
  Object? erreur;

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    appels.add(chemin);
    if (erreur != null) throw erreur!;
    return reponses[chemin];
  }
}

/// Attend la première valeur d'un chargement à l'ouverture (la copie locale ou, sans elle, la réponse du CRM).
Future<T?> charger<T>(
  ProviderContainer c,
  ProviderListenable<AsyncValue<T?>> p,
) async {
  c.listen(p, (_, _) {});
  for (var i = 0; i < 200; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    final v = c.read(p);
    if (v is AsyncData<T?>) return v.value;
  }
  fail('chargement sans résultat');
}

void main() {
  setUp(() {
    DemoTemps.maintenant = () => DateTime(2026, 11, 4, 10);
    DemoTemps.reel = true;
  });

  tearDown(() {
    DemoTemps.maintenant = DateTime.now;
    DemoTemps.reel = false;
    definirPlanningServeur(null);
    definirRapportsServeur(null);
  });

  group('lecture des lignes de planning', () {
    test('tournée de l’encadrement : jour, heure, cible et semaine', () {
      final p = planningDepuisJson(_tournee(), _lundi);
      // Triées par semaine, jour puis heure ; le samedi est écarté.
      expect(p.etapes.map((e) => e.id), ['e5', 'e1', 'e2', 'e3']);
      final e1 = p.etapes.firstWhere((e) => e.id == 'e1');
      expect(e1.jour, 0);
      expect(e1.heure, '09:30');
      expect(e1.cible, CiblePlanning.client);
      expect(e1.ref, 'c1');
      expect(e1.titre, 'Carrefour – Ivry');
      expect(e1.rdv, isTrue);
      expect(e1.fait, isTrue);
      expect(e1.note, 'Point linéaire');
      expect(e1.sem, 0);
      final adm = p.etapes.firstWhere((e) => e.id == 'e2');
      expect(adm.cible, CiblePlanning.adm);
      expect(adm.titre, 'Administratif');
      expect(adm.heure, isEmpty);
      expect(adm.jour, 2);
      final suivante = p.etapes.firstWhere((e) => e.id == 'e3');
      expect(suivante.sem, 1);
      expect(suivante.cible, CiblePlanning.prospect);
      expect(suivante.ref, 'p1');
      final libre = p.etapes.firstWhere((e) => e.id == 'e5');
      expect(libre.sem, -1);
      expect(libre.jour, 1);
      expect(libre.cible, CiblePlanning.libre);
      expect(libre.titre, 'Salon Cosmétique');
      expect(p.semaineCourante.map((e) => e.id), ['e1', 'e2']);
      expect(p.tournee, isEmpty);
    });

    test('promoteur : visites planifiées, tournée du jour sans heure', () {
      final lignes = [
        {
          'id': 'a',
          'datePassage': '2026-11-04T00:00:00.000Z',
          'fait': false,
          'raison': null,
          'client': _carrefour,
          '_src': 'planning',
        },
        {
          'id': 'b',
          'datePassage': '2026-11-05T00:00:00.000Z',
          'fait': true,
          'raison': 'Réassort',
          'client': {'id': 'c2', 'enseigne': 'Leclerc', 'ville': null},
          '_src': 'planning',
        },
      ];
      final p = planningDepuisJson(lignes, _lundi);
      expect(p.etapes.map((e) => (e.id, e.jour, e.titre, e.fait, e.note)), [
        ('a', 2, 'Carrefour – Ivry', false, ''),
        ('b', 3, 'Leclerc', true, 'Réassort'),
      ]);
      expect(p.tournee.map((t) => (t.id, t.magasinId, t.heure)), [
        ('a', 'c1', ''),
      ]);
    });

    test('lignes illisibles : ignorées', () {
      final p = planningDepuisJson([
        {'id': 'x', 'datePassage': 'n’importe quoi'},
        {'datePassage': '2026-11-03T10:00:00.000Z'},
      ], _lundi);
      expect(p.etapes, isEmpty);
    });
  });

  group('prévision et rapports', () {
    test('rapprochement : la ligne prévue reprend l’id de la réalisée', () {
      final realisee = planningDepuisJson(_tournee(), _lundi).semaineCourante;
      final prevue = lignesDepuisRapport(_prevue()['prevue'], _lundi);
      final r = rapprocherPrevue(prevue, realisee);
      expect(r[0].id, 'e1');
      expect(r[1].id, 'prevu-1');
      expect(r.every((e) => !e.fait), isTrue);
    });

    test('rapprochement : un client déplacé garde sa ligne', () {
      final realisee = [
        for (final e in planningDepuisJson(_tournee(), _lundi).etapes)
          if (e.id == 'e1') e.copyWith(jour: 3, heure: '15:00'),
      ];
      final prevue = lignesDepuisRapport([
        _ligne(
          '2026-11-02',
          '09:30',
          'Carrefour',
          clientId: 'c1',
          ville: 'Ivry',
        ),
      ], _lundi);
      expect(rapprocherPrevue(prevue, realisee).single.id, 'e1');
    });

    test('rapport d’une semaine : écarts et taux de réalisation', () {
      final r = rapportDepuisLignes(
        lundi: _lundi,
        etat: _semaine(),
        prevueBrute: _prevue()['prevue'],
        realisee: planningDepuisJson(_tournee(), _lundi).semaineCourante,
      );
      expect(r.nonRenseignee, isFalse);
      expect(r.valide, isFalse);
      final e = r.ecarts!;
      expect(e.prevues, 2);
      expect(e.realisees, 1);
      expect(e.pct, 50);
      expect(e.retirees, 1);
      expect(e.ajoutees, 1); // l'ADM n'était pas prévue
    });

    test('sans prévision : pas de comparaison', () {
      final r = rapportEquipeDepuisJson({
        'auteur': {'id': _uuid},
        'etat': _semaine(),
        'prevue': null,
        'realisee': [
          _ligne('2026-11-02', '09:30', 'Carrefour', clientId: 'c1'),
        ],
      }, _lundi)!;
      expect(r.nonRenseignee, isTrue);
      expect(r.ecarts, isNull);
      expect(r.realisee, hasLength(1));
    });

    test('état de la semaine : gardé seulement pour la semaine courante', () {
      final j = {
        'id': 'courant',
        'semaine': _semaine(),
        'prevue': _prevue(),
        'historique': _historique(),
      };
      final r = rapportsDepuisJson(j, _lundi);
      expect(r.semaine!.phaseRapport, isTrue);
      expect(r.semaine!.verrouillee, isFalse);
      expect(r.prevue, hasLength(2));
      expect(r.semaines.map((s) => s.numero), [45, 44]);
      // Copie locale d'une autre semaine : ni état ni prévision, mais l'historique reste.
      final ancienne = rapportsDepuisJson(j, DateTime(2026, 11, 9));
      expect(ancienne.semaine, isNull);
      expect(ancienne.prevue, isNull);
      expect(ancienne.semaines, hasLength(2));
    });

    test('Mes rapports : la semaine courante seulement une fois validée', () {
      final r = rapportsDepuisJson({
        'semaine': _semaine(),
        'historique': _historique(),
      }, _lundi);
      final liste = rapportsReels(r);
      expect(liste.map((x) => x.numero), [44]);
      final s44 = liste.single;
      expect(s44.periode, '26 – 30 octobre');
      expect(s44.visites, 14);
      expect(s44.pct, 93);
      expect(s44.prevues, 15);
      expect(s44.rdv, 4);
      expect(s44.auto, isTrue);
      expect(s44.valide, isTrue);
      expect(s44.ecartsConnus, isFalse);
      expect(s44.lundi, '2026-10-26');
      expect(s44.pied, startsWith('Validé automatiquement le '));

      final validee = rapportsReels(
        RapportsServeur(
          semaines: [
            for (final s in r.semaines)
              s.numero == 45
                  ? SemaineHistorique(
                      lundi: s.lundi,
                      numero: 45,
                      valide: true,
                      valideAuto: false,
                      valideAt: DateTime(2026, 11, 9, 8, 5),
                      nbPrevues: 2,
                      nbLignes: 3,
                      visites: 3,
                      rdv: 1,
                      pourcentPrevu: 100,
                    )
                  : s,
          ],
        ),
      );
      expect(validee.map((x) => x.numero), [45, 44]);
      expect(validee.first.auto, isFalse);
      expect(validee.first.pied, 'Validé le lun. 9 nov. à 08:05');
    });

    test('semaine passée non validée : signalée', () {
      final r = rapportDepuisHistorique(
        const SemaineHistorique(
          lundi: '2026-10-19',
          numero: 43,
          valide: false,
          valideAuto: false,
          valideAt: null,
          nbPrevues: null,
          nbLignes: 2,
          visites: 1,
          rdv: 0,
          pourcentPrevu: null,
        ),
      );
      expect(r.valide, isFalse);
      expect(r.pied, 'Rapport non validé');
      expect(r.pct, isNull);
    });
  });

  group('dates de la démonstration', () {
    test(
      'dates d’exemple : figées en démonstration, relatives une fois connecté',
      () {
        DemoTemps.reel = false;
        expect(DemoTemps.jourRelatif(-13), '22 oct.');
        expect(DemoTemps.jourRelatif(-34), '1 oct.');
        expect(DemoTemps.jourRelatif(32), '6 déc.');
        expect(DemoTemps.lundiLibelle, 'lun. 2 nov.');
        expect(DemoTemps.livraisonPrevueNumerique, '06/11/2026');
        DemoTemps.reel = true;
        DemoTemps.maintenant = () => DateTime(2026, 12, 15, 9);
        expect(DemoTemps.jourRelatif(-13), '2 déc.');
        expect(DemoTemps.lundiLibelle, 'lun. 14 déc.');
        expect(DemoTemps.livraisonPrevueNumerique, '17/12/2026');
        expect(DemoTemps.semaineLibelle, '14 – 18 décembre');
      },
    );
  });

  group('synchro et chargement à l’ouverture', () {
    late Directory dossier;
    late AppDatabase base;
    late _Api api;

    setUp(() async {
      dossier = Directory.systemTemp.createTempSync('crm_planning_test_');
      base = await ouvrirBaseChiffree(
        fichier: File('${dossier.path}/crm.db'),
        cleHex: _cle,
      );
      api = _Api();
    });

    tearDown(() async {
      await base.close();
      dossier.deleteSync(recursive: true);
    });

    ProviderContainer conteneur(String role) {
      final c = ProviderContainer(
        overrides: [
          baseLocaleProvider.overrideWithValue(base),
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            () => SessionNotifier(
              Utilisateur(
                id: 'moi',
                identifiant: 'x',
                nomAffiche: 'Jean DUPONT',
                email: null,
                roleApi: role,
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> attendre(
      ProviderContainer c,
      NotifierProvider<Notifier<EtatSynchro>, EtatSynchro> p,
    ) async {
      c.listen(p, (_, _) {});
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        if (c.read(p).phase != PhaseSynchro.chargement) return;
      }
    }

    test(
      'chef de secteur : tournée et rapports téléchargés, relus hors connexion',
      () async {
        api.reponses['/tournees/me'] = _tournee();
        api.reponses['/tournees/semaine'] = _semaine();
        api.reponses['/tournees/semaine/prevue'] = _prevue();
        api.reponses['/tournees/historique'] = _historique();
        final c = conteneur('CHEF_SECTEUR');
        await attendre(c, planningSynchroProvider);
        await attendre(c, rapportsSynchroProvider);
        expect(c.read(planningSynchroProvider).phase, PhaseSynchro.ok);
        expect(c.read(rapportsSynchroProvider).phase, PhaseSynchro.ok);
        expect(planningServeur()!.semaineCourante.map((e) => e.id), [
          'e1',
          'e2',
        ]);
        expect(rapportsServeur()!.semaine!.phaseRapport, isTrue);
        expect(rapportsServeur()!.semaines, hasLength(2));
        expect(api.appels.contains('/plannings'), isFalse);

        definirPlanningServeur(null);
        definirRapportsServeur(null);
        api.erreur = const ErreurApi(TypeErreurApi.reseau);
        final c2 = conteneur('CHEF_SECTEUR');
        await attendre(c2, planningSynchroProvider);
        await attendre(c2, rapportsSynchroProvider);
        expect(c2.read(planningSynchroProvider).phase, PhaseSynchro.horsLigne);
        expect(planningServeur()!.etapes, hasLength(4));
        expect(rapportsServeur()!.prevue, hasLength(2));
      },
    );

    test(
      'promoteur : ses visites planifiées, ni tournée ni rapports',
      () async {
        api.reponses['/plannings'] = [
          {
            'id': 'a',
            'datePassage': '2026-11-04T00:00:00.000Z',
            'fait': false,
            'raison': null,
            'client': _carrefour,
          },
        ];
        final c = conteneur('COMMERCIAL');
        await attendre(c, planningSynchroProvider);
        await attendre(c, rapportsSynchroProvider);
        expect(planningServeur()!.tournee.single.magasinId, 'c1');
        expect(planningServeur()!.etapes.single.titre, 'Carrefour – Ivry');
        expect(rapportsServeur(), isNull);
        expect(api.appels.where((a) => a.startsWith('/tournees')), isEmpty);
      },
    );

    test('refus : rien à voir, pas une panne', () async {
      api.erreur = const ErreurApi(TypeErreurApi.refuse, statut: 403);
      final c = conteneur('CHEF_SECTEUR');
      await attendre(c, planningSynchroProvider);
      expect(c.read(planningSynchroProvider).phase, PhaseSynchro.ok);
    });

    test(
      'planning d’un membre de l’équipe : tournée puis copie locale',
      () async {
        api.reponses['/tournees/user/$_uuid'] = {
          'user': {'id': _uuid},
          'etapes': _tournee(),
        };
        final cle = (userId: _uuid, promoteur: false);
        final c = conteneur('DIRECTION');
        final l = await charger(c, planningUtilisateurProvider(cle));
        expect(l!.map((e) => e.id), ['e5', 'e1', 'e2', 'e3']);

        api.erreur = const ErreurApi(TypeErreurApi.reseau);
        final c2 = conteneur('DIRECTION');
        final copie = await charger(c2, planningUtilisateurProvider(cle));
        expect(copie, hasLength(4));
      },
    );

    test('planning d’un promoteur : /plannings avec son identifiant', () async {
      api.reponses['/plannings'] = [
        {
          'id': 'a',
          'datePassage': '2026-11-03T00:00:00.000Z',
          'fait': true,
          'client': _carrefour,
        },
      ];
      final c = conteneur('CHEF_SECTEUR');
      final l = await charger(
        c,
        planningUtilisateurProvider((userId: _uuid, promoteur: true)),
      );
      expect(l!.single.jour, 1);
      expect(l.single.fait, isTrue);
      expect(api.appels, ['/plannings']);
    });

    test('identifiant qui n’est pas un UUID : rien n’est demandé', () async {
      final c = conteneur('DIRECTION');
      final l = await charger(
        c,
        planningUtilisateurProvider((userId: '../../admin', promoteur: false)),
      );
      expect(l, isNull);
      expect(api.appels, isEmpty);
    });

    test('rapport d’un chef de secteur : refus = pas de rapport', () async {
      api.reponses['/rapports/$_uuid'] = {
        'auteur': {'id': _uuid},
        'etat': {..._semaine(), 'verrouillee': true, 'valideAuto': true},
        'prevue': _prevue()['prevue'],
        'realisee': [
          _ligne(
            '2026-11-02',
            '09:30',
            'Carrefour',
            clientId: 'c1',
            ville: 'Ivry',
            fait: true,
          ),
        ],
      };
      final cle = (userId: _uuid, lundi: '2026-11-02');
      final c = conteneur('DIRECTION');
      final r = await charger(c, rapportEquipeProvider(cle));
      expect(r!.valide, isTrue);
      expect(r.valideAuto, isTrue);
      expect(r.ecarts!.pct, 50);

      final refus = _Api()
        ..erreur = const ErreurApi(TypeErreurApi.refuse, statut: 403);
      final c2 = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(refus)],
      );
      addTearDown(c2.dispose);
      expect(await charger(c2, rapportEquipeProvider(cle)), isNull);
    });

    test('rapport personnel d’une semaine passée', () async {
      api.reponses['/tournees/semaine'] = {
        ..._semaine(),
        'semaine': '2026-10-26',
        'valideAt': '2026-11-02T03:00:00.000Z',
        'valideAuto': true,
        'verrouillee': true,
      };
      api.reponses['/tournees/semaine/prevue'] = {
        'prevue': [
          _ligne(
            '2026-10-26',
            '09:30',
            'Carrefour',
            clientId: 'c1',
            ville: 'Ivry',
          ),
        ],
      };
      api.reponses['/tournees/me'] = [
        _etape(
          'r1',
          '2026-10-26T09:30:00.000Z',
          client: _carrefour,
          fait: true,
        ),
      ];
      final c = conteneur('CHEF_SECTEUR');
      final r = await charger(c, rapportPersonnelProvider('2026-10-26'));
      expect(r!.valide, isTrue);
      expect(r.ecarts!.pct, 100);
      expect(r.ecarts!.lignes.single.genre.name, 'fait');
    });
  });
}
