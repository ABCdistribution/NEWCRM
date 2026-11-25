import 'dart:io';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/fiche_client.dart';
import 'package:crm_app/core/data/journal_contacts.dart';
import 'package:crm_app/core/envoi/corps_activite.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/fiche_client_provider.dart';
import 'package:crm_app/core/sync/journal_contacts_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

Map<String, dynamic> _detail() => {
  'id': 'c1',
  'tel1': '0102030405',
  'email': 'magasin@exemple.fr',
  'centrale': {'nom': 'Carrefour'},
  'secteur': {'nom': 'Yvelines'},
  'commerciaux': [
    {'displayName': 'Julien MARTIN'},
  ],
  'periodicites': [
    {
      'periodicite': {'libelle': 'Mensuelle'},
    },
  ],
  'contacts': [
    {
      'prenom': 'Mme',
      'nom': 'Girard',
      'poste': 'Chef de rayon',
      'portable': '0607080910',
      'fixe': '0102030405',
      'mail': 'girard@exemple.fr',
    },
    {'nom': ' '},
  ],
  'notes': [
    {
      'remarque': 'Demande une tête de gondole',
      'createdAt': '2026-11-10T09:00:00.000Z',
      'auteur': {'displayName': 'Nadia H.'},
    },
  ],
};

Map<String, dynamic> _historique() => {
  'commandes': [
    {
      'id': 'x1',
      'numero': 'CDE-9',
      'dateCommande': '2026-11-12T08:00:00.000Z',
      'annulee': false,
      'viaMobile': true,
      'nbLignes': 5,
      'total': 840.0,
      'statutLivraison': 'EXPEDIEE',
      'dateExpedition': '2026-11-13T08:00:00.000Z',
      'transporteur': 'Geodis',
    },
    {
      'id': 'x2',
      'numero': 'CDE-8',
      'dateCommande': '2026-10-01T08:00:00.000Z',
      'annulee': true,
      'total': 10.0,
    },
  ],
  'visites': [
    {
      'id': 'v1',
      'createdAt': '2026-11-05T10:00:00.000Z',
      'promoteur': {'displayName': 'Julien MARTIN'},
      '_count': {'photos': 4},
    },
    {
      'id': 'v2',
      'createdAt': '2026-09-05T10:00:00.000Z',
      '_count': {'photos': 0},
    },
  ],
  'ca': {
    'anneeN': 2026,
    'courbeN': [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 200, 0],
    'courbeN1': [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 50],
  },
};

class _Api implements ApiLecture {
  final Map<String, Object?> reponses = {};
  Object? erreur;

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    if (erreur != null) throw erreur!;
    final r = reponses[chemin];
    if (r is ErreurApi) throw r;
    return r;
  }
}

void main() {
  setUp(() {
    DemoTemps.reel = true;
    DemoTemps.maintenant = () => DateTime(2026, 11, 16);
  });
  tearDown(() {
    DemoTemps.reel = false;
    DemoTemps.maintenant = DateTime.now;
  });

  group('ficheClientDepuisJson', () {
    test('contacts, notes, visites, commandes, CA 12 mois, coordonnées', () {
      final f = ficheClientDepuisJson('c1', _detail(), _historique());
      expect(f.contacts, hasLength(1));
      expect(f.contacts.single.nom, 'Mme Girard');
      expect(f.contacts.single.telephone, '0607080910');
      expect(f.contacts.single.poste, 'Chef de rayon');
      expect(f.notes.single.texte, 'Demande une tête de gondole');
      expect(f.notes.single.auteur, 'Nadia H.');
      expect(f.visites, hasLength(2));
      expect(f.visitesMois, 1);
      expect(f.visites.first.photos, 4);
      expect(f.commandes.map((c) => c.id), ['CDE-9']);
      expect(f.derniereCommande!.magasinId, 'c1');
      expect(f.derniereCommande!.statut, StatutLivraison.pasLivree);
      expect(f.derniereCommande!.transporteur, 'Geodis');
      // 11 mois de 2026 (10 x 100 + 200) + décembre 2025 (50)
      expect(f.ca12Mois, 1250);
      expect(f.telephone, '0102030405');
      expect(f.centrale, 'Carrefour');
      expect(f.secteur, 'Yvelines');
      expect(f.commerciaux, ['Julien MARTIN']);
      expect(f.periodicite, 'Mensuelle');
    });

    test('sans historique (marketing) : fiche sans commandes ni CA', () {
      final f = ficheClientDepuisJson('c1', _detail(), null);
      expect(f.commandes, isEmpty);
      expect(f.visites, isEmpty);
      expect(f.ca12Mois, isNull);
      expect(f.contacts, hasLength(1));
    });

    test(
      'briefing : objectif annuel, CA du mois, visite, livraisons, variation',
      () {
        final detail = {
          ..._detail(),
          'objectifs': [
            {'annee': 2025, 'cibleCa': 1000},
            {'annee': 2026, 'cibleCa': 24000},
          ],
        };
        final histo = {
          ..._historique(),
          'commandes': [
            {
              'numero': 'CDE-1',
              'annulee': false,
              'statutLivraison': 'EXPEDIEE',
              'dateLivraison': '2026-11-12T08:00:00.000Z',
              'total': 10,
            },
            {
              'numero': 'CDE-2',
              'annulee': false,
              'statutLivraison': 'LIVREE',
              'total': 10,
            },
            {
              'numero': 'CDE-3',
              'annulee': true,
              'statutLivraison': 'PAS_LIVREE',
              'total': 10,
            },
          ],
        };
        final f = ficheClientDepuisJson('c1', detail, histo);
        expect(f.objectifAnnuel, 24000);
        expect(f.caMois, 200);
        expect(
          f.derniereVisite,
          DateTime.parse('2026-11-05T10:00:00.000Z').toLocal(),
        );
        expect(f.livraisons.map((l) => l.numero), ['CDE-1']);
        expect(f.livraisons.single.prevue, isNotNull);
        // 10 mois de 100 sur 10 mois de 10 : +900 %
        expect(f.variationCaPct, 900);
        final d = f.donneesBriefing;
        expect(d.periodicite, 'Mensuelle');
        expect(d.livraisons, hasLength(1));
      },
    );

    test('briefing : objectif absent, nul ou illisible', () {
      expect(
        ficheClientDepuisJson('c1', _detail(), _historique()).objectifAnnuel,
        isNull,
      );
      for (final o in <Object>[
        [
          {'annee': 2026, 'cibleCa': 0},
        ],
        [
          {'annee': 2026, 'cibleCa': 'abc'},
        ],
        'x',
      ]) {
        final f = ficheClientDepuisJson('c1', {
          ..._detail(),
          'objectifs': o,
        }, null);
        expect(f.objectifAnnuel, isNull);
      }
      // un montant en texte (Decimal sérialisé) est accepté
      final f = ficheClientDepuisJson('c1', {
        ..._detail(),
        'objectifs': [
          {'annee': 2026, 'cibleCa': '12000.00'},
        ],
      }, null);
      expect(f.objectifAnnuel, 12000);
    });

    test('montants courts', () {
      expect(euroCourt(29400), '29,4 k€');
      expect(euroCourt(840), '840 €');
    });
  });

  group('ficheClientProvider', () {
    late Directory dossier;
    late _Api api;

    setUp(() {
      dossier = Directory.systemTemp.createTempSync('crm_fiche_test_');
      api = _Api();
    });
    tearDown(() => dossier.deleteSync(recursive: true));

    Future<ProviderContainer> conteneur() async {
      final base = await ouvrirBaseChiffree(
        fichier: File('${dossier.path}/crm.db'),
        cleHex: _cle,
      );
      addTearDown(base.close);
      final c = ProviderContainer(
        overrides: [
          baseLocaleProvider.overrideWithValue(base),
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith(
            () => SessionNotifier(
              const Utilisateur(
                id: 'u',
                identifiant: 'x',
                nomAffiche: 'Jean DUPONT',
                email: null,
                roleApi: 'COMMERCIAL',
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<List<FicheClient?>> emissions(ProviderContainer c) async {
      final vues = <FicheClient?>[];
      c.listen(
        ficheClientProvider('c1'),
        (_, n) => n.whenData(vues.add),
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return vues;
    }

    test(
      'journal des appels et e-mails : téléchargé puis relu hors connexion',
      () async {
        api.reponses['/clients/c1/journal-contacts'] = {
          'data': [
            {
              'type': 'APPEL',
              'id': 'a1',
              'date': '2026-11-24T10:00:00.000Z',
              'resultat': 'MESSAGERIE',
              'auteur': 'Nadia H.',
            },
          ],
        };
        final c = await conteneur();
        Future<List<List<EntreeJournalContact>>> lire() async {
          final vues = <List<EntreeJournalContact>>[];
          c.listen(
            journalContactsProvider('c1'),
            (_, n) => n.whenData(vues.add),
            fireImmediately: true,
          );
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return vues;
        }

        final vues = await lire();
        expect(vues.single.single.resultat, ResultatAppel.messagerie);

        c.invalidate(journalContactsProvider('c1'));
        api.erreur = const ErreurApi(TypeErreurApi.reseau);
        final hors = await lire();
        expect(hors, isNotEmpty);
        expect(hors.first.single.auteur, 'Nadia H.');
      },
    );

    test('téléchargée puis relue hors connexion', () async {
      api.reponses['/clients/c1'] = _detail();
      api.reponses['/clients/c1/historique'] = _historique();
      final c = await conteneur();
      final vues = await emissions(c);
      expect(vues, hasLength(1));
      expect(vues.single!.contacts.single.nom, 'Mme Girard');

      c.invalidate(ficheClientProvider('c1'));
      api.erreur = const ErreurApi(TypeErreurApi.reseau);
      final hors = await emissions(c);
      expect(hors, isNotEmpty);
      expect(hors.first!.notes.single.auteur, 'Nadia H.');
    });

    test(
      'historique refusé (marketing) : la fiche s\'affiche quand même',
      () async {
        api.reponses['/clients/c1'] = _detail();
        api.reponses['/clients/c1/historique'] = const ErreurApi(
          TypeErreurApi.refuse,
        );
        final c = await conteneur();
        final vues = await emissions(c);
        expect(vues.single!.commandes, isEmpty);
        expect(vues.single!.contacts, hasLength(1));
      },
    );
  });
}
