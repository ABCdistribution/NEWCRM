import 'dart:io';

import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/envois_base.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/envoi/file_envoi.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/faux_serveur_envoi.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _client = '11111111-1111-4111-8111-111111111111';
const _art = '33333333-3333-4333-8333-333333333331';
const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3];

Map<String, Object?> _visite(String idApk) => {
  'idApk': idApk,
  'clientId': _client,
  'typeVisite': 'COMMERCIALE',
  'etapes': [
    {'etape': 'debut', 'horodatage': '2026-11-04T13:23:00.000Z'},
  ],
};

Map<String, Object?> _commande(String idApk, {String statut = 'VALIDEE'}) => {
  'idCommandeApk': idApk,
  'clientId': _client,
  'dateCommande': '2026-11-23T09:30:00.000Z',
  'statut': statut,
  'lignes': [
    {'articleId': _art, 'quantite': 6, 'prixIndicatif': 12.5},
  ],
};

void main() {
  late Directory dossier;
  late File fichier;
  late AppDatabase base;
  late FauxServeurEnvoi serveur;
  late FileEnvoi file;

  FileEnvoi nouvelleFile() => FileEnvoi(
    base: base,
    ecriture: serveur,
    fichiers: serveur,
    maintenant: () => DateTime(2026, 11, 23, 10),
  );

  setUp(() async {
    dossier = Directory.systemTemp.createTempSync('crm_file_envoi_test_');
    fichier = File('${dossier.path}/crm.db');
    base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
    serveur = FauxServeurEnvoi();
    file = nouvelleFile();
  });

  tearDown(() async {
    await base.close();
    dossier.deleteSync(recursive: true);
  });

  Future<EnvoiLocal> visiteAvecPhotos(
    String idApk, {
    String locale = 'v218093',
    int nbPhotos = 2,
    String utilisateur = 'u',
  }) async {
    for (var i = 0; i < nbPhotos; i++) {
      // Une photo par étape (jusqu'à trois).
      await base.ajouterPhotoVisite(
        locale,
        const ['arrivee', 'rayonFin', 'rayonArrivee'][i],
        [..._jpeg, i],
      );
    }
    return file.enfilerVisite(
      utilisateurId: utilisateur,
      idApk: idApk,
      corps: _visite(idApk),
      visiteLocaleId: locale,
    );
  }

  group('écritures d\'activité (note, appel, e-mail)', () {
    const prospect = '22222222-2222-4222-8222-222222222222';

    Future<EnvoiLocal> note(String idApk, {String utilisateur = 'u'}) =>
        file.enfilerEcriture(
          utilisateurId: utilisateur,
          idApk: idApk,
          methode: 'POST',
          chemin: '/prospects/$prospect/notes',
          corps: {'remarque': 'Relancer', 'idApk': idApk},
          cible: 'prospect:$prospect',
          libelle: 'Note prospect',
        );

    test('une note est envoyée une fois, avec son idApk', () async {
      await note('N1');
      final r = await file.vider('u');
      expect(r.issue, IssueVidage.termine);
      expect(r.envoyes.single.refLocale, 'prospect:$prospect');
      expect(serveur.appels, ['POST /prospects/$prospect/notes']);
      expect(serveur.activites['N1']!['corps'], {
        'remarque': 'Relancer',
        'idApk': 'N1',
      });
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.envoye);
    });

    test(
      'réseau coupé : la note reste à envoyer puis part sans doublon',
      () async {
        await note('N1');
        serveur.horsLigne = true;
        expect((await file.vider('u')).issue, IssueVidage.reseau);
        expect((await base.envoisDe('u')).single.etat, EtatEnvoi.aEnvoyer);
        serveur.horsLigne = false;
        expect((await file.vider('u')).issue, IssueVidage.termine);
        expect(serveur.activites, hasLength(1));
        // Même clé : l'entrée existante est renvoyée, pas de seconde note.
        await note('N1');
        expect(await base.envoisDe('u'), hasLength(1));
      },
    );

    test('réponse perdue : le rejeu ne crée pas de seconde note', () async {
      await note('N1');
      await file.vider('u');
      // Le téléphone ignore que la note est partie et la renvoie : le CRM répond « déjà reçu ».
      final r = await serveur.envoyer(
        'POST',
        '/prospects/$prospect/notes',
        corps: {'remarque': 'Relancer', 'idApk': 'N1'},
      );
      expect((r! as Map)['dejaSynchronise'], isTrue);
      expect(serveur.activites, hasLength(1));
    });

    test(
      'refus (404 hors périmètre) : entrée en erreur avec son libellé',
      () async {
        await note('N1');
        serveur.refus['POST /prospects'] = erreurHttp(
          404,
          'Prospect introuvable',
        );
        final r = await file.vider('u');
        expect(r.issue, IssueVidage.termine);
        final e = (await base.envoisDe('u')).single;
        expect(e.etat, EtatEnvoi.erreur);
        expect(e.derniereErreur, 'Prospect introuvable');
        expect(libelleEnvoi(e.type, e.payload), 'Note prospect');
      },
    );

    test('chemin hors clients et prospects : refusé sans appel', () async {
      await file.enfilerEcriture(
        utilisateurId: 'u',
        idApk: 'X1',
        methode: 'POST',
        chemin: '/admin/utilisateurs',
        corps: {'idApk': 'X1'},
      );
      await file.vider('u');
      expect(serveur.appels, isEmpty);
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.erreur);
    });

    test('appel et e-mail : corps contrôlés comme ceux de l\'API', () async {
      await file.enfilerEcriture(
        utilisateurId: 'u',
        idApk: 'A1',
        methode: 'POST',
        chemin: '/clients/$_client/appels',
        corps: {'idApk': 'A1', 'dateAppel': '2026-11-25T09:00:00.000Z'},
      );
      await file.enfilerEcriture(
        utilisateurId: 'u',
        idApk: 'E1',
        methode: 'POST',
        chemin: '/clients/$_client/emails',
        corps: {
          'idApk': 'E1',
          'dateEmail': '2026-11-25T09:01:00.000Z',
          'destinataire': 'a@b.fr',
        },
      );
      final r = await file.vider('u');
      expect(r.envoyes, hasLength(2));
      expect(serveur.activites.keys, ['A1', 'E1']);
    });
  });

  group('visite et photos', () {
    test(
      'la visite est créée puis ses photos, une par étape, avec leur idApk',
      () async {
        await visiteAvecPhotos('Vabc');
        final r = await file.vider('u');
        expect(r.issue, IssueVidage.termine);
        expect(r.envoyes, hasLength(1));
        expect(serveur.appels.first, 'POST /visites');
        final id = serveur.visites['Vabc']!['id']! as String;
        expect(serveur.appels.skip(1), [
          'POST /visites/$id/photos',
          'POST /visites/$id/photos',
        ]);
        expect(serveur.photos, hasLength(2));
        expect(serveur.photos.values.map((p) => p['etape']).toSet(), {
          'arrivee',
          'rayonFin',
        });
        expect(
          serveur.photos.values.every((p) => p['mime'] == 'image/jpeg'),
          isTrue,
        );
        final e = (await base.envoisDe('u')).single;
        expect(e.etat, EtatEnvoi.envoye);
        expect(e.serveurId, id);
        expect(e.envoyeLe, isNotNull);
        expect(e.derniereErreur, isNull);
      },
    );

    test('une photo acceptée est effacée de l\'appareil', () async {
      final e = await visiteAvecPhotos('Vabc');
      expect(await base.photosDeVisite(refPhotosEnvoi('Vabc')), hasLength(2));
      await file.vider('u');
      expect(await base.photosDeVisite(refPhotosEnvoi('Vabc')), isEmpty);
      final fichiers = await base.fichiersDeEnvoi(e.id);
      expect(
        fichiers.every(
          (f) => f.etat == EtatFichierEnvoi.envoye && f.photoId == null,
        ),
        isTrue,
      );
    });

    test(
      'les photos quittent l\'identifiant local de la visite : une nouvelle visite du même numéro ne les reprend pas',
      () async {
        await visiteAvecPhotos('Vabc');
        expect(await base.photosDeVisite('v218093'), isEmpty);
        await base.ajouterPhotoVisite('v218093', 'arrivee', _jpeg);
        await visiteAvecPhotos('Vdef', nbPhotos: 0);
        // La seconde visite part avec la seule photo prise après la première.
        expect(
          await base.fichiersDeEnvoi((await base.envoisDe('u')).last.id),
          hasLength(1),
        );
      },
    );

    test(
      'plusieurs photos pour une étape (ancien brouillon) : seule la plus récente part',
      () async {
        await base.ajouterPhotoVisite('v218093', 'arrivee', [..._jpeg, 1]);
        await base.ajouterPhotoVisite('v218093', 'rayonArrivee', [..._jpeg, 2]);
        await base.ajouterPhotoVisite('v218093', 'arrivee', [..._jpeg, 3]);
        final e = await file.enfilerVisite(
          utilisateurId: 'u',
          idApk: 'Vabc',
          corps: _visite('Vabc'),
          visiteLocaleId: 'v218093',
        );
        final fichiers = await base.fichiersDeEnvoi(e.id);
        expect(fichiers.map((f) => f.etape), ['rayonArrivee', 'arrivee']);
        // Rien n'est perdu avant l'envoi : les trois photos restent sur le téléphone.
        expect(await base.photosDeVisite(refPhotosEnvoi('Vabc')), hasLength(3));

        await file.vider('u');
        expect(serveur.photos, hasLength(2));
        expect(serveur.photos.values.map((p) => p['etape']).toSet(), {
          'arrivee',
          'rayonArrivee',
        });
        expect(serveur.photos.values.every((p) => p['taille'] == 8), isTrue);
        final restantes = await base.photosDeVisite(refPhotosEnvoi('Vabc'));
        expect(restantes.single.octets, [
          ..._jpeg,
          1,
        ]); // l'ancienne photo, jamais envoyée
        expect((await base.envoisDe('u')).single.etat, EtatEnvoi.envoye);

        // La purge de l'entrée envoyée efface aussi l'ancienne photo.
        await base.purgerEnvoisEnvoyes(DateTime(2026, 12));
        expect(await base.photosDeVisite(refPhotosEnvoi('Vabc')), isEmpty);
      },
    );

    test('visite sans photo : un seul appel', () async {
      await visiteAvecPhotos('Vabc', nbPhotos: 0);
      await file.vider('u');
      expect(serveur.appels, ['POST /visites']);
    });

    test('type MIME d\'après les octets', () {
      expect(typeMimeImage(_jpeg), 'image/jpeg');
      expect(typeMimeImage([0x89, 0x50, 0x4E, 0x47, 0]), 'image/png');
      expect(typeMimeImage([]), 'image/jpeg');
    });
  });

  group('ordre', () {
    test('du plus ancien au plus récent, la visite avant ses photos', () async {
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00001'),
      );
      await visiteAvecPhotos('Vabc', nbPhotos: 1);
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00002'),
      );
      await file.vider('u');
      final id = serveur.visites['Vabc']!['id'];
      expect(serveur.appels, [
        'POST /commandes/apk',
        'POST /visites',
        'POST /visites/$id/photos',
        'POST /commandes/apk',
      ]);
    });

    test('les entrées d\'un autre utilisateur ne partent pas', () async {
      await file.enfilerCommande(
        utilisateurId: 'autre',
        corps: _commande('CMD00001'),
      );
      final r = await file.vider('u');
      expect(r.issue, IssueVidage.termine);
      expect(serveur.appels, isEmpty);
      expect((await base.envoisDe('autre')).single.etat, EtatEnvoi.aEnvoyer);
    });
  });

  group('réseau et reprise', () {
    test(
      'réseau coupé : l\'entrée reste à envoyer, puis part sans doublon',
      () async {
        await visiteAvecPhotos('Vabc');
        serveur.horsLigne = true;
        final r = await file.vider('u');
        expect(r.issue, IssueVidage.reseau);
        var e = (await base.envoisDe('u')).single;
        expect(e.etat, EtatEnvoi.aEnvoyer);
        expect(e.essais, 1);
        expect(e.derniereErreur, isNotNull);
        expect(serveur.visites, isEmpty);

        serveur.horsLigne = false;
        final r2 = await file.vider('u');
        expect(r2.issue, IssueVidage.termine);
        e = (await base.envoisDe('u')).single;
        expect(e.etat, EtatEnvoi.envoye);
        expect(e.essais, 2);
        expect(e.derniereErreur, isNull);
        expect(serveur.visites, hasLength(1));
        expect(serveur.photos, hasLength(2));
      },
    );

    test(
      'coupure en plein envoi des photos : la visite n\'est pas recréée, aucune photo en double',
      () async {
        await visiteAvecPhotos('Vabc', nbPhotos: 3);
        // La première photo passe, la deuxième trouve le réseau coupé.
        serveur.surAppel = (appel) {
          if (appel.endsWith('/photos') &&
              serveur.nbAppels('POST /visites/') == 2) {
            serveur.horsLigne = true;
          }
        };
        expect((await file.vider('u')).issue, IssueVidage.reseau);
        expect(serveur.photos, hasLength(1));

        serveur.surAppel = null;
        serveur.horsLigne = false;
        expect((await file.vider('u')).issue, IssueVidage.termine);
        expect(serveur.appels.where((a) => a == 'POST /visites'), hasLength(1));
        expect(serveur.visites, hasLength(1));
        expect(serveur.photos, hasLength(3));
        expect((await base.envoisDe('u')).single.etat, EtatEnvoi.envoye);
      },
    );

    test('erreur serveur 5xx et 429 : on retentera', () async {
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00001'),
      );
      serveur.pannes.add(erreurHttp(500, 'boum'));
      expect((await file.vider('u')).issue, IssueVidage.reseau);
      serveur.pannes.add(erreurHttp(429, 'Trop de requêtes'));
      expect((await file.vider('u')).issue, IssueVidage.reseau);
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.aEnvoyer);
      expect((await file.vider('u')).issue, IssueVidage.termine);
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.envoye);
    });

    test('reprise après redémarrage : une entrée en cours repart', () async {
      await visiteAvecPhotos('Vabc');
      final e = (await base.envoisDe('u')).single;
      // L'application a été tuée en plein envoi.
      await base.majEnvoi(e.id, etat: EtatEnvoi.enCours, essais: 1);
      await base.close();

      base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
      file = nouvelleFile();
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.enCours);
      final r = await file.vider('u');
      expect(r.envoyes, hasLength(1));
      expect(serveur.visites, hasLength(1));
      expect(serveur.photos, hasLength(2));
    });

    test('visite déjà reçue par le serveur : succès, pas de doublon', () async {
      await visiteAvecPhotos('Vabc');
      // Le serveur a déjà la visite (envoi précédent dont la réponse s'est perdue).
      await serveur.envoyer('POST', '/visites', corps: _visite('Vabc'));
      await file.vider('u');
      expect(serveur.visites, hasLength(1));
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.envoye);
    });
  });

  group('refus de l\'API', () {
    test(
      'erreur de validation : entrée en erreur avec le message, pas de boucle',
      () async {
        await file.enfilerCommande(
          utilisateurId: 'u',
          corps: _commande('CMD00001'),
        );
        serveur.refus['POST /commandes/apk'] = erreurHttp(
          400,
          'nePasLivrerAvant : la date ne peut pas être antérieure à aujourd\'hui',
        );
        final r = await file.vider('u');
        expect(r.issue, IssueVidage.termine);
        final e = (await base.envoisDe('u')).single;
        expect(e.etat, EtatEnvoi.erreur);
        expect(e.derniereErreur, contains('antérieure'));
        expect(e.essais, 1);

        // Un nouveau passage ne retente pas.
        await file.vider('u');
        expect(serveur.nbAppels('POST /commandes/apk'), 1);
        expect((await base.comptesEnvoi('u')), (aEnvoyer: 0, enErreur: 1));
      },
    );

    test('une entrée refusée ne bloque pas les suivantes', () async {
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00001'),
      );
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00002'),
      );
      serveur.pannes.add(erreurHttp(422, 'Refusée'));
      final r = await file.vider('u');
      expect(r.issue, IssueVidage.termine);
      final etats = (await base.envoisDe('u')).map((e) => e.etat).toList();
      expect(etats, [EtatEnvoi.erreur, EtatEnvoi.envoye]);
    });

    test('401 : session expirée, l\'entrée reste à envoyer', () async {
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00001'),
      );
      serveur.pannes.add(
        const ErreurApi(TypeErreurApi.sessionExpiree, statut: 401),
      );
      final r = await file.vider('u');
      expect(r.issue, IssueVidage.sessionExpiree);
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.aEnvoyer);
      expect((await file.vider('u')).issue, IssueVidage.termine);
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.envoye);
    });

    test('409 « déjà reçu » vaut succès', () async {
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00001'),
      );
      serveur.refus['POST /commandes/apk'] = erreurHttp(
        409,
        'Commande déjà reçue',
      );
      final r = await file.vider('u');
      expect(r.envoyes, hasLength(1));
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.envoye);
    });

    test('409 autre (proposition PEM plus ouverte) : en erreur', () async {
      await visiteAvecPhotos('Vabc', nbPhotos: 0);
      serveur.refus['POST /visites'] = erreurHttp(
        409,
        "Cette visite PEM n'est plus ouverte",
      );
      await file.vider('u');
      final e = (await base.envoisDe('u')).single;
      expect(e.etat, EtatEnvoi.erreur);
      expect(e.derniereErreur, "Cette visite PEM n'est plus ouverte");
    });

    test(
      'photo refusée : la visite part, les autres photos aussi, entrée en erreur',
      () async {
        await visiteAvecPhotos('Vabc', nbPhotos: 3);
        // La deuxième photo est refusée.
        serveur.pannes.addAll([
          null,
          null,
          erreurHttp(400, 'Le fichier doit être une image.'),
        ]);
        await file.vider('u');
        expect(serveur.visites, hasLength(1));
        expect(serveur.photos, hasLength(2));
        final e = (await base.envoisDe('u')).single;
        expect(e.etat, EtatEnvoi.erreur);
        expect(e.derniereErreur, contains('photo'));
        final etats = (await base.fichiersDeEnvoi(
          e.id,
        )).map((f) => f.etat).toList();
        expect(etats, [
          EtatFichierEnvoi.envoye,
          EtatFichierEnvoi.refuse,
          EtatFichierEnvoi.envoye,
        ]);
      },
    );

    test(
      'relance manuelle : l\'entrée repart, sans refaire ce qui est passé',
      () async {
        await visiteAvecPhotos('Vabc', nbPhotos: 2);
        serveur.pannes.addAll([
          null,
          null,
          erreurHttp(400, 'Le fichier doit être une image.'),
        ]);
        await file.vider('u');
        expect((await base.comptesEnvoi('u')).enErreur, 1);

        expect(await base.relancerEnvoisEnErreur('u'), 1);
        var e = (await base.envoisDe('u')).single;
        expect(e.etat, EtatEnvoi.aEnvoyer);
        expect(e.essais, 0);
        expect(e.derniereErreur, isNull);

        serveur.appels.clear();
        await file.vider('u');
        // La visite n'est pas recréée, seule la photo refusée est renvoyée.
        expect(serveur.appels, hasLength(1));
        expect(serveur.appels.single, endsWith('/photos'));
        expect(serveur.visites, hasLength(1));
        expect(serveur.photos, hasLength(2));
        e = (await base.envoisDe('u')).single;
        expect(e.etat, EtatEnvoi.envoye);
      },
    );
  });

  group('commande validée', () {
    test('créée en VALIDEE : un seul appel, rien à valider', () async {
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00001'),
      );
      await file.vider('u');
      expect(serveur.appels, ['POST /commandes/apk']);
      expect(serveur.commandes['CMD00001']!['statut'], 'VALIDEE');
    });

    test('rejouée : pas de doublon', () async {
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00001'),
      );
      // Réponse perdue : le serveur a la commande mais l'entrée est restée à envoyer.
      await serveur.envoyer(
        'POST',
        '/commandes/apk',
        corps: _commande('CMD00001'),
      );
      await file.vider('u');
      expect(serveur.commandes, hasLength(1));
      expect((await base.envoisDe('u')).single.etat, EtatEnvoi.envoye);
    });

    test(
      'même identifiant mis deux fois dans la file : une seule entrée',
      () async {
        final a = await file.enfilerCommande(
          utilisateurId: 'u',
          corps: _commande('CMD00001'),
        );
        final b = await file.enfilerCommande(
          utilisateurId: 'u',
          corps: _commande('CMD00001'),
        );
        expect(b.id, a.id);
        expect(await base.envoisDe('u'), hasLength(1));
      },
    );

    test(
      'un brouillon en attente portant le même identifiant est validé',
      () async {
        await serveur.envoyer(
          'POST',
          '/commandes/apk',
          corps: _commande('CMD00001', statut: 'EN_ATTENTE'),
        );
        expect(serveur.commandes['CMD00001']!['statut'], 'EN_ATTENTE');
        await file.enfilerCommande(
          utilisateurId: 'u',
          corps: _commande('CMD00001'),
        );
        await file.vider('u');
        final id = serveur.commandes['CMD00001']!['id'];
        expect(serveur.appels.last, 'POST /commandes/apk/$id/valider');
        expect(serveur.commandes['CMD00001']!['statut'], 'VALIDEE');
        expect(serveur.commandes, hasLength(1));
      },
    );

    test(
      'coupure entre la création et la validation : la validation reprend sans recréer',
      () async {
        await serveur.envoyer(
          'POST',
          '/commandes/apk',
          corps: _commande('CMD00001', statut: 'EN_ATTENTE'),
        );
        await file.enfilerCommande(
          utilisateurId: 'u',
          corps: _commande('CMD00001'),
        );
        serveur.pannes.addAll([null, const ErreurApi(TypeErreurApi.reseau)]);
        expect((await file.vider('u')).issue, IssueVidage.reseau);
        expect((await base.envoisDe('u')).single.serveurId, isNotNull);
        serveur.appels.clear();
        expect((await file.vider('u')).issue, IssueVidage.termine);
        expect(serveur.appels, hasLength(1));
        expect(serveur.appels.single, endsWith('/valider'));
        expect(serveur.commandes['CMD00001']!['statut'], 'VALIDEE');
      },
    );
  });

  group('purge', () {
    test('les entrées envoyées depuis plus de 7 jours disparaissent', () async {
      await file.enfilerCommande(
        utilisateurId: 'u',
        corps: _commande('CMD00001'),
      );
      await file.vider('u');
      // Envoyée « maintenant » (10 h le 23/11) : gardée.
      await file.vider('u');
      expect(await base.envoisDe('u'), hasLength(1));
      final plusTard = FileEnvoi(
        base: base,
        ecriture: serveur,
        fichiers: serveur,
        maintenant: () => DateTime(2026, 12, 5),
      );
      await plusTard.vider('u');
      expect(await base.envoisDe('u'), isEmpty);
    });

    test(
      'au démarrage, les photos de visites abandonnées sont effacées',
      () async {
        await base.ajouterPhotoVisite('v218093', 'arrivee', _jpeg);
        await visiteAvecPhotos('Vabc', locale: 'v2', nbPhotos: 1);
        await base.purgerPhotosOrphelines();
        expect(await base.photosDeVisite('v218093'), isEmpty);
        // Celles d'une visite en file sont gardées.
        expect(await base.photosDeVisite(refPhotosEnvoi('Vabc')), hasLength(1));
      },
    );
  });
}
