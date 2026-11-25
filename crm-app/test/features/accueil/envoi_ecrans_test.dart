import 'dart:io';

import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/referentiels_visite.dart';
import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/cle_base.dart';
import 'package:crm_app/core/db/envois_base.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/envoi/envoi_provider.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:crm_app/core/sync/referentiels_visite_provider.dart';
import 'package:crm_app/features/accueil/widgets/bloc_envoi.dart';
import 'package:crm_app/features/commandes/commande_actions.dart';
import 'package:crm_app/features/commandes/state/commande_provider.dart';
import 'package:crm_app/features/visites/valider_visite_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../../support/faux_serveur_envoi.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _client = '11111111-1111-4111-8111-111111111111';
const _art = '33333333-3333-4333-8333-333333333331';

const _promoteur = Utilisateur(
  id: 'u',
  identifiant: 'x',
  nomAffiche: 'Jean DUPONT',
  email: null,
  roleApi: 'COMMERCIAL',
);

class _StockageMemoire implements StockageSecret {
  final Map<String, String> valeurs = {};

  @override
  Future<String?> lire(String nom) async => valeurs[nom];

  @override
  Future<void> ecrire(String nom, String valeur) async => valeurs[nom] = valeur;
}

/// File d'envoi figée à un état donné ; `relancer` est compté.
class _EnvoiFixe extends EnvoiNotifier {
  _EnvoiFixe(this._etat);

  final EtatFileEnvoi _etat;
  int relances = 0;

  @override
  EtatFileEnvoi build() => _etat;

  @override
  Future<void> relancer() async => relances++;
}

class _Hote extends ConsumerWidget {
  const _Hote({required this.action});

  final void Function(BuildContext context, WidgetRef ref) action;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => action(context, ref),
        child: const Text('go'),
      ),
    ),
  );
}

void main() {
  setUpAll(chargerInter);

  group('pastille de la file d\'envoi', () {
    testWidgets('file vide : rien n\'est affiché', (tester) async {
      await pumpEcran(
        tester,
        const Scaffold(body: BlocEnvoi()),
        overrides: [
          envoiProvider.overrideWith(() => _EnvoiFixe(const EtatFileEnvoi())),
        ],
      );
      expect(find.text('Relancer'), findsNothing);
      expect(find.textContaining('à envoyer'), findsNothing);
    });

    testWidgets('à envoyer et en erreur : nombres, message, « Relancer »', (
      tester,
    ) async {
      final faux = _EnvoiFixe(
        const EtatFileEnvoi(
          aEnvoyer: 2,
          erreurs: [
            EnvoiEnErreur(
              id: 3,
              type: TypeEnvoi.commande,
              message: 'Article introuvable',
            ),
          ],
        ),
      );
      await pumpEcran(
        tester,
        const Scaffold(body: BlocEnvoi()),
        overrides: [envoiProvider.overrideWith(() => faux)],
      );
      expect(find.text('2 à envoyer'), findsOneWidget);
      expect(find.text('1 en erreur'), findsOneWidget);
      expect(find.text('Commande · Article introuvable'), findsOneWidget);
      await tester.tap(find.text('Relancer'));
      await tester.pump();
      expect(faux.relances, 1);
    });

    testWidgets('pendant un envoi : « Relancer » est inactif', (tester) async {
      final faux = _EnvoiFixe(const EtatFileEnvoi(aEnvoyer: 1, enCours: true));
      await pumpEcran(
        tester,
        const Scaffold(body: BlocEnvoi()),
        overrides: [envoiProvider.overrideWith(() => faux)],
      );
      await tester.tap(find.text('Relancer'));
      await tester.pump();
      expect(faux.relances, 0);
    });
  });

  group('branchement sur la validation (session réelle)', () {
    late Directory dossier;
    late AppDatabase base;
    late FauxServeurEnvoi serveur;

    setUp(() async {
      serveur = FauxServeurEnvoi();
    });

    /// Laisse la base et le réseau factice avancer (vrai temps), en faisant tourner la zone simulée du test.
    Future<void> attendreReel(
      WidgetTester tester,
      bool Function() fait, {
      int max = 200,
    }) async {
      for (var i = 0; i < max && !fait(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    Future<ProviderContainer> ouvrir(
      WidgetTester tester,
      void Function(BuildContext, WidgetRef) action, {
      bool connecte = true,
    }) async {
      await tester.runAsync(() async {
        dossier = Directory.systemTemp.createTempSync('crm_envoi_ecran_test_');
        base = await ouvrirBaseChiffree(
          fichier: File('${dossier.path}/crm.db'),
          cleHex: _cle,
        );
      });
      addTearDown(() async {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await base.close();
          dossier.deleteSync(recursive: true);
        });
      });
      await pumpEcran(
        tester,
        _Hote(action: action),
        overrides: [
          baseLocaleProvider.overrideWithValue(base),
          apiClientProvider.overrideWithValue(serveur),
          apiEcritureProvider.overrideWithValue(serveur),
          apiFichiersProvider.overrideWithValue(serveur),
          stockageSessionProvider.overrideWithValue(
            StockageSession(_StockageMemoire()),
          ),
          questionnaireProvider.overrideWith(
            (ref) => Stream.value(const <QuestionFin>[]),
          ),
          raisonsAbsenceProvider.overrideWith(
            (ref) => Stream.value(const <RaisonAbsence>[]),
          ),
          sessionProvider.overrideWith(
            () => SessionNotifier(connecte ? _promoteur : null),
          ),
        ],
      );
      final c = ProviderScope.containerOf(tester.element(find.byType(_Hote)));
      if (connecte) {
        // Les téléchargements de départ reconstruisent le store : on attend qu'ils soient finis.
        c.read(crmProvider);
        await attendreReel(
          tester,
          () => c
              .read(jeuxDeDonneesProvider)
              .every((j) => j.$2.phase != PhaseSynchro.chargement),
        );
        await attendreReel(tester, () => false, max: 3);
        await tester.pump();
      }
      return c;
    }

    testWidgets(
      'valider une visite : rangée dans la file avec sa clé, envoyée, jamais simulée',
      (tester) async {
        final c = await ouvrir(
          tester,
          (context, ref) => ouvrirValiderVisite(context, 'v218093'),
        );
        final store = c.read(crmProvider.notifier);
        final id = store.demarrerVisite(_client);
        store.majVisite(
          id,
          (v) => v.copyWith(
            chrono: {
              for (final e in EtapeDph.values)
                if (e != EtapeDph.indispensables && e != EtapeDph.articlesPem)
                  e: '04/11/2026 14h30',
            },
            photos: const {
              EtapeDph.arrivee: 1,
              EtapeDph.rayonArrivee: 1,
              EtapeDph.rayonFin: 1,
            },
            commandeEnRayon: true,
          ),
        );
        // Une visite en cours de saisie : le store n'est pas relu après l'envoi.
        store.demarrerVisitePem(_client, 'prop-1');
        await tester.runAsync(
          () => base.ajouterPhotoVisite(id, 'arrivee', [0xFF, 0xD8, 0xFF, 1]),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(find.text('Valider la visite ?'), findsOneWidget);
        await tester.tap(find.text('Valider'));
        await tester.pump();
        await attendreReel(
          tester,
          () => serveur.visites.isNotEmpty && serveur.photos.isNotEmpty,
        );
        await tester.pump();

        final corps = serveur.visites.values.single['corps']! as Map;
        expect(corps['clientId'], _client);
        expect(corps['commandeEnRayon'], isTrue);
        expect(corps['typeVisite'], 'COMMERCIALE');
        expect((corps['etapes'] as List), isNotEmpty);
        expect(serveur.photos.values.single['etape'], 'arrivee');
        await attendreReel(tester, () => !c.read(envoiProvider).enCours);
        await tester.pump();
        expect(c.read(envoiProvider).vide, isTrue);
        expect(c.read(crmProvider).visiteParId(id)!.etat, EtatVisite.envoyee);
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'démonstration : la visite n\'est pas rangée, l\'envoi reste simulé',
      (tester) async {
        final c = await ouvrir(
          tester,
          (context, ref) => ouvrirValiderVisite(context, 'v218093'),
          connecte: false,
        );
        final store = c.read(crmProvider.notifier);
        final id = store.demarrerVisite('m1');
        store.majVisite(
          id,
          (v) => v.copyWith(
            chrono: {
              for (final e in EtapeDph.values)
                if (e != EtapeDph.indispensables && e != EtapeDph.articlesPem)
                  e: '04/11/2026 14h30',
            },
            photos: const {
              EtapeDph.arrivee: 1,
              EtapeDph.rayonArrivee: 1,
              EtapeDph.rayonFin: 1,
            },
            commandeEnRayon: false,
          ),
        );
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();
        expect(c.read(crmProvider).visiteParId(id)!.etat, EtatVisite.terminee);
        await tester.pump(const Duration(seconds: 4));
        expect(c.read(crmProvider).visiteParId(id)!.etat, EtatVisite.envoyee);
        expect(serveur.appels, isEmpty);
        final lignes = await tester.runAsync(() => base.envoisDe('u'));
        expect(lignes, isEmpty);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'valider une commande : rangée en VALIDEE avec son idCommandeApk, envoyée sans doublon',
      (tester) async {
        final c = await ouvrir(
          tester,
          (context, ref) => validerCommande(context, ref),
        );
        c.read(commandeEnCoursProvider.notifier).demarrer(magasinId: _client);
        c.read(commandeEnCoursProvider.notifier).ajouter(_art);
        await tester.tap(find.text('go'));
        await tester.pump();
        await attendreReel(tester, () => serveur.commandes.isNotEmpty);
        await tester.pump();

        expect(serveur.commandes, hasLength(1));
        final envoi = serveur.commandes.values.single;
        expect(envoi['statut'], 'VALIDEE');
        final corps = envoi['corps']! as Map;
        expect(corps['clientId'], _client);
        expect(
          RegExp(
            r'^[A-Za-z0-9]{10}$',
          ).hasMatch(corps['idCommandeApk']! as String),
          isTrue,
        );
        expect(c.read(commandeEnCoursProvider), isNull);
        await attendreReel(tester, () => !c.read(envoiProvider).enCours);
        await tester.pump();
        expect(c.read(envoiProvider).vide, isTrue);
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      'démonstration : la commande validée reste locale, rien n\'est rangé',
      (tester) async {
        final c = await ouvrir(
          tester,
          (context, ref) => validerCommande(context, ref),
          connecte: false,
        );
        c.read(commandeEnCoursProvider.notifier).demarrer(magasinId: 'm1');
        c.read(commandeEnCoursProvider.notifier).ajouter('a1');
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(c.read(commandeEnCoursProvider), isNull);
        expect(serveur.appels, isEmpty);
        final lignes = await tester.runAsync(() => base.envoisDe('u'));
        expect(lignes, isEmpty);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}
