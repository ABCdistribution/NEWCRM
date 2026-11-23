import 'dart:io';

import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/pem_serveur.dart';
import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/pem_provider.dart';
import 'package:crm_app/core/sync/referentiels_visite_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/accueil/support_pem.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

void main() {
  group('synchro des propositions PEM', () {
    late Directory dossier;
    late AppDatabase base;
    late FauxServeurPem serveur;

    setUp(() async {
      dossier = Directory.systemTemp.createTempSync('crm_pem_test_');
      base = await ouvrirBaseChiffree(
        fichier: File('${dossier.path}/crm.db'),
        cleHex: _cle,
      );
      serveur = FauxServeurPem()
        ..propositions['p1'] = propositionPem('p1', dateProposee: '2026-11-09')
        ..propositions['p2'] = propositionPem(
          'p2',
          clientId: 'm8',
          enseigne: 'U EXPRESS',
          ville: 'BOULOGNE',
          dateProposee: '2026-11-06',
          statut: 'ACCEPTEE',
        )
        ..propositions['p3'] = propositionPem('p3', statut: 'REALISEE')
        ..articles.addAll([
          articlePemApi('a1', libelle: 'Titanium 2'),
          articlePemApi('a2', libelle: 'Salon Series', marque: null),
        ]);
    });

    tearDown(() async {
      definirPropositionsPemServeur(null);
      // Laisse finir la relecture du planning lancée après accepter / reporter.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await base.close();
      dossier.deleteSync(recursive: true);
    });

    ProviderContainer conteneur({String? role = 'COMMERCIAL'}) {
      final c = ProviderContainer(
        overrides: [
          baseLocaleProvider.overrideWithValue(base),
          apiClientProvider.overrideWithValue(serveur),
          apiEcritureProvider.overrideWithValue(serveur),
          sessionProvider.overrideWith(
            () => SessionNotifier(
              role == null
                  ? null
                  : Utilisateur(
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
      c.listen(propositionsPemSynchroProvider, (_, _) {});
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        if (c.read(propositionsPemSynchroProvider).phase !=
            PhaseSynchro.chargement) {
          return;
        }
      }
    }

    test(
      'propositions ouvertes seulement, triées, relues hors connexion',
      () async {
        final c = conteneur();
        await attendreFin(c);
        expect(c.read(propositionsPemSynchroProvider).phase, PhaseSynchro.ok);
        final liste = c.read(propositionsPemProvider);
        expect(liste.map((p) => p.id), ['p2', 'p1']);
        expect(liste.first.statut, StatutPem.acceptee);
        expect(liste.last.clientNom, 'U EXPRESS – PARIS');
        expect(serveur.lectures.first, '/pem/propositions');
        expect(await base.enregistrements('pem_propositions'), hasLength(2));

        // Nouveau lancement sans réseau : la copie locale chiffrée sert.
        definirPropositionsPemServeur(null);
        serveur.erreurLecture = const ErreurApi(TypeErreurApi.reseau);
        final c2 = conteneur();
        await attendreFin(c2);
        expect(
          c2.read(propositionsPemSynchroProvider).phase,
          PhaseSynchro.horsLigne,
        );
        expect(c2.read(propositionsPemProvider).map((p) => p.id), ['p2', 'p1']);
      },
    );

    test('un autre rôle que le promoteur ne télécharge rien', () async {
      final c = conteneur(role: 'CHEF_SECTEUR');
      await attendreFin(c);
      expect(serveur.lectures, isEmpty);
      expect(c.read(propositionsPemProvider), isEmpty);
    });

    test(
      'accepter : appel à l’API, copie locale mise à jour, planning relu',
      () async {
        final c = conteneur();
        await attendreFin(c);
        final actions = c.read(actionsPemProvider);
        serveur.lectures.clear();
        final r = await actions.accepter('p1', date: '2026-11-10');
        expect(r.statut, StatutPem.acceptee);
        expect(r.dateProposee, '2026-11-10');
        expect(r.planningId, 'plan-p1');
        expect(serveur.ecritures.last.$1, 'POST');
        expect(serveur.ecritures.last.$2, '/pem/propositions/p1/accepter');
        expect(serveur.ecritures.last.$3, {'date': '2026-11-10'});
        final p1 = c
            .read(propositionsPemProvider)
            .firstWhere((p) => p.id == 'p1');
        expect(p1.statut, StatutPem.acceptee);
        expect(p1.dateProposee, '2026-11-10');
        expect(
          await base.enregistrement('pem_propositions', 'p1'),
          contains('ACCEPTEE'),
        );
        // Les lignes de planning créées par le CRM arrivent par la synchro du planning, relancée.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(serveur.lectures, contains('/plannings'));
        // Sans date : la date proposée reste.
        await actions.accepter('p2');
        expect(serveur.ecritures.last.$3, <String, Object?>{});
      },
    );

    test(
      'reporter trois fois : un report de moins à chaque fois, puis obligatoire',
      () async {
        final c = conteneur();
        await attendreFin(c);
        final actions = c.read(actionsPemProvider);
        PropositionPem p() =>
            c.read(propositionsPemProvider).firstWhere((x) => x.id == 'p1');

        var r = await actions.reporter(
          'p1',
          motif: ' Inventaire ',
          date: '2026-11-11',
        );
        expect(serveur.ecritures.last.$2, '/pem/propositions/p1/reporter');
        expect(serveur.ecritures.last.$3, {
          'motif': 'Inventaire',
          'date': '2026-11-11',
        });
        expect((r.nbReports, r.reportsRestants), (1, 2));
        expect(p().motifDernierReport, 'Inventaire');
        expect(p().dateProposee, '2026-11-11');

        // Motif vide : non envoyé.
        r = await actions.reporter('p1', motif: '  ', date: '2026-11-12');
        expect(serveur.ecritures.last.$3, {'date': '2026-11-12'});
        expect((r.nbReports, r.reportsRestants), (2, 1));
        expect(p().reportable, isTrue);

        r = await actions.reporter('p1', date: '2026-11-13');
        expect((r.nbReports, r.reportsRestants), (3, 0));
        expect(r.obligatoire, isTrue);
        expect(r.statut, StatutPem.acceptee);
        expect(p().obligatoire, isTrue);
        expect(p().reportable, isFalse);
      },
    );

    test('visite obligatoire : le message du CRM remonte tel quel', () async {
      serveur.propositions['p4'] = propositionPem(
        'p4',
        nbReports: 3,
        obligatoire: true,
      );
      final c = conteneur();
      await attendreFin(c);
      await expectLater(
        c.read(actionsPemProvider).reporter('p4', date: '2026-11-10'),
        throwsA(
          isA<ErreurApi>().having(
            (e) => e.message,
            'message',
            'Cette visite PEM est obligatoire : elle ne peut plus être reportée',
          ),
        ),
      );
      expect(c.read(propositionsPemProvider).any((p) => p.id == 'p4'), isTrue);
    });

    test(
      'date refusée ou réseau coupé : l’erreur remonte, la liste ne change pas',
      () async {
        final c = conteneur();
        await attendreFin(c);
        final actions = c.read(actionsPemProvider);
        await expectLater(
          actions.reporter('p1', date: '2026-12-31'),
          throwsA(isA<ErreurApi>()),
        );
        serveur.erreurEcriture = const ErreurApi(TypeErreurApi.reseau);
        await expectLater(
          actions.accepter('p1', date: '2026-11-10'),
          throwsA(
            isA<ErreurApi>().having(
              (e) => e.type,
              'type',
              TypeErreurApi.reseau,
            ),
          ),
        );
        final p1 = c
            .read(propositionsPemProvider)
            .firstWhere((x) => x.id == 'p1');
        expect(
          (p1.statut, p1.nbReports, p1.dateProposee),
          (StatutPem.proposee, 0, '2026-11-09'),
        );
      },
    );

    test(
      'articles PEM : copie locale puis API, relus hors connexion',
      () async {
        final c = conteneur();
        c.listen(articlesPemProvider, (_, _) {});
        final a = await c.read(articlesPemProvider.future);
        expect(a.map((x) => x.articleId), ['a1', 'a2']);
        expect(a.first.libelle, 'Titanium 2');
        expect(a.first.marque, 'Titanium');
        expect(a.last.marque, '');

        serveur.erreurLecture = const ErreurApi(TypeErreurApi.reseau);
        final c2 = conteneur();
        c2.listen(articlesPemProvider, (_, _) {});
        final hors = await c2.read(articlesPemProvider.future);
        expect(hors.map((x) => x.articleId), ['a1', 'a2']);
      },
    );
  });

  group('démonstration (sans session)', () {
    ProviderContainer demo() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test(
      'deux propositions fictives, dont une obligatoire ; articles fictifs',
      () async {
        final c = demo();
        final liste = c.read(propositionsPemProvider);
        expect(liste, hasLength(2));
        expect(liste.map((p) => p.obligatoire), [true, false]);
        expect(
          liste.first.dateProposee.compareTo(liste.last.dateProposee) < 0,
          isTrue,
        );
        c.listen(articlesPemProvider, (_, _) {});
        expect(await c.read(articlesPemProvider.future), isNotEmpty);
      },
    );

    test('accepter se simule localement', () async {
      final c = demo();
      final r = await c
          .read(actionsPemProvider)
          .accepter('pem-d1', date: '2026-11-10');
      expect(r.statut, StatutPem.acceptee);
      final p = c
          .read(propositionsPemProvider)
          .firstWhere((x) => x.id == 'pem-d1');
      expect(p.statut, StatutPem.acceptee);
      expect(p.dateProposee, '2026-11-10');
      // Hors fenêtre : refus avec un message en français.
      await expectLater(
        c.read(actionsPemProvider).accepter('pem-d1', date: '2026-12-31'),
        throwsA(isA<ErreurApi>()),
      );
    });

    test(
      'reporter se simule localement : le compteur baisse, obligatoire au troisième',
      () async {
        final c = demo();
        final actions = c.read(actionsPemProvider);
        PropositionPem p() =>
            c.read(propositionsPemProvider).firstWhere((x) => x.id == 'pem-d1');
        // La proposition de démonstration a déjà un report : deux restants.
        expect(p().reportsRestants, 2);
        await actions.reporter('pem-d1', motif: 'Salon', date: '2026-11-12');
        expect(p().reportsRestants, 1);
        expect(p().dateProposee, '2026-11-12');
        expect(p().obligatoire, isFalse);
        await actions.reporter('pem-d1', date: '2026-11-13');
        expect(p().reportsRestants, 0);
        expect(p().obligatoire, isTrue);
        expect(p().statut, StatutPem.acceptee);
        await expectLater(
          actions.reporter('pem-d1', date: '2026-11-14'),
          throwsA(
            isA<ErreurApi>().having(
              (e) => e.message,
              'message',
              contains('obligatoire'),
            ),
          ),
        );
      },
    );

    test('la proposition devenue obligatoire ne se reporte pas', () async {
      final c = demo();
      await expectLater(
        c.read(actionsPemProvider).reporter('pem-d2', date: '2026-11-10'),
        throwsA(isA<ErreurApi>().having((e) => e.statut, 'statut', 409)),
      );
    });

    test('date de report hors de la fenêtre refusée', () async {
      final c = demo();
      final actions = c.read(actionsPemProvider);
      for (final d in ['2026-11-04', '2026-11-19', 'demain']) {
        await expectLater(
          actions.reporter('pem-d1', date: d),
          throwsA(isA<ErreurApi>()),
          reason: d,
        );
      }
      expect(
        c
            .read(propositionsPemProvider)
            .firstWhere((p) => p.id == 'pem-d1')
            .nbReports,
        1,
      );
    });
  });
}
