import 'dart:io';
import 'dart:math';

import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:crm_app/features/commandes/logic/attente_crm.dart';
import 'package:crm_app/features/commandes/logic/attente_crm_corps.dart';
import 'package:crm_app/features/commandes/state/commande_en_cours.dart';
import 'package:crm_app/features/commandes/state/commande_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/commandes/support_attente_crm.dart';
import '../../support/app_test_support.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

CommandeAttenteCrm _commande(
  String id, {
  DateTime? date,
  String commentaire = '',
}) => CommandeAttenteCrm(
  id: id,
  idApk: 'APK$id',
  clientId: 'm8',
  clientNom: 'U EXPRESS – BOULOGNE',
  lignes: const [LigneAttenteCrm(articleId: 'a2', quantite: 12)],
  totalIndicatif: 10,
  date: date,
  commentaire: commentaire,
);

void main() {
  group('commandeAttenteDepuisJson', () {
    test('détail : client, lignes, total, e-mail, envoi', () {
      final c = commandeAttenteDepuisJson(
        detailAttente(
          'c1',
          commentaire: 'Prévenir le chef de rayon',
          emailValidation: 'chef@exemple.fr',
          emailEnvoyeLe: '2026-11-11T10:00:00.000Z',
        ),
      )!;
      expect(c.id, 'c1');
      expect(c.idApk, 'APKc1');
      expect(c.clientId, 'm8');
      expect(c.clientNom, 'U EXPRESS – BOULOGNE');
      expect(c.clientEmail, 'magasin@exemple.fr');
      expect(c.nbLignes, 2);
      expect(c.lignes.first.articleId, 'a2');
      expect(c.lignes.first.quantite, 12);
      // 22,62 × 12 + 16,28 × 24 : le prix d'une ligne peut arriver en texte (décimal).
      expect(c.totalIndicatif, closeTo(662.16, 0.001));
      expect(c.lignes.last.prixIndicatif, 16.28);
      expect(c.commentaire, 'Prévenir le chef de rayon');
      expect(c.emailValidation, 'chef@exemple.fr');
      expect(c.envoyee, isTrue);
      expect(c.date, isNotNull);
    });

    test('ligne de liste sans détail : nombre de lignes et total donnés', () {
      final c = commandeAttenteDepuisJson({
        'id': 'c2',
        'idCommandeApk': 'APKc2',
        'statut': 'EN_ATTENTE',
        'dateCommande': '2026-11-10T09:30:00.000Z',
        'nbLignes': 3,
        'totalIndicatif': 40.5,
        'client': {'id': 'm1', 'enseigne': 'CARREFOUR', 'ville': null},
      })!;
      expect(c.totalIndicatif, 40.5);
      expect(c.clientNom, 'CARREFOUR');
      expect(c.envoyee, isFalse);
      expect(c.clientEmail, isNull);
    });

    test('commande validée ou sans client : ignorée', () {
      expect(
        commandeAttenteDepuisJson(detailAttente('c3', statut: 'VALIDEE')),
        isNull,
      );
      expect(
        commandeAttenteDepuisJson({'id': 'c4', 'statut': 'EN_ATTENTE'}),
        isNull,
      );
    });
  });

  test('tri : la plus récente d’abord, sans date en dernier', () {
    final t = trierAttentes([
      _commande('vieille', date: DateTime(2026, 11, 3)),
      _commande('sans'),
      _commande('recente', date: DateTime(2026, 11, 10, 14)),
      _commande('milieu', date: DateTime(2026, 11, 8)),
    ]);
    expect(t.map((c) => c.id), ['recente', 'milieu', 'vieille', 'sans']);
  });

  test('date affichée : jour, mois court et heure', () {
    expect(libelleDateAttente(DateTime(2026, 11, 3, 7, 5)), '3 nov. 07:05');
  });

  group('consigne « ne pas livrer avant » lue de l’API', () {
    test('champs de l’API : date, motif, remarque inchangée', () {
      final c = commandeAttenteDepuisJson(
        detailAttente(
          'c1',
          commentaire: 'Prévenir le chef de rayon',
          nePasLivrerAvant: '2026-11-16',
          motifNePasLivrerAvant: 'Inventaire',
        ),
      )!;
      expect(c.nePasLivrerAvant, '2026-11-16');
      expect(c.motifNePasLivrerAvant, 'Inventaire');
      expect(c.commentaire, 'Prévenir le chef de rayon');
      expect(c.consigneHeritee, isFalse);
      expect(libelleJourMois('2026-11-16'), '16/11');
    });

    test('date avec heure : seul le jour est gardé ; sans consigne : nulle', () {
      final c = commandeAttenteDepuisJson(
        detailAttente(
          'c1',
          nePasLivrerAvant: '2026-11-16T00:00:00.000Z',
          motifNePasLivrerAvant: 'Impératif',
        ),
      )!;
      expect(c.nePasLivrerAvant, '2026-11-16');
      final sans = commandeAttenteDepuisJson(detailAttente('c2'))!;
      expect(sans.nePasLivrerAvant, isNull);
      expect(sans.motifNePasLivrerAvant, isNull);
    });

    test('ancien format : la première ligne du commentaire est relue puis retirée', () {
      final c = commandeAttenteDepuisJson(
        detailAttente(
          'c1',
          commentaire:
              '⏳ Ne pas livrer avant le 2026-11-16 · Inventaire\nPrévenir le chef de rayon',
        ),
      )!;
      expect(c.nePasLivrerAvant, '2026-11-16');
      expect(c.motifNePasLivrerAvant, 'Inventaire');
      expect(c.commentaire, 'Prévenir le chef de rayon');
      expect(c.consigneHeritee, isTrue);
      final seule = commandeAttenteDepuisJson(
        detailAttente('c2', commentaire: '⏳ Ne pas livrer avant le 2026-12-01'),
      )!;
      expect(seule.nePasLivrerAvant, '2026-12-01');
      expect(seule.motifNePasLivrerAvant, isNull);
      expect(seule.commentaire, '');
    });

    test('les champs de l’API l’emportent ; une ligne restée dans le commentaire n’est plus affichée', () {
      final c = commandeAttenteDepuisJson(
        detailAttente(
          'c1',
          commentaire: '⏳ Ne pas livrer avant le 2026-11-16 · Inventaire\nNote',
          nePasLivrerAvant: '2026-12-01',
          motifNePasLivrerAvant: 'Impératif',
        ),
      )!;
      expect(c.nePasLivrerAvant, '2026-12-01');
      expect(c.motifNePasLivrerAvant, 'Impératif');
      expect(c.commentaire, 'Note');
      expect(c.consigneHeritee, isFalse);
    });

    test('commentaire ordinaire : rendu tel quel', () {
      final r = consigneDepuisCommentaire(' Bonjour ');
      expect(r.pas, isFalse);
      expect(r.note, 'Bonjour');
    });
  });

  test('adresse e-mail : format', () {
    expect(emailValide('chef@exemple.fr'), isTrue);
    expect(emailValide('  chef.rayon@mail.exemple.fr '), isTrue);
    expect(emailValide(''), isFalse);
    expect(emailValide('chef@exemple'), isFalse);
    expect(emailValide('chef exemple@mail.fr'), isFalse);
    expect(emailValide('@exemple.fr'), isFalse);
  });

  test('identifiant mobile : 10 caractères alphanumériques', () {
    final a = genererIdApk(Random(1));
    expect(a, matches(r'^[A-Za-z0-9]{10}$'));
    expect(genererIdApk(Random(1)), a);
    expect(genererIdApk(), matches(r'^[A-Za-z0-9]{10}$'));
  });

  group('corps des appels', () {
    double? prix(String id) => {'a2': 22.62, 'a9': 16.28}[id];
    final cmd = CommandeEnCours(
      magasinId: 'm8',
      lignes: const [LigneCommande('a2', 12), LigneCommande('a9', 24)],
      note: 'Remarque',
      pas: true,
      dateMin: '2026-11-16',
      motifPas: 'Autre',
      motifAutre: 'Travaux',
    );

    test('création : UUID, quantités, prix, remarque et consigne en champs séparés', () {
      final corps = corpsCreation(
        cmd,
        idApk: 'ABCD123456',
        maintenant: DateTime.utc(2026, 11, 10, 9, 30),
        prixDe: prix,
      );
      expect(corps['idCommandeApk'], 'ABCD123456');
      expect(corps['clientId'], 'm8');
      expect(corps['statut'], 'EN_ATTENTE');
      expect(corps['dateCommande'], '2026-11-10T09:30:00.000Z');
      expect(corps['commentaire'], 'Remarque');
      expect(corps['nePasLivrerAvant'], '2026-11-16');
      expect(corps['motifNePasLivrerAvant'], 'Travaux');
      expect(corps.containsKey('emailValidation'), isFalse);
      expect(corps['lignes'], [
        {'articleId': 'a2', 'quantite': 12, 'prixIndicatif': 22.62},
        {'articleId': 'a9', 'quantite': 24, 'prixIndicatif': 16.28},
      ]);
    });

    test('modification : rien si rien n’a changé', () {
      final crm = commandeAttenteDepuisJson(
        detailAttente(
          'c1',
          commentaire: 'Remarque',
          nePasLivrerAvant: '2026-11-16',
          motifNePasLivrerAvant: 'Travaux',
        ),
      )!;
      expect(corpsModification(cmd, crm, prix), isEmpty);
    });

    test('modification : lignes changées, remarque effacée', () {
      final crm = commandeAttenteDepuisJson(
        detailAttente('c1', commentaire: 'Ancienne'),
      )!;
      final modifiee = CommandeEnCours(
        magasinId: 'm8',
        lignes: const [LigneCommande('a2', 6), LigneCommande('a9', 24)],
      );
      final corps = corpsModification(modifiee, crm, prix);
      expect(corps['lignes'], [
        {'articleId': 'a2', 'quantite': 6, 'prixIndicatif': 22.62},
        {'articleId': 'a9', 'quantite': 24, 'prixIndicatif': 16.28},
      ]);
      expect(corps.containsKey('commentaire'), isTrue);
      expect(corps['commentaire'], isNull);
    });

    test('modification : consigne retirée = nePasLivrerAvant null ; changée = date et motif', () {
      final crm = commandeAttenteDepuisJson(
        detailAttente(
          'c1',
          nePasLivrerAvant: '2026-11-16',
          motifNePasLivrerAvant: 'Travaux',
        ),
      )!;
      final sans = corpsModification(
        const CommandeEnCours(
          magasinId: 'm8',
          lignes: [LigneCommande('a2', 12), LigneCommande('a9', 24)],
        ),
        crm,
        prix,
      );
      expect(sans, {'nePasLivrerAvant': null});
      final autre = corpsModification(
        const CommandeEnCours(
          magasinId: 'm8',
          lignes: [LigneCommande('a2', 12), LigneCommande('a9', 24)],
          pas: true,
          dateMin: '2026-12-01',
          motifPas: 'Inventaire',
        ),
        crm,
        prix,
      );
      expect(autre, {
        'nePasLivrerAvant': '2026-12-01',
        'motifNePasLivrerAvant': 'Inventaire',
      });
    });

    test('consigne incomplète (sans motif) : non envoyée', () {
      final corps = corpsCreation(
        const CommandeEnCours(
          magasinId: 'm8',
          lignes: [LigneCommande('a2', 1)],
          pas: true,
          dateMin: '2026-11-16',
        ),
        idApk: 'ABCD123456',
        maintenant: DateTime.utc(2026, 11, 10),
        prixDe: prix,
      );
      expect(corps.containsKey('nePasLivrerAvant'), isFalse);
      expect(corps.containsKey('motifNePasLivrerAvant'), isFalse);
    });

    test('ancien format : le premier enregistrement migre la consigne et nettoie le commentaire', () {
      final crm = commandeAttenteDepuisJson(
        detailAttente(
          'c1',
          commentaire: '⏳ Ne pas livrer avant le 2026-11-16 · Travaux\nRemarque',
        ),
      )!;
      expect(corpsModification(cmd, crm, prix), {
        'commentaire': 'Remarque',
        'nePasLivrerAvant': '2026-11-16',
        'motifNePasLivrerAvant': 'Travaux',
      });
    });

    test('article inconnu de l’app : il garde le prix du CRM', () {
      final crm = commandeAttenteDepuisJson(detailAttente('c1'))!;
      final corps = corpsModification(
        const CommandeEnCours(
          magasinId: 'm8',
          lignes: [LigneCommande('a2', 1), LigneCommande('a9', 5)],
        ),
        crm,
        (_) => null,
      );
      final lignes = corps['lignes']! as List;
      expect(lignes.last, {
        'articleId': 'a9',
        'quantite': 5,
        'prixIndicatif': 16.28,
      });
    });
  });

  test('reprise dans le panier : client, lignes, remarque et consigne', () {
    final c = conteneurPour(Role.promoteur);
    final crm = commandeAttenteDepuisJson(
      detailAttente(
        'c1',
        commentaire: 'Remarque',
        nePasLivrerAvant: '2026-11-16',
        motifNePasLivrerAvant: 'Travaux',
      ),
    )!;
    c.read(commandeEnCoursProvider.notifier).reprendreCrm(crm);
    final cmd = c.read(commandeEnCoursProvider)!;
    expect(cmd.magasinId, 'm8');
    expect(cmd.lignes.map((l) => (l.produitId, l.qty)), [
      ('a2', 12),
      ('a9', 24),
    ]);
    expect(cmd.note, 'Remarque');
    expect(cmd.pas, isTrue);
    expect(cmd.dateMin, '2026-11-16');
    expect(cmd.motifPas, 'Autre');
    expect(cmd.motifAutre, 'Travaux');
    expect(cmd.crm?.id, 'c1');
    expect(cmd.idApk, 'APKc1');
  });

  test('reprise : motif de la liste sélectionné, ancien format relu', () {
    final c = conteneurPour(Role.promoteur);
    c
        .read(commandeEnCoursProvider.notifier)
        .reprendreCrm(
          commandeAttenteDepuisJson(
            detailAttente(
              'c1',
              nePasLivrerAvant: '2026-11-16',
              motifNePasLivrerAvant: 'Inventaire',
            ),
          )!,
        );
    var cmd = c.read(commandeEnCoursProvider)!;
    expect((cmd.motifPas, cmd.motifAutre), ('Inventaire', ''));
    c
        .read(commandeEnCoursProvider.notifier)
        .reprendreCrm(
          commandeAttenteDepuisJson(
            detailAttente(
              'c1',
              commentaire: '⏳ Ne pas livrer avant le 2026-11-16 · Travaux\nNote',
            ),
          )!,
        );
    cmd = c.read(commandeEnCoursProvider)!;
    expect((cmd.pas, cmd.dateMin, cmd.motifPas, cmd.motifAutre, cmd.note), (
      true,
      '2026-11-16',
      'Autre',
      'Travaux',
      'Note',
    ));
  });

  group('ErreurApi des écritures', () {
    test('le message français de l’API est gardé tel quel', () {
      final e = ErreurApi.depuisReponse(
        409,
        '{"statusCode":409,"message":"Commande déjà validée : modification impossible","error":"Conflict"}',
      );
      expect(e.message, 'Commande déjà validée : modification impossible');
      expect(e.statut, 409);
      expect(
        ErreurApi.depuisReponse(
          503,
          '{"statusCode":503,"message":"Envoi de mail non configuré"}',
        ).message,
        'Envoi de mail non configuré',
      );
      expect(
        ErreurApi.depuisReponse(
          400,
          '{"statusCode":400,"message":["Adresse e-mail invalide","autre"]}',
        ).message,
        'Adresse e-mail invalide autre',
      );
    });

    test('session expirée, panne du serveur ou corps illisible', () {
      expect(
        ErreurApi.depuisReponse(401, '{"message":"Unauthorized"}').type,
        TypeErreurApi.sessionExpiree,
      );
      final e500 = ErreurApi.depuisReponse(500, '{"message":"Internal error"}');
      expect(e500.type, TypeErreurApi.serveur);
      expect(e500.message, contains('Réessayez plus tard'));
      expect(
        ErreurApi.depuisReponse(429, '<html>').message,
        'Réponse inattendue du serveur.',
      );
    });
  });

  group('synchro des commandes en attente', () {
    late Directory dossier;
    late AppDatabase base;
    late FauxServeurCommandes serveur;

    setUp(() async {
      dossier = Directory.systemTemp.createTempSync('crm_attente_test_');
      base = await ouvrirBaseChiffree(
        fichier: File('${dossier.path}/crm.db'),
        cleHex: _cle,
      );
      serveur = FauxServeurCommandes()
        ..commandes['c1'] = detailAttente(
          'c1',
          date: '2026-11-10T09:30:00.000Z',
        )
        ..commandes['c2'] = detailAttente(
          'c2',
          date: '2026-11-12T15:00:00.000Z',
          emailValidation: 'chef@exemple.fr',
          emailEnvoyeLe: '2026-11-12T16:00:00.000Z',
        )
        ..commandes['c3'] = detailAttente('c3', statut: 'VALIDEE');
    });

    tearDown(() async {
      definirAttentesServeur(null);
      await base.close();
      dossier.deleteSync(recursive: true);
    });

    ProviderContainer conteneur({String role = 'COMMERCIAL'}) {
      final c = ProviderContainer(
        overrides: [
          baseLocaleProvider.overrideWithValue(base),
          apiClientProvider.overrideWithValue(serveur),
          apiEcritureProvider.overrideWithValue(serveur),
          sessionProvider.overrideWith(
            () => SessionNotifier(
              Utilisateur(
                id: 'u',
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

    Future<void> attendreFin(ProviderContainer c) async {
      c.listen(commandesAttenteSynchroProvider, (_, _) {});
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        if (c.read(commandesAttenteSynchroProvider).phase !=
            PhaseSynchro.chargement) {
          return;
        }
      }
    }

    test(
      'seules les commandes en attente, détail compris, triées, relues hors connexion',
      () async {
        final c = conteneur();
        await attendreFin(c);
        expect(c.read(commandesAttenteSynchroProvider).phase, PhaseSynchro.ok);
        final liste = c.read(attentesCrmProvider);
        expect(liste.map((x) => x.id), ['c2', 'c1']);
        expect(liste.first.envoyee, isTrue);
        expect(liste.last.nbLignes, 2);
        expect(c.read(attentesCrmProvider).length, 2); // compteur de l'onglet
        expect(serveur.lectures.first, '/commandes/apk');
        expect(await base.enregistrements('commandes_attente'), hasLength(2));

        // Nouveau lancement sans réseau : la copie locale (lignes comprises) sert.
        definirAttentesServeur(null);
        serveur.erreurLecture = const ErreurApi(TypeErreurApi.reseau);
        final c2 = conteneur();
        await attendreFin(c2);
        expect(
          c2.read(commandesAttenteSynchroProvider).phase,
          PhaseSynchro.horsLigne,
        );
        expect(c2.read(attentesCrmProvider).map((x) => x.id), ['c2', 'c1']);
        expect(c2.read(attentesCrmProvider).last.lignes.first.articleId, 'a2');
      },
    );

    test('un autre rôle que le promoteur ne télécharge rien', () async {
      final c = conteneur(role: 'CHEF_SECTEUR');
      await attendreFin(c);
      expect(serveur.lectures, isEmpty);
      expect(c.read(attentesCrmProvider), isEmpty);
    });

    test('créer, modifier, envoyer par mail, valider, supprimer', () async {
      final c = conteneur();
      await attendreFin(c);
      final synchro = c.read(commandesAttenteSynchroProvider.notifier);

      final cree = await synchro.creer({
        'idCommandeApk': 'NEWAPK0001',
        'clientId': 'm1',
        'dateCommande': '2026-11-13T08:00:00.000Z',
        'statut': 'EN_ATTENTE',
        'lignes': [
          {'articleId': 'a1', 'quantite': 6, 'prixIndicatif': 3.5},
        ],
      });
      expect(cree.idApk, 'NEWAPK0001');
      expect(c.read(attentesCrmProvider), hasLength(3));
      expect(await base.enregistrements('commandes_attente'), hasLength(3));
      // Un renvoi du même identifiant (coupure) ne crée pas de doublon.
      await synchro.creer({
        'idCommandeApk': 'NEWAPK0001',
        'clientId': 'm1',
        'dateCommande': '2026-11-13T08:00:00.000Z',
        'lignes': [
          {'articleId': 'a1', 'quantite': 6},
        ],
      });
      expect(c.read(attentesCrmProvider), hasLength(3));

      final maj = await synchro.modifier(cree.id, {'commentaire': 'Remarque'});
      expect(maj.commentaire, 'Remarque');
      expect(
        c
            .read(attentesCrmProvider)
            .firstWhere((x) => x.id == cree.id)
            .commentaire,
        'Remarque',
      );

      final envoyee = await synchro.envoyerMail(cree.id, 'client@exemple.fr');
      expect(envoyee.envoyee, isTrue);
      expect(envoyee.emailValidation, 'client@exemple.fr');
      expect(serveur.ecritures.last.$2, endsWith('/envoyer-mail'));
      expect(serveur.ecritures.last.$3, {'email': 'client@exemple.fr'});

      await synchro.valider('c1');
      expect(
        c.read(attentesCrmProvider).map((x) => x.id),
        isNot(contains('c1')),
      );
      expect(await base.enregistrement('commandes_attente', 'c1'), isNull);

      await synchro.supprimer('c2');
      expect(c.read(attentesCrmProvider).map((x) => x.id), [cree.id]);
      // Déjà supprimée côté CRM (404) : elle disparaît quand même.
      serveur.erreurEcriture = const ErreurApi(
        TypeErreurApi.inattendue,
        statut: 404,
      );
      await synchro.supprimer(cree.id);
      expect(c.read(attentesCrmProvider), isEmpty);
    });

    test(
      'échec d’une écriture : l’erreur remonte et la liste ne change pas',
      () async {
        final c = conteneur();
        await attendreFin(c);
        final synchro = c.read(commandesAttenteSynchroProvider.notifier);
        serveur.erreurEcriture = ErreurApi.depuisReponse(
          409,
          '{"message":"Commande déjà validée"}',
        );
        await expectLater(
          synchro.modifier('c1', {'commentaire': 'x'}),
          throwsA(
            isA<ErreurApi>().having(
              (e) => e.message,
              'message',
              'Commande déjà validée',
            ),
          ),
        );
        expect(c.read(attentesCrmProvider), hasLength(2));
        serveur.erreurEcriture = const ErreurApi(TypeErreurApi.reseau);
        await expectLater(synchro.valider('c1'), throwsA(isA<ErreurApi>()));
        expect(c.read(attentesCrmProvider).map((x) => x.id), contains('c1'));
      },
    );
  });
}
