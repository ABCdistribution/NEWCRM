import 'package:crm_app/core/data/pem_demo.dart';
import 'package:crm_app/core/data/pem_serveur.dart';
import 'package:crm_app/core/data/referentiels_visite.dart';
import 'package:crm_app/core/data/visites_serveur.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/accueil/accueil_logique.dart';
import 'package:crm_app/features/visites/logic/visites_logique.dart';
import 'package:crm_app/features/visites/state/actions_visite.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

PropositionPem proposition({
  String id = 'p1',
  String date = '2026-11-09',
  StatutPem statut = StatutPem.proposee,
  int nbReports = 0,
  bool obligatoire = false,
  int? reportsRestants,
}) => PropositionPem(
  id: id,
  clientId: 'm5',
  clientNom: 'U EXPRESS – PARIS',
  dateProposee: date,
  statut: statut,
  nbReports: nbReports,
  obligatoire: obligatoire,
  reportsRestants: reportsRestants,
);

Map<String, dynamic> jsonProposition({
  Object? id = 'p1',
  Object? client = const {
    'id': 'm5',
    'enseigne': 'U EXPRESS',
    'ville': 'PARIS',
  },
  Object? statut = 'PROPOSEE',
  Object? dateProposee = '2026-11-09',
  Object? nbReports = 1,
  Object? obligatoire = false,
  Object? reportsRestants = 2,
}) => {
  'id': id,
  'client': client,
  'promoteur': {'id': 'u', 'displayName': 'Julien MARTIN'},
  'dateProposee': dateProposee,
  'statut': statut,
  'nbReports': nbReports,
  'obligatoire': obligatoire,
  'reportsRestants': reportsRestants,
  'motifDernierReport': 'Inventaire',
  'planningId': null,
  'visiteId': null,
};

Visite brouillonPem({
  Map<String, ReleveArticlePem> articles = const {},
  Map<EtapeDph, int> photos = const {},
}) => Visite(
  id: 'v1',
  num: 1,
  magasinId: 'm5',
  par: 'Julien M.',
  etat: EtatVisite.brouillon,
  date: '4 nov. 14:23',
  age: 0,
  chrono: const {},
  photos: photos,
  typeVisite: TypeVisite.pem,
  propositionPemId: 'p1',
  articlesPem: articles,
);

const articles = [
  ArticlePem(articleId: 'a1', libelle: 'Titanium 2', code: '20015'),
  ArticlePem(articleId: 'a2', libelle: 'Salon Series', code: '20007'),
  ArticlePem(articleId: 'a3', libelle: 'Elixir', code: '20020'),
];

void main() {
  group('reports restants et obligation', () {
    test('trois reports avant que la visite devienne obligatoire', () {
      expect(nbReportsAvantObligation, 3);
      expect(proposition().reportsRestants, 3);
      expect(proposition(nbReports: 2).reportsRestants, 1);
      expect(proposition(nbReports: 3).reportsRestants, 0);
      expect(proposition(nbReports: 5).reportsRestants, 0);
      // La valeur du CRM l'emporte quand elle est donnée.
      expect(proposition(reportsRestants: 2).reportsRestants, 2);
    });

    test('reportable : proposée, non obligatoire, avec un report restant', () {
      expect(proposition().reportable, isTrue);
      expect(proposition(nbReports: 2).reportable, isTrue);
      expect(proposition(nbReports: 3).reportable, isFalse);
      expect(proposition(obligatoire: true).reportable, isFalse);
      expect(proposition(statut: StatutPem.acceptee).reportable, isFalse);
    });

    test('ouverte : proposée ou acceptée seulement', () {
      expect(proposition().ouverte, isTrue);
      expect(proposition(statut: StatutPem.acceptee).ouverte, isTrue);
      expect(proposition(statut: StatutPem.realisee).ouverte, isFalse);
      expect(proposition(statut: StatutPem.annulee).ouverte, isFalse);
    });

    test('libellé de la pastille', () {
      expect(libelleReports(proposition()), '3 reports restants');
      expect(libelleReports(proposition(nbReports: 2)), '1 report restant');
      expect(libelleReports(proposition(obligatoire: true)), 'Obligatoire');
      expect(
        libelleReports(proposition(nbReports: 3)),
        'Plus de report possible',
      );
    });

    test(
      'report simulé : un de moins à chaque fois, obligatoire au troisième',
      () {
        var p = proposition();
        p = reporterLocalement(p, motif: 'Inventaire', date: '2026-11-11');
        expect((p.nbReports, p.reportsRestants), (1, 2));
        expect(p.statut, StatutPem.proposee);
        expect(p.dateProposee, '2026-11-11');
        expect(p.motifDernierReport, 'Inventaire');
        expect(p.obligatoire, isFalse);
        p = reporterLocalement(p, date: '2026-11-18');
        expect((p.nbReports, p.reportsRestants), (2, 1));
        expect(p.reportable, isTrue);
        p = reporterLocalement(p, date: '2026-11-18');
        expect((p.nbReports, p.reportsRestants), (3, 0));
        expect(p.obligatoire, isTrue);
        expect(p.statut, StatutPem.acceptee);
        expect(p.reportable, isFalse);
        // Plus de report : la proposition ne change plus.
        expect(reporterLocalement(p, date: '2026-11-19'), same(p));
      },
    );

    test(
      'acceptation simulée : acceptée, à la date choisie si elle est donnée',
      () {
        final a = accepterLocalement(proposition(), date: '2026-11-12');
        expect(a.statut, StatutPem.acceptee);
        expect(a.dateProposee, '2026-11-12');
        expect(accepterLocalement(proposition()).dateProposee, '2026-11-09');
      },
    );
  });

  group('fenêtres de dates', () {
    final auj = DateTime(2026, 11, 4);

    test('acceptation : d’aujourd’hui à +14 jours', () {
      final f = fenetreAcceptation(auj);
      expect(jourIso(f.min), '2026-11-04');
      expect(jourIso(f.max), '2026-11-18');
      expect(dansFenetre(DateTime(2026, 11, 4), f), isTrue);
      expect(dansFenetre(DateTime(2026, 11, 18), f), isTrue);
      expect(dansFenetre(DateTime(2026, 11, 3), f), isFalse);
      expect(dansFenetre(DateTime(2026, 11, 19), f), isFalse);
    });

    test('report : de demain à +14 jours, une semaine par défaut', () {
      final f = fenetreReport(auj);
      expect(jourIso(f.min), '2026-11-05');
      expect(jourIso(f.max), '2026-11-18');
      expect(dansFenetre(auj, f), isFalse);
      expect(jourIso(dateReportParDefaut(auj)), '2026-11-11');
      expect(dansFenetre(dateReportParDefaut(auj), f), isTrue);
    });

    test('passage de mois et d’année', () {
      final f = fenetreReport(DateTime(2026, 12, 25));
      expect(jourIso(f.min), '2026-12-26');
      expect(jourIso(f.max), '2027-01-08');
      expect(
        jourIso(dateReportParDefaut(DateTime(2026, 12, 28))),
        '2027-01-04',
      );
    });

    test('la date proposée est acceptable si elle est dans la fenêtre', () {
      expect(
        dateProposeeAcceptable(proposition(date: '2026-11-09'), auj),
        isTrue,
      );
      expect(
        dateProposeeAcceptable(proposition(date: '2026-11-04'), auj),
        isTrue,
      );
      expect(
        dateProposeeAcceptable(proposition(date: '2026-11-03'), auj),
        isFalse,
      );
      expect(
        dateProposeeAcceptable(proposition(date: '2026-12-01'), auj),
        isFalse,
      );
      expect(
        dateProposeeAcceptable(proposition(date: 'bientôt'), auj),
        isFalse,
      );
    });

    test('lecture et écriture d’un jour', () {
      expect(lireJourIso('2026-11-09T08:30:00.000Z'), DateTime(2026, 11, 9));
      expect(lireJourIso('n’importe quoi'), isNull);
      expect(lireJourIso(null), isNull);
      expect(libelleDatePem('2026-11-09'), 'lun. 9 nov.');
      expect(libelleDatePem('bientôt'), 'bientôt');
    });
  });

  test('propositions ouvertes : triées par date proposée', () {
    final l = propositionsOuvertes([
      proposition(id: 'c', date: '2026-11-12'),
      proposition(id: 'x', statut: StatutPem.realisee),
      proposition(id: 'a', date: '2026-11-06'),
      proposition(id: 'b', date: '2026-11-06', statut: StatutPem.acceptee),
      proposition(id: 'y', statut: StatutPem.annulee),
    ]);
    expect(l.map((p) => p.id), ['a', 'b', 'c']);
  });

  group('lecture du JSON du CRM', () {
    test('proposition complète', () {
      final p = propositionPemDepuisJson(jsonProposition())!;
      expect(p.id, 'p1');
      expect(p.clientId, 'm5');
      expect(p.clientNom, 'U EXPRESS – PARIS');
      expect(p.dateProposee, '2026-11-09');
      expect(p.statut, StatutPem.proposee);
      expect((p.nbReports, p.reportsRestants, p.obligatoire), (1, 2, false));
      expect(p.motifDernierReport, 'Inventaire');
      expect(p.planningId, isNull);
    });

    test('classe du client : niveauClass normalisé, sinon vide', () {
      Map<String, dynamic> avec(Object? classe) {
        final j = jsonProposition();
        j['client'] = {...(j['client'] as Map), 'niveauClass': classe};
        return j;
      }

      expect(propositionPemDepuisJson(avec('c'))!.clientClasse, 'C');
      expect(propositionPemDepuisJson(avec('—'))!.clientClasse, isEmpty);
      expect(propositionPemDepuisJson(avec(null))!.clientClasse, isEmpty);
    });

    test('date avec heure, reports restants absents ou négatifs', () {
      final p = propositionPemDepuisJson(
        jsonProposition(
          dateProposee: '2026-11-09T00:00:00.000Z',
          nbReports: 2,
          reportsRestants: null,
        ),
      )!;
      expect(p.dateProposee, '2026-11-09');
      expect(p.reportsRestants, 1);
      expect(
        propositionPemDepuisJson(
          jsonProposition(reportsRestants: -1),
        )!.reportsRestants,
        0,
      );
    });

    test('obligatoire et acceptée', () {
      final p = propositionPemDepuisJson(
        jsonProposition(
          statut: 'ACCEPTEE',
          obligatoire: true,
          nbReports: 3,
          reportsRestants: 0,
        ),
      )!;
      expect(p.statut, StatutPem.acceptee);
      expect(p.obligatoire, isTrue);
      expect(p.reportable, isFalse);
    });

    test('lignes inutilisables ignorées', () {
      expect(propositionPemDepuisJson(jsonProposition(id: null)), isNull);
      expect(propositionPemDepuisJson(jsonProposition(client: null)), isNull);
      expect(
        propositionPemDepuisJson(jsonProposition(statut: 'AUTRE')),
        isNull,
      );
      expect(
        propositionPemDepuisJson(jsonProposition(dateProposee: 'demain')),
        isNull,
      );
    });

    test('articles PEM : identifiant, libellé, code et marque', () {
      final liste = articlesPemDepuisJson([
        {
          'id': 'l1',
          'article': {
            'id': 'a1',
            'codeAs400': '20015',
            'libelle': 'Titanium 2',
            'gencode': null,
            'marque': {'nom': 'Titanium'},
          },
        },
        {
          'id': 'l2',
          'article': {'id': 'a2', 'libelle': 'Salon Series', 'marque': null},
        },
        {
          'id': 'l3',
          'article': {'id': 'a3', 'libelle': ''},
        },
        {'id': 'l4'},
      ]);
      expect(liste.map((a) => a.articleId), ['a1', 'a2']);
      expect(liste.first.marque, 'Titanium');
      expect(liste.first.code, '20015');
      expect(liste.last.marque, '');
      expect(articlesPemDepuisJson(null), isEmpty);
    });

    test('visite PEM du CRM : type, proposition et articles relevés', () {
      final v = visiteDepuisJson({
        'id': 'v9',
        'createdAt': '2026-11-03T09:30:00.000Z',
        'client': {'id': 'm5'},
        'promoteur': {'id': 'u', 'displayName': 'Julien MARTIN'},
        'typeVisite': 'PEM',
        'propositionPemId': 'p1',
        'articlesPem': [
          {
            'articleId': 'a1',
            'present': true,
            'misEnAvant': true,
            'article': {'libelle': 'Titanium 2', 'codeAs400': '20015'},
          },
          {'articleId': 'a2', 'present': false, 'misEnAvant': true},
          {'articleId': 'a3', 'present': true, 'misEnAvant': false},
          {'articleId': 'a4'},
        ],
      })!;
      expect(v.estPem, isTrue);
      expect(v.propositionPemId, 'p1');
      expect(v.articlesPem.keys, ['a1', 'a2', 'a3']);
      expect(v.articlesPem['a1'], (present: true, misEnAvant: true));
      // Un article absent n'est jamais « mis en avant ».
      expect(v.articlesPem['a2'], (present: false, misEnAvant: false));
      expect(v.articlesPemAbsents, 1);
      expect(v.articlesPemMisEnAvant, 1);
      expect(articlesPemAbsents(v), ['Article inconnu']);
      expect(articlesPemMisEnAvant(v), ['Titanium 2']);
    });

    test('visite commerciale du CRM : pas de type PEM', () {
      final v = visiteDepuisJson({
        'id': 'v8',
        'client': {'id': 'm5'},
        'typeVisite': 'COMMERCIALE',
        'propositionPemId': 'p1',
      })!;
      expect(v.estPem, isFalse);
      expect(v.propositionPemId, isNull);
      expect(v.articlesPem, isEmpty);
    });
  });

  group('parcours d’une visite PEM', () {
    test(
      'cinq étapes : arrivée, rayon avant, articles PEM, questionnaire, rayon après',
      () {
        expect(EtapeDph.parcoursPem.map((e) => e.cle), [
          'arrivee',
          'rayonArrivee',
          'articlesPem',
          'questionnaire',
          'rayonFin',
        ]);
        expect(EtapeDph.articlesPem.libelle, 'Vérification des articles PEM');
        expect(
          EtapeDph.rayonArrivee.libellePour(TypeVisite.pem),
          'Photo du rayon avant',
        );
        expect(
          EtapeDph.rayonFin.libellePour(TypeVisite.pem),
          'Photo du rayon après',
        );
        // Les visites commerciales gardent leurs libellés.
        expect(
          EtapeDph.rayonArrivee.libellePour(TypeVisite.commerciale),
          'Photo du rayon',
        );
        expect(
          EtapeDph.rayonFin.libellePour(TypeVisite.commerciale),
          'Photo du rayon de fin de visite',
        );
        expect(
          EtapeDph.questionnaire.libellePour(TypeVisite.pem),
          EtapeDph.questionnaire.libelle,
        );
      },
    );

    test('sans liste d’articles PEM, l’étape n’est pas proposée', () {
      expect(EtapeDph.parcoursPemPour(articles: true), hasLength(5));
      final sans = EtapeDph.parcoursPemPour(articles: false);
      expect(sans, hasLength(4));
      expect(sans, isNot(contains(EtapeDph.articlesPem)));
    });

    test('le parcours commercial reste inchangé', () {
      expect(EtapeDph.parcours, hasLength(8));
      expect(EtapeDph.parcours, isNot(contains(EtapeDph.articlesPem)));
      expect(EtapeDph.parcoursPour(indispensables: false), hasLength(7));
      final c = conteneurPour(Role.promoteur);
      final id = c.read(crmProvider.notifier).demarrerVisite('m5');
      expect(c.read(crmProvider).visiteParId(id)!.etapes, EtapeDph.parcours);
      expect(brouillonPem().etapes, EtapeDph.parcoursPem);
    });

    test('« Suivant » exige chaque article relevé', () {
      const message =
          "Indiquez pour chaque article PEM s'il est présent ou absent.";
      final vide = brouillonPem();
      expect(
        erreurEtape(vide, EtapeDph.articlesPem, articlesPem: articles),
        message,
      );
      final deux = brouillonPem(
        articles: {
          'a1': (present: true, misEnAvant: false),
          'a2': (present: false, misEnAvant: false),
        },
      );
      expect(articlesPemReleves(deux, articles), 2);
      expect(
        erreurEtape(deux, EtapeDph.articlesPem, articlesPem: articles),
        message,
      );
      final tous = brouillonPem(
        articles: {
          'a1': (present: true, misEnAvant: false),
          'a2': (present: false, misEnAvant: false),
          'a3': (present: true, misEnAvant: true),
        },
      );
      expect(
        erreurEtape(tous, EtapeDph.articlesPem, articlesPem: articles),
        isNull,
      );
      // « Mis en avant » n'est jamais exigé.
      // Liste inconnue : rien n'est exigé.
      expect(erreurEtape(vide, EtapeDph.articlesPem), isNull);
    });

    test(
      'la validation d’une visite PEM liste ce qui manque, sans commande ni DN',
      () {
        final manque = manquants(brouillonPem(), articlesPem: articles);
        expect(manque, [
          "Prenez la photo d'arrivée sur site.",
          'Prenez la photo du rayon.',
          "Indiquez pour chaque article PEM s'il est présent ou absent.",
        ]);
        final complet = brouillonPem(
          articles: {
            for (final a in articles)
              a.articleId: (present: true, misEnAvant: false),
          },
          photos: const {EtapeDph.arrivee: 1, EtapeDph.rayonArrivee: 1},
        );
        expect(manquants(complet, articlesPem: articles), isEmpty);
      },
    );

    test(
      'libellés des articles relevés : ceux de la visite, sinon ceux de la liste',
      () {
        final v = brouillonPem(
          articles: {
            'a1': (present: false, misEnAvant: false),
            'a2': (present: true, misEnAvant: true),
            'zz': (present: false, misEnAvant: false),
          },
        );
        expect(articlesPemAbsents(v, articles), [
          'Titanium 2',
          'Article inconnu',
        ]);
        expect(articlesPemMisEnAvant(v, articles), ['Salon Series']);
        expect((v.articlesPemAbsents, v.articlesPemMisEnAvant), (2, 1));
      },
    );
  });

  group('visite PEM dans le store', () {
    test(
      '« Démarrer la visite PEM » crée un brouillon de type PEM lié à la proposition',
      () {
        final c = conteneurPour(Role.promoteur);
        final store = c.read(crmProvider.notifier);
        final id = store.demarrerVisitePem('m5', 'pem-d1');
        final v = c.read(crmProvider).visiteParId(id)!;
        expect(v.estPem, isTrue);
        expect(v.etat, EtatVisite.brouillon);
        expect(v.propositionPemId, 'pem-d1');
        expect(v.magasinId, 'm5');
        // Reprise : le même brouillon, pas de doublon.
        expect(store.demarrerVisitePem('m5', 'pem-d1'), id);
        expect(
          c.read(crmProvider).visites.where((x) => x.estPem),
          hasLength(1),
        );
        expect(visitePemDe(c.read(crmProvider).visites, 'pem-d1')!.id, id);
        expect(visitePemDe(c.read(crmProvider).visites, 'autre'), isNull);
      },
    );

    test(
      'une visite commerciale ne reprend pas le brouillon PEM, et inversement',
      () {
        final c = conteneurPour(Role.promoteur);
        final store = c.read(crmProvider.notifier);
        final pem = store.demarrerVisitePem('m5', 'pem-d1');
        final commerciale = store.demarrerVisite('m5');
        expect(commerciale, isNot(pem));
        expect(c.read(crmProvider).visiteParId(commerciale)!.estPem, isFalse);
        expect(store.demarrerVisite('m5'), commerciale);
        expect(store.demarrerVisitePem('m5', 'pem-d1'), pem);
      },
    );

    test('la tournée du jour ne compte pas les visites PEM', () {
      final c = conteneurPour(Role.promoteur);
      c.read(crmProvider.notifier).demarrerVisitePem('m8', 'pem-x');
      expect(
        etatTournee(c.read(crmProvider).visites, 'm8'),
        EtatTournee.aFaire,
      );
    });

    test('relever un article : présent, absent, mis en avant', () {
      final c = conteneurPour(Role.promoteur);
      final store = c.read(crmProvider.notifier);
      final id = store.demarrerVisitePem('m5', 'pem-d1');
      final actions = ActionsVisite(store, id);
      Visite v() => c.read(crmProvider).visiteParId(id)!;

      // Mettre en avant avant d'avoir relevé la présence : sans effet.
      actions.mettreEnAvantArticlePem('a1', misEnAvant: true);
      expect(v().articlesPem, isEmpty);

      actions.releverArticlePem('a1', present: true);
      expect(v().articlesPem['a1'], (present: true, misEnAvant: false));
      actions.mettreEnAvantArticlePem('a1', misEnAvant: true);
      expect(v().articlesPem['a1'], (present: true, misEnAvant: true));
      // Repasser « Présent » garde le choix.
      actions.releverArticlePem('a1', present: true);
      expect(v().articlesPem['a1'], (present: true, misEnAvant: true));
      // Absent : plus « mis en avant », et l'interrupteur n'a plus d'effet.
      actions.releverArticlePem('a1', present: false);
      expect(v().articlesPem['a1'], (present: false, misEnAvant: false));
      actions.mettreEnAvantArticlePem('a1', misEnAvant: true);
      expect(v().articlesPem['a1'], (present: false, misEnAvant: false));
      // Le type de la visite survit aux modifications (effacement de la raison d'absence comprise).
      actions.effacerRaisonAbsence();
      expect(v().estPem, isTrue);
      expect(v().propositionPemId, 'pem-d1');
      expect(v().articlesPem, hasLength(1));
    });
  });

  test(
    'démonstration : une proposition à traiter, une devenue obligatoire',
    () {
      expect(propositionsPemDemo, hasLength(2));
      expect(propositionsPemDemo.first.reportable, isTrue);
      expect(propositionsPemDemo.last.obligatoire, isTrue);
      expect(propositionsPemDemo.last.reportable, isFalse);
      expect(articlesPemDemo, isNotEmpty);
      expect(articlesPemDemo.every((a) => a.libelle.isNotEmpty), isTrue);
    },
  );
}
