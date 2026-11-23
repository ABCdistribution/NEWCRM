import 'dart:io';
import 'dart:typed_data';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/activite_serveur.dart';
import 'package:crm_app/core/data/equipe_serveur.dart';
import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:crm_app/core/sync/photos_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

Map<String, dynamic> _carte() => {
  'periode': {'annee': 2026, 'mois': 11},
  'regions': [
    {
      'id': 'r1',
      'nom': 'Île-de-France',
      'stats': {'visites': 30, 'commandes': 12, 'ca': 20000, 'objectif': 25000},
      'chefsSecteur': [
        {
          'id': 'cs1',
          'displayName': 'Nadia HADDAD',
          'secteur': {'id': 's1', 'nom': 'Yvelines'},
          'visites': 10,
          'commandes': 4,
          'ca': 8000,
          'objectif': 9000,
          'promoteurs': [
            {
              'id': 'p1',
              'displayName': 'Julien MARTIN',
              'nbClients': 42,
              'visites': 17,
              'commandes': 5,
              'ca': 4200,
              'objectif': null,
            },
          ],
        },
      ],
    },
  ],
};

class _Api implements ApiLecture, ApiOctets {
  final Map<String, Object?> reponses = {};
  final Map<String, List<int>?> photos = {};
  final List<String> appels = [];
  Object? erreur;

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    appels.add(chemin);
    if (erreur != null) throw erreur!;
    return reponses[chemin];
  }

  @override
  Future<List<int>?> octets(String chemin) async {
    appels.add(chemin);
    return photos[chemin];
  }
}

class _Ecriture implements ApiEcriture {
  final List<String> appels = [];
  Object? erreur;

  @override
  Future<Object?> envoyer(
    String methode,
    String chemin, {
    Object? corps,
  }) async {
    appels.add('$methode $chemin');
    if (erreur != null) throw erreur!;
    return null;
  }
}

void main() {
  tearDown(() {
    definirEquipeServeur(null);
    definirPerformanceServeur(null);
    definirNotificationsServeur(null);
  });

  group('équipe du CRM', () {
    test('chefs, promoteurs et totaux du périmètre', () {
      final e = equipeDepuisJson(_carte())!;
      expect(e.chefs.single.nom, 'Nadia HADDAD');
      expect(e.chefs.single.ini, 'NH');
      expect(e.chefs.single.region, 'Île-de-France');
      expect(e.chefs.single.secteur, 'Yvelines');
      expect(e.chefs.single.reel, isTrue);
      final p = e.parChef['cs1']!.single;
      expect(p.mag, 42);
      expect(p.v, 17);
      expect(p.commandes, 5);
      expect(p.real, 4200);
      expect(p.cible, 0);
      expect(p.obj, 0);
      expect(p.userId, 'p1');
      expect(e.total.real, 20000);
      expect(e.total.cible, 25000);
    });

    test('accesseurs : le CRM remplace la démonstration', () {
      expect(chefsActuels().first.id, 'n');
      definirEquipeServeur(equipeDepuisJson(_carte()));
      expect(chefsActuels().map((c) => c.id), ['cs1']);
      expect(promoteursDuChef('cs1'), hasLength(1));
      expect(promoteurActuelParNom('Julien MARTIN'), isNotNull);
      expect(promoteursDeMonEquipe(), hasLength(1));
      expect(chefActuelParId('cs1')!.nom, 'Nadia HADDAD');
    });

    test('réponse inattendue : ignorée', () {
      expect(equipeDepuisJson({'x': 1}), isNull);
    });
  });

  group('activité du promoteur', () {
    test('CA, objectif mensuel, visites', () {
      final p = performanceDepuisJson({
        'noRepr': false,
        'kpis': {'ca': 5100.5, 'visites': 7, 'commandes': 3},
        'objectif': {'cible': 6000},
      })!;
      expect(p.ca, 5100.5);
      expect(p.cible, 6000);
      expect(p.visites, 7);
      expect(p.commandes, 3);
    });

    test('compte sans code représentant : aucune activité', () {
      expect(performanceDepuisJson({'noRepr': true}), isNull);
    });
  });

  group('notifications', () {
    test('non lue : alerte avec émetteur ; lue ou sans titre : ignorée', () {
      final a = alerteDepuisNotification({
        'titre': 'Visite non effectuée',
        'message': 'Pensez à saisir votre visite',
        'luAt': null,
        'emetteur': {'displayName': 'Nadia H.'},
      })!;
      expect(a.titre, 'Visite non effectuée');
      expect(a.detail, 'Nadia H. · Pensez à saisir votre visite');
      expect(a.classe, isEmpty);
      expect(a.niveau, NiveauAlerte.haut);
      expect(a.magasinId, isNull);
      // Le magasin visé par le CRM (clientId) rattache la notification à sa fiche, sans lecture du texte.
      final liee = alerteDepuisNotification({
        'id': 'n9',
        'titre': 'Relance',
        'luAt': null,
        'clientId': 'c-42',
      })!;
      expect(liee.magasinId, 'c-42');
      expect(liee.notificationId, 'n9');
      expect(
        alerteDepuisNotification({'titre': 'x', 'luAt': '2026-11-01'}),
        isNull,
      );
      expect(alerteDepuisNotification({'titre': ' ', 'luAt': null}), isNull);
    });
  });

  group('synchro et photos', () {
    late Directory dossier;
    late AppDatabase base;
    late _Api api;
    late _Ecriture ecriture;

    setUp(() async {
      ecriture = _Ecriture();
      dossier = Directory.systemTemp.createTempSync('crm_eq_test_');
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
          apiEcritureProvider.overrideWithValue(ecriture),
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
      'chef de secteur : équipe téléchargée puis relue hors connexion',
      () async {
        api.reponses['/dashboard/carte-equipes'] = _carte();
        final c = conteneur('CHEF_SECTEUR');
        await attendre(c, equipeProvider);
        expect(c.read(equipeProvider).phase, PhaseSynchro.ok);
        expect(equipeServeur()!.chefs.single.id, 'cs1');

        definirEquipeServeur(null);
        api.erreur = Exception('hors ligne');
        final c2 = conteneur('CHEF_SECTEUR');
        await attendre(c2, equipeProvider);
        expect(equipeServeur()!.chefs.single.id, 'cs1');
      },
    );

    test('promoteur : activité du mois demandée', () async {
      api.reponses['/performances/me'] = {
        'noRepr': false,
        'kpis': {'ca': 100, 'visites': 2, 'commandes': 1},
        'objectif': {'cible': 500},
      };
      final c = conteneur('COMMERCIAL');
      await attendre(c, performanceProvider);
      expect(performanceServeur()!.ca, 100);
      expect(performanceServeur()!.cible, 500);
    });

    test('encadrement : l’activité personnelle n’est pas demandée', () async {
      final c = conteneur('CHEF_SECTEUR');
      await attendre(c, performanceProvider);
      expect(api.appels.contains('/performances/me'), isFalse);
    });

    test('notifications du CRM : non lues dans la cloche', () async {
      api.reponses['/notifications/me'] = {
        'nonLues': 1,
        'items': [
          {'titre': 'Relance', 'message': 'À faire', 'luAt': null},
          {'titre': 'Ancienne', 'message': '', 'luAt': '2026-11-01'},
        ],
      };
      final c = conteneur('COMMERCIAL');
      await attendre(c, notificationsSynchroProvider);
      expect(notificationsServeur().map((a) => a.titre), ['Relance']);
    });

    Map<String, dynamic> boite() => {
      'nonLues': 2,
      'items': [
        {'id': 'n1', 'titre': 'Relance', 'message': 'À faire', 'luAt': null},
        {'id': 'n2', 'titre': 'Rappel', 'message': '', 'luAt': null},
      ],
    };

    test(
      'marquer une notification comme lue : appel API, retirée de la cloche et de la copie locale',
      () async {
        api.reponses['/notifications/me'] = boite();
        final c = conteneur('COMMERCIAL');
        await attendre(c, notificationsSynchroProvider);
        expect(notificationsServeur().map((a) => a.notificationId), [
          'n1',
          'n2',
        ]);

        await c.read(notificationsSynchroProvider.notifier).marquerLue('n1');
        expect(ecriture.appels, ['PATCH /notifications/n1/lu']);
        expect(notificationsServeur().map((a) => a.titre), ['Rappel']);

        // Relue hors connexion : la notification lue ne revient pas.
        definirNotificationsServeur(null);
        api.erreur = Exception('hors ligne');
        final c2 = conteneur('COMMERCIAL');
        await attendre(c2, notificationsSynchroProvider);
        expect(notificationsServeur().map((a) => a.titre), ['Rappel']);
      },
    );

    test('tout marquer comme lu', () async {
      api.reponses['/notifications/me'] = boite();
      final c = conteneur('COMMERCIAL');
      await attendre(c, notificationsSynchroProvider);
      await c.read(notificationsSynchroProvider.notifier).toutMarquerLu();
      expect(ecriture.appels, ['POST /notifications/lu-tout']);
      expect(notificationsServeur(), isEmpty);
    });

    test('échec réseau : la notification reste dans la cloche', () async {
      api.reponses['/notifications/me'] = boite();
      final c = conteneur('COMMERCIAL');
      await attendre(c, notificationsSynchroProvider);
      ecriture.erreur = const ErreurApi(TypeErreurApi.reseau);
      await expectLater(
        c.read(notificationsSynchroProvider.notifier).marquerLue('n1'),
        throwsA(isA<ErreurApi>()),
      );
      expect(notificationsServeur(), hasLength(2));
    });

    test(
      'notification déjà supprimée du CRM (404) : retirée quand même',
      () async {
        api.reponses['/notifications/me'] = boite();
        final c = conteneur('COMMERCIAL');
        await attendre(c, notificationsSynchroProvider);
        ecriture.erreur = const ErreurApi(
          TypeErreurApi.inattendue,
          statut: 404,
        );
        await c.read(notificationsSynchroProvider.notifier).marquerLue('n2');
        expect(notificationsServeur().map((a) => a.titre), ['Relance']);
      },
    );

    test(
      'photos : moi et mon équipe, gardées en base, absente mémorisée',
      () async {
        api.reponses['/dashboard/carte-equipes'] = _carte();
        api.photos['/users/moi/photo'] = [1, 2, 3];
        api.photos['/users/cs1/photo'] = null;
        api.photos['/users/p1/photo'] = [9, 9];
        final c = conteneur('CHEF_SECTEUR');
        await attendre(c, equipeProvider);
        c.listen(photosProvider, (_, _) {});
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
          if (c.read(photosProvider).length == 2) break;
        }
        final photos = c.read(photosProvider);
        expect(photos['moi'], Uint8List.fromList([1, 2, 3]));
        expect(photos['p1'], Uint8List.fromList([9, 9]));
        expect(photos.containsKey('cs1'), isFalse);
        final stockees = {
          for (final l in await base.toutesLesPhotos()) l.id: l.octets.length,
        };
        expect(stockees, {'moi': 3, 'p1': 2, 'cs1': 0});
      },
    );
  });
}
