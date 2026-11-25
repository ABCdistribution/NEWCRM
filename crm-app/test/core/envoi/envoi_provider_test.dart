import 'dart:io';

import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
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
import 'package:crm_app/features/visites/state/actions_visite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/faux_serveur_envoi.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const _client = '11111111-1111-4111-8111-111111111111';
const _art = '33333333-3333-4333-8333-333333333331';
const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3];

class _StockageMemoire implements StockageSecret {
  final Map<String, String> valeurs = {};

  @override
  Future<String?> lire(String nom) async => valeurs[nom];

  @override
  Future<void> ecrire(String nom, String valeur) async => valeurs[nom] = valeur;
}

Map<String, Object?> _commande(String idApk) => {
  'idCommandeApk': idApk,
  'clientId': _client,
  'dateCommande': '2026-11-23T09:30:00.000Z',
  'statut': 'VALIDEE',
  'lignes': [
    {'articleId': _art, 'quantite': 6},
  ],
};

Future<void> _attendre(bool Function() condition) async {
  for (var i = 0; i < 300; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition jamais atteinte.');
}

Future<void> _calme(ProviderContainer c) async {
  if (c.read(sessionProvider) == null) return;
  c.listen(jeuxDeDonneesProvider, (_, _) {});
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await _attendre(
    () => c
        .read(jeuxDeDonneesProvider)
        .every((j) => j.$2.phase != PhaseSynchro.chargement),
  );
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  late Directory dossier;
  late AppDatabase base;
  late FauxServeurEnvoi serveur;
  late _StockageMemoire stockage;

  setUp(() async {
    dossier = Directory.systemTemp.createTempSync('crm_envoi_prov_test_');
    base = await ouvrirBaseChiffree(
      fichier: File('${dossier.path}/crm.db'),
      cleHex: _cle,
    );
    serveur = FauxServeurEnvoi();
    stockage = _StockageMemoire();
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await base.close();
    dossier.deleteSync(recursive: true);
  });

  ProviderContainer conteneur({
    bool connecte = true,
    Duration delai = const Duration(milliseconds: 40),
  }) {
    final c = ProviderContainer(
      overrides: [
        baseLocaleProvider.overrideWithValue(base),
        apiClientProvider.overrideWithValue(serveur),
        apiEcritureProvider.overrideWithValue(serveur),
        apiFichiersProvider.overrideWithValue(serveur),
        stockageSessionProvider.overrideWithValue(StockageSession(stockage)),
        delaiReessaiEnvoiProvider.overrideWithValue((_) => delai),
        roleProvider.overrideWith(() => RoleNotifier(Role.promoteur)),
        sessionProvider.overrideWith(
          () => SessionNotifier(
            connecte
                ? const Utilisateur(
                    id: 'u',
                    identifiant: 'x',
                    nomAffiche: 'Jean DUPONT',
                    email: null,
                    roleApi: 'COMMERCIAL',
                  )
                : null,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    // Les téléchargements de départ (lancés par la lecture du store) doivent être finis avant d'arrêter le conteneur.
    addTearDown(() => _calme(c));
    return c;
  }

  /// Attend la fin des téléchargements de départ : ils reconstruisent le store des visites.
  Future<void> attendreSynchro(ProviderContainer c) async {
    c.listen(jeuxDeDonneesProvider, (_, _) {});
    c.read(crmProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await _attendre(
      () => c
          .read(jeuxDeDonneesProvider)
          .every((j) => j.$2.phase != PhaseSynchro.chargement),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Visite terminee(ProviderContainer c) {
    final store = c.read(crmProvider.notifier);
    final id = store.demarrerVisite(_client);
    ActionsVisite(store, id).terminer();
    return c.read(crmProvider).visiteParId(id)!;
  }

  group('démonstration', () {
    test('sans session : rien n\'est rangé ni envoyé', () async {
      final c = conteneur(connecte: false);
      final envoi = c.read(envoiProvider.notifier);
      expect(envoi.actif, isFalse);
      expect(await envoi.enfilerVisite(terminee(c)), isFalse);
      expect(await envoi.enfilerCommande(_commande('CMD00001')), isFalse);
      await envoi.declencher();
      expect(c.read(envoiProvider).vide, isTrue);
      expect(serveur.appels, isEmpty);
      expect(await base.envoisDe('u'), isEmpty);
    });
  });

  group('session réelle', () {
    test(
      'une visite terminée part, passe en « Envoyée » et la file se vide',
      () async {
        final c = conteneur();
        await attendreSynchro(c);
        final envoi = c.read(envoiProvider.notifier);
        final visite = terminee(c);
        expect(visite.etat, EtatVisite.terminee);
        // Une autre visite en cours de saisie : le store n'est pas relu pendant l'envoi.
        c.read(crmProvider.notifier).demarrerVisite('autre-magasin');
        expect(await envoi.enfilerVisite(visite), isTrue);
        await _attendre(
          () =>
              serveur.visites.isNotEmpty &&
              c.read(envoiProvider).vide &&
              !c.read(envoiProvider).enCours,
        );
        expect(
          c.read(crmProvider).visiteParId(visite.id)?.etat,
          EtatVisite.envoyee,
        );
        final corps = serveur.visites.values.single['corps']! as Map;
        expect(corps['clientId'], _client);
        expect(corps['typeVisite'], 'COMMERCIALE');
      },
    );

    test('une commande validée part en un appel', () async {
      final c = conteneur();
      final envoi = c.read(envoiProvider.notifier);
      expect(await envoi.enfilerCommande(_commande('CMD00001')), isTrue);
      await _attendre(
        () => c.read(envoiProvider).vide && !c.read(envoiProvider).enCours,
      );
      expect(serveur.commandes['CMD00001']!['statut'], 'VALIDEE');
      expect(serveur.appels, ['POST /commandes/apk']);
    });

    test('au démarrage, ce qui attendait dans la base part', () async {
      // Entrée rangée par une session précédente, application tuée avant l'envoi.
      await base.enfilerEnvoi(
        utilisateurId: 'u',
        type: TypeEnvoi.visite,
        cle: 'Vabc',
        payload:
            '{"idApk":"Vabc","clientId":"$_client","typeVisite":"COMMERCIALE"}',
        refLocale: 'v218093',
      );
      await base.enfilerEnvoi(
        utilisateurId: 'autre',
        type: TypeEnvoi.visite,
        cle: 'Vdef',
        payload: '{"idApk":"Vdef","clientId":"$_client"}',
      );
      final c = conteneur();
      c.listen(envoiProvider, (_, _) {});
      await _attendre(() => serveur.visites.containsKey('Vabc'));
      await _attendre(() => !c.read(envoiProvider).enCours);
      expect(serveur.visites.containsKey('Vdef'), isFalse);
      expect(c.read(envoiProvider).vide, isTrue);
    });

    test(
      'réseau coupé : la file retente seule, puis envoie sans doublon',
      () async {
        serveur.horsLigne = true;
        final c = conteneur();
        c.listen(envoiProvider, (_, _) {});
        final envoi = c.read(envoiProvider.notifier);
        await envoi.enfilerCommande(_commande('CMD00001'));
        await _attendre(
          () => serveur.appels.length >= 2,
        ); // au moins une reprise
        expect(c.read(envoiProvider).aEnvoyer, 1);
        expect(c.read(envoiProvider).erreurs, isEmpty);
        expect(serveur.commandes, isEmpty);

        serveur.horsLigne = false;
        await _attendre(
          () => c.read(envoiProvider).vide && !c.read(envoiProvider).enCours,
        );
        expect(serveur.commandes, hasLength(1));
      },
    );

    test('un seul envoi à la fois', () async {
      serveur.latence = const Duration(milliseconds: 20);
      final c = conteneur();
      c.listen(envoiProvider, (_, _) {});
      final envoi = c.read(envoiProvider.notifier);
      await Future.wait([
        envoi.enfilerCommande(_commande('CMD00001')),
        envoi.enfilerCommande(_commande('CMD00002')),
        envoi.enfilerCommande(_commande('CMD00003')),
      ]);
      envoi.declencher();
      await _attendre(
        () =>
            serveur.commandes.length == 3 &&
            c.read(envoiProvider).vide &&
            !c.read(envoiProvider).enCours,
      );
      expect(serveur.maxSimultanes, 1);
    });

    test(
      'refus de l\'API : compté en erreur avec le message, relancé à la demande',
      () async {
        final c = conteneur();
        c.listen(envoiProvider, (_, _) {});
        serveur.refus['POST /commandes/apk'] = erreurHttp(
          400,
          'Article introuvable',
        );
        final envoi = c.read(envoiProvider.notifier);
        await envoi.enfilerCommande(_commande('CMD00001'));
        await _attendre(
          () =>
              c.read(envoiProvider).enErreur == 1 &&
              !c.read(envoiProvider).enCours,
        );
        final etat = c.read(envoiProvider);
        expect(etat.aEnvoyer, 0);
        expect(etat.erreurs.single.type, TypeEnvoi.commande);
        expect(etat.erreurs.single.message, 'Article introuvable');
        // Pas de boucle : rien ne repart tout seul.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(serveur.nbAppels('POST /commandes/apk'), 1);

        serveur.refus.clear();
        await envoi.relancer();
        await _attendre(
          () => c.read(envoiProvider).vide && !c.read(envoiProvider).enCours,
        );
        expect(serveur.commandes, hasLength(1));
      },
    );

    test(
      'session expirée : retour à la connexion, la file est gardée pour la prochaine connexion',
      () async {
        final c = conteneur();
        c.listen(envoiProvider, (_, _) {});
        serveur.pannes.add(erreurHttp(401, 'Unauthorized'));
        final envoi = c.read(envoiProvider.notifier);
        await envoi.enfilerCommande(_commande('CMD00001'));
        await _attendre(() => c.read(sessionProvider) == null);
        expect((await base.envoisDe('u')).single.etat, EtatEnvoi.aEnvoyer);
        expect(serveur.commandes, isEmpty);
      },
    );

    test('une photo de visite est envoyée avec la visite', () async {
      final c = conteneur();
      c.listen(envoiProvider, (_, _) {});
      final visite = terminee(c);
      await base.ajouterPhotoVisite(visite.id, 'arrivee', _jpeg);
      await c.read(envoiProvider.notifier).enfilerVisite(visite);
      await _attendre(
        () =>
            serveur.photos.isNotEmpty &&
            c.read(envoiProvider).vide &&
            !c.read(envoiProvider).enCours,
      );
      expect(serveur.photos.values.single['etape'], 'arrivee');
    });
  });
}
