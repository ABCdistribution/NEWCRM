import 'dart:io';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/data/magasins_serveur.dart';
import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/cle_base.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/sync_clients.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

Map<String, dynamic> _client(
  String id,
  String enseigne, {
  String? ville = 'VERSAILLES',
  String? classe = 'B',
  bool actif = true,
}) => {
  'id': id,
  'codeAs400': 'K$id',
  'enseigne': enseigne,
  'raisonSociale': '$enseigne SAS',
  'adresse1': '104 AVENUE DES CHAMPS',
  'codePostal': '78000',
  'ville': ville,
  'tel1': '0102030405',
  'contact1': 'Mme Girard',
  'actif': actif,
  'niveauClass': classe,
};

class _FauxApi implements ApiLecture {
  _FauxApi(this.clients);
  List<Map<String, dynamic>> clients;
  Object? erreur;
  final List<(String, Map<String, String>)> appels = [];

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    appels.add((chemin, query ?? {}));
    if (erreur != null) throw erreur!;
    final page = int.parse(query!['page']!);
    final limit = int.parse(query['limit']!);
    return {
      'data': clients.skip((page - 1) * limit).take(limit).toList(),
      'total': clients.length,
    };
  }
}

void main() {
  late Directory dossier;
  late File fichier;
  late AppDatabase base;

  setUp(() async {
    dossier = Directory.systemTemp.createTempSync('crm_clients_test_');
    fichier = File('${dossier.path}/crm.db');
    base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
  });

  tearDown(() async {
    definirClientsServeur(null);
    await base.close();
    dossier.deleteSync(recursive: true);
  });

  test(
    'téléchargement du périmètre (mes=1), toutes les pages, rangé en base',
    () async {
      final api = _FauxApi([
        for (var i = 0; i < 230; i++) _client('c$i', 'Enseigne $i'),
      ]);
      final n = await SyncClients(api, base).telecharger();
      expect(n, 230);
      expect(
        api.appels.every((a) => a.$1 == '/clients' && a.$2['mes'] == '1'),
        isTrue,
      );
      expect(api.appels.map((a) => a.$2['page']), ['1', '2', '3']);
      expect(await base.tousLesClients(), hasLength(230));
      expect(await base.meta(AppDatabase.cleClientsMajLe), isNotNull);
    },
  );

  test(
    'clients inactifs : demandés actifs seulement et jamais rangés',
    () async {
      final api = _FauxApi([
        _client('a', 'A'),
        _client('b', 'B', actif: false),
      ]);
      expect(await SyncClients(api, base).telecharger(), 1);
      expect(api.appels.first.$2['actif'], 'true');
      expect((await base.tousLesClients()).map((c) => c.id), ['a']);
    },
  );

  test(
    'un nouveau téléchargement remplace tout ; un échec ne touche pas la copie locale',
    () async {
      final api = _FauxApi([_client('a', 'A'), _client('b', 'B')]);
      await SyncClients(api, base).telecharger();
      api.clients = [_client('b', 'B')];
      await SyncClients(api, base).telecharger();
      expect((await base.tousLesClients()).map((c) => c.id), ['b']);
      api.erreur = const ErreurApi(TypeErreurApi.reseau);
      await expectLater(
        SyncClients(api, base).telecharger(),
        throwsA(isA<ErreurApi>()),
      );
      expect(await base.tousLesClients(), hasLength(1));
    },
  );

  test(
    'client sans identifiant ou sans enseigne ignoré ; classe hors A à G ignorée',
    () async {
      final api = _FauxApi([
        _client('a', 'A', classe: 'Z'),
        {'enseigne': 'sans id'},
        {'id': 'x'},
      ]);
      expect(await SyncClients(api, base).telecharger(), 1);
      expect((await base.tousLesClients()).single.niveauClass, isNull);
    },
  );

  group('magasin de l\'app', () {
    test(
      'nom, adresse, statut et classe depuis le client ; rien d\'inventé',
      () async {
        // Rangés directement : le téléchargement, lui, écarte les clients inactifs.
        await base.remplacerClients([
          clientDepuisJson(_client('a', 'CARREFOUR MARKET'))!,
          clientDepuisJson(
            _client('b', 'U EXPRESS', classe: null, actif: false),
          )!,
        ]);
        final m = {
          for (final c in await base.tousLesClients())
            c.id: magasinDepuisClient(c),
        };
        final a = m['a']!;
        expect(a.nom, 'Carrefour Market – Versailles');
        expect(a.enseigne, 'Carrefour Market');
        expect(a.adresse, '104 AVENUE DES CHAMPS, 78000 Versailles');
        expect(a.statut, 'Client actif');
        expect(a.classe, 'B');
        expect(a.contact, 'Mme Girard');
        expect(a.reel, isTrue);
        expect(a.ca, '—');
        expect(a.cde, '—');
        expect(a.visites, 0);
        final b = m['b']!;
        expect(b.actif, isFalse);
        expect(b.statut, 'Client inactif');
        expect(b.classe, '—');
      },
    );
  });

  group('migration', () {
    test(
      'une base de la version 2 (catalogue, sans clients) est mise à niveau sans perte',
      () async {
        await base.close();
        fichier.deleteSync();
        final brut = sqlite.sqlite3.open(fichier.path);
        brut.execute("PRAGMA key = \"x'$_cle'\";");
        brut.execute(
          'CREATE TABLE meta_base (cle TEXT NOT NULL PRIMARY KEY, valeur TEXT NOT NULL, '
          "mis_a_jour_le INTEGER NOT NULL DEFAULT (strftime('%s','now')));",
        );
        brut.execute(
          'CREATE TABLE articles_locaux (id TEXT NOT NULL PRIMARY KEY, code_as400 TEXT NOT NULL, libelle TEXT NOT NULL, '
          'gencode TEXT NULL, marque TEXT NULL, famille TEXT NULL, gamme TEXT NULL, type_article TEXT NULL, '
          'statut TEXT NULL, pcb INTEGER NULL, stock INTEGER NOT NULL DEFAULT 0, actif INTEGER NOT NULL DEFAULT 1, '
          'prix REAL NULL, en_promo INTEGER NOT NULL DEFAULT 0, promo_libelle TEXT NULL, mis_en_avant INTEGER NOT NULL DEFAULT 0);',
        );
        brut.execute(
          "INSERT INTO articles_locaux (id, code_as400, libelle) VALUES ('a1', 'C1', 'Déjà là');",
        );
        brut.execute('PRAGMA user_version = 2;');
        brut.close();

        base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
        expect((await base.tousLesArticles()).single.libelle, 'Déjà là');
        expect(await base.tousLesClients(), isEmpty);
        await SyncClients(_FauxApi([_client('a', 'A')]), base).telecharger();
        expect(await base.tousLesClients(), hasLength(1));
      },
    );
  });

  group('store de l\'application', () {
    Magasin reel(String id, String nom) => Magasin(
      id: id,
      nom: nom,
      statut: 'Client actif',
      classe: 'B',
      adresse: 'x',
      ca: '—',
      evo: '',
      cde: '—',
      cdeDate: '',
      visites: 0,
      objectif: 0,
      reel: true,
    );

    test(
      'démo : magasins de la maquette ; avec clients réels : eux seuls, sans étape ni visite de démo',
      () {
        final demo = ProviderContainer(
          overrides: [
            roleProvider.overrideWith(() => RoleNotifier(Role.promoteur)),
          ],
        );
        addTearDown(demo.dispose);
        final etatDemo = demo.read(crmProvider);
        expect(etatDemo.magasins, isNotEmpty);
        expect(etatDemo.magasins.every((m) => !m.reel), isTrue);
        expect(etatDemo.tournee, isNotEmpty);

        final c = ProviderContainer(
          overrides: [
            roleProvider.overrideWith(() => RoleNotifier(Role.promoteur)),
          ],
        );
        addTearDown(c.dispose);
        // Sans session, lire l'état des clients retire les clients réels (retour à la démo) : on le lit d'abord.
        c.read(clientsProvider);
        definirClientsServeur([
          reel('r1', 'Vrai client – Rouen'),
          reel('r2', 'Autre – Caen'),
        ]);
        final etat = c.read(crmProvider);
        expect(etat.magasins.map((m) => m.id), ['r1', 'r2']);
        expect(etat.tousMagasins.map((m) => m.id), ['r1', 'r2']);
        expect(
          etat.tournee,
          isEmpty,
        ); // la tournée de démo visait des clients de démo
        expect(etat.visites, isEmpty);
        expect(
          etat.etapes.where((e) => e.cible == CiblePlanning.client),
          isEmpty,
        );
      },
    );

    test(
      'clients téléchargés puis lus depuis la base : l\'état de l\'app se reconstruit',
      () async {
        await SyncClients(
          _FauxApi([_client('a', 'CARREFOUR'), _client('b', 'U EXPRESS')]),
          base,
        ).telecharger();
        final c = ProviderContainer(
          overrides: [
            baseLocaleProvider.overrideWithValue(base),
            apiClientProvider.overrideWithValue(
              _FauxApi([_client('a', 'CARREFOUR'), _client('b', 'U EXPRESS')]),
            ),
            stockageSessionProvider.overrideWithValue(
              StockageSession(_MemoireSecrete()),
            ),
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
            roleProvider.overrideWith(() => RoleNotifier(Role.promoteur)),
          ],
        );
        addTearDown(c.dispose);
        c.listen(clientsProvider, (_, _) {});
        c.listen(crmProvider, (_, _) {});
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (c.read(clientsProvider).phase == PhaseSynchro.ok) break;
        }
        expect(c.read(clientsProvider).nb, 2);
        expect(c.read(crmProvider).magasins.map((m) => m.nom), [
          'Carrefour – Versailles',
          'U Express – Versailles',
        ]);
      },
    );
  });
}

class _MemoireSecrete implements StockageSecret {
  final Map<String, String> v = {};
  @override
  Future<String?> lire(String nom) async => v[nom];
  @override
  Future<void> ecrire(String nom, String valeur) async => v[nom] = valeur;
}
