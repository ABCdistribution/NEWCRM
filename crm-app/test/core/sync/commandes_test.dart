import 'dart:io';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/commandes_serveur.dart';
import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

Map<String, dynamic> _cmd(
  String numero, {
  String statut = 'EN_PREPARATION',
  bool annulee = false,
  bool mobile = false,
  String? expedition,
  String? livraison,
  String? transporteur,
}) => {
  'id': 'id-$numero',
  'numero': numero,
  'dateCommande': '2026-11-03T09:12:00.000Z',
  'statutLivraison': statut,
  'dateExpedition': expedition,
  'dateLivraison': livraison,
  'transporteur': transporteur,
  'noSuivi': transporteur == null ? null : 'GEO1',
  'annulee': annulee,
  'viaMobile': mobile,
  'nbLignes': 9,
  'total': 1540.0,
  'client': {'id': 'c1', 'codeAs400': 'K1', 'enseigne': 'CARREFOUR'},
};

class _FauxApi implements ApiLecture {
  _FauxApi(this.lignes);
  List<Map<String, dynamic>> lignes;
  Object? erreur;
  final List<(String, Map<String, String>)> appels = [];

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    appels.add((chemin, query ?? {}));
    if (erreur != null) throw erreur!;
    final page = int.parse(query!['page']!);
    final limit = int.parse(query['limit']!);
    return {
      'data': chemin == '/commandes'
          ? lignes.skip((page - 1) * limit).take(limit).toList()
          : const [],
      'total': chemin == '/commandes' ? lignes.length : 0,
    };
  }
}

void main() {
  group('commandeDepuisJson', () {
    test(
      'commande en préparation : pas livrée, origine EDI, montant formaté',
      () {
        final c = commandeDepuisJson(_cmd('CDE-1'))!;
        expect(c.id, 'CDE-1');
        expect(c.magasinId, 'c1');
        expect(c.statut, StatutLivraison.pasLivree);
        expect(c.ht, '1540,00 €');
        expect(c.lignes, 9);
        expect(c.src, 'EDI');
        expect(c.colis, 0);
        expect(c.evenements.single.libelle, 'Commande reçue');
      },
    );

    test('commande mobile expédiée puis livrée : suivi et transporteur', () {
      final c = commandeDepuisJson(
        _cmd(
          'CDE-2',
          statut: 'LIVREE',
          mobile: true,
          expedition: '2026-11-04T10:00:00.000Z',
          livraison: '2026-11-06T10:00:00.000Z',
          transporteur: 'Geodis',
        ),
      )!;
      expect(c.statut, StatutLivraison.livree);
      expect(c.src, 'Appli');
      expect(c.suivi, 'GEO1');
      expect(c.transporteur, 'Geodis');
      expect(c.evenements.map((e) => e.libelle), [
        'Commande reçue',
        'Expédiée',
        'Livrée',
      ]);
      expect(c.eta, startsWith('livrée le'));
    });

    test('annulée ou sans numéro : ignorée', () {
      expect(commandeDepuisJson(_cmd('CDE-3', annulee: true)), isNull);
      expect(commandeDepuisJson({..._cmd('x'), 'numero': ''}), isNull);
    });
  });

  group('synchro des commandes', () {
    late Directory dossier;
    late AppDatabase base;
    late _FauxApi api;

    setUp(() async {
      dossier = Directory.systemTemp.createTempSync('crm_cmd_test_');
      base = await ouvrirBaseChiffree(
        fichier: File('${dossier.path}/crm.db'),
        cleHex: _cle,
      );
      api = _FauxApi([_cmd('CDE-1'), _cmd('CDE-2', annulee: true)]);
    });

    tearDown(() async {
      definirCommandesServeur(null);
      await base.close();
      dossier.deleteSync(recursive: true);
    });

    ProviderContainer conteneur() {
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

    Future<void> attendreFin(ProviderContainer c) async {
      c.listen(commandesProvider, (_, _) {});
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        if (c.read(commandesProvider).phase != PhaseSynchro.chargement) return;
      }
    }

    test(
      'téléchargées dans la base chiffrée, annulées écartées, relues hors connexion',
      () async {
        final c = conteneur();
        await attendreFin(c);
        expect(c.read(commandesProvider).phase, PhaseSynchro.ok);
        expect(commandesServeur()!.map((x) => x.id), ['CDE-1']);
        expect(api.appels.first.$1, '/commandes');
        expect(api.appels.first.$2['mes'], '1');
        expect(
          api.appels.first.$2['dateDepuis'],
          matches(r'^\d{4}-\d{2}-\d{2}$'),
        );
        expect(await base.enregistrements('commandes'), hasLength(2));

        // Nouveau lancement sans réseau : la copie locale sert.
        definirCommandesServeur(null);
        api.erreur = const ErreurApi(TypeErreurApi.reseau);
        final c2 = conteneur();
        await attendreFin(c2);
        expect(c2.read(commandesProvider).phase, PhaseSynchro.horsLigne);
        expect(c2.read(commandesProvider).nb, 2);
        expect(c2.read(commandesProvider).bloquant, isFalse);
        expect(commandesServeur()!.map((x) => x.id), ['CDE-1']);
      },
    );

    test(
      'gros périmètre : plafonné à 1 000 commandes, 10 pages seulement',
      () async {
        api.lignes = [for (var i = 0; i < 5000; i++) _cmd('CDE-$i')];
        final c = conteneur();
        await attendreFin(c);
        expect(commandesServeur(), hasLength(1000));
        expect(api.appels, hasLength(10));
        expect(c.read(commandesProvider).total, 1000);
      },
    );

    test(
      'rôle sans accès (403) : jeu vide, l\'application n\'est pas bloquée',
      () async {
        api.erreur = const ErreurApi(TypeErreurApi.refuse);
        final c = conteneur();
        await attendreFin(c);
        final etat = c.read(commandesProvider);
        expect(etat.phase, PhaseSynchro.ok);
        expect(etat.bloquant, isFalse);
      },
    );
  });
}
