import 'dart:io';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/data/produits_serveur.dart';
import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/cle_base.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/sync_catalogue.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

Map<String, dynamic> _article(
  String id,
  String libelle, {
  String? marque = 'Franck Provost',
  int stock = 50,
  int? pcb = 6,
  double? prix = 3.46,
}) => {
  'id': id,
  'codeAs400': 'C$id',
  'libelle': libelle,
  'gencode': '3666085207382',
  'typeArticle': 'PF',
  'statut': 'ACTIF',
  'pcb': pcb,
  'stock': stock,
  'actif': true,
  'marque': marque == null ? null : {'nom': marque},
  'gamme': {'nom': 'Soins'},
  'famille': {'nom': 'Shampooings'},
  'prixIndicatif': prix,
  'enPromo': false,
  'promoLibelle': null,
  'misEnAvant': false,
};

/// Faux serveur : `GET /articles` paginé.
class _FauxApi implements ApiLecture {
  _FauxApi(this.articles);
  List<Map<String, dynamic>> articles;
  Object? erreur;
  final List<Map<String, String>> requetes = [];

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    requetes.add(query ?? {});
    if (erreur != null) throw erreur!;
    expect(chemin, '/articles');
    final page = int.parse(query!['page']!);
    final limit = int.parse(query['limit']!);
    final debut = (page - 1) * limit;
    final data = articles.skip(debut).take(limit).toList();
    return {
      'data': data,
      'total': articles.length,
      'page': page,
      'limit': limit,
    };
  }
}

class _StockageMemoire implements StockageSecret {
  final Map<String, String> valeurs = {};
  @override
  Future<String?> lire(String nom) async => valeurs[nom];
  @override
  Future<void> ecrire(String nom, String valeur) async => valeurs[nom] = valeur;
}

void main() {
  late Directory dossier;
  late File fichier;
  late AppDatabase base;

  setUp(() async {
    dossier = Directory.systemTemp.createTempSync('crm_catalogue_test_');
    fichier = File('${dossier.path}/crm.db');
    base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
  });

  tearDown(() async {
    definirCatalogueServeur(null);
    await base.close();
    dossier.deleteSync(recursive: true);
  });

  group('téléchargement', () {
    test(
      'toutes les pages sont lues (100 par page) et rangées en base',
      () async {
        final api = _FauxApi([
          for (var i = 0; i < 250; i++) _article('id$i', 'Article $i'),
        ]);
        final n = await SyncCatalogue(api, base).telecharger();
        expect(n, 250);
        expect(api.requetes.map((q) => q['page']), ['1', '2', '3']);
        expect(api.requetes.every((q) => q['limit'] == '100'), isTrue);
        expect(await base.tousLesArticles(), hasLength(250));
        expect(await base.meta(AppDatabase.cleCatalogueMajLe), isNotNull);
      },
    );

    test(
      'un nouveau téléchargement remplace tout : l\'article supprimé disparaît',
      () async {
        final api = _FauxApi([_article('a', 'A'), _article('b', 'B')]);
        await SyncCatalogue(api, base).telecharger();
        api.articles = [_article('b', 'B modifié')];
        await SyncCatalogue(api, base).telecharger();
        final lignes = await base.tousLesArticles();
        expect(lignes.map((l) => l.id), ['b']);
        expect(lignes.single.libelle, 'B modifié');
      },
    );

    test('la progression est signalée page après page', () async {
      final api = _FauxApi([
        for (var i = 0; i < 250; i++) _article('id$i', 'Article $i'),
      ]);
      final vues = <(int, int)>[];
      await SyncCatalogue(
        api,
        base,
      ).telecharger(progression: (recus, total) => vues.add((recus, total)));
      expect(vues, [(100, 250), (200, 250), (250, 250)]);
    });

    test('échec réseau : la base locale est inchangée', () async {
      final api = _FauxApi([_article('a', 'A')]);
      await SyncCatalogue(api, base).telecharger();
      api.erreur = const ErreurApi(TypeErreurApi.reseau);
      await expectLater(
        SyncCatalogue(api, base).telecharger(),
        throwsA(isA<ErreurApi>()),
      );
      expect(await base.tousLesArticles(), hasLength(1));
    });

    test('réponse inattendue : erreur, rien d\'enregistré', () async {
      final api = _FauxApi([]);
      api.erreur = null;
      final bizarre = _ApiBizarre();
      await expectLater(
        SyncCatalogue(bizarre, base).telecharger(),
        throwsA(isA<ErreurApi>()),
      );
      expect(await base.tousLesArticles(), isEmpty);
    });

    test(
      'articles sans identifiant ou libellé ignorés, doublons dédoublonnés',
      () async {
        final api = _FauxApi([
          _article('a', 'A'),
          _article('a', 'A encore'),
          {'libelle': 'sans id'},
          {'id': 'x'},
        ]);
        expect(await SyncCatalogue(api, base).telecharger(), 1);
      },
    );
  });

  group('produit de l\'app', () {
    test('stock, kit, promo, marque', () async {
      final api = _FauxApi([
        _article('a', 'Shampoing', stock: 0),
        _article('b', 'Masque', stock: 3, pcb: 6),
        _article('c', 'KIT couleur', stock: 40),
        _article('d', 'Sans marque', marque: null, prix: null),
      ]);
      await SyncCatalogue(api, base).telecharger();
      final produits = {
        for (final a in await base.tousLesArticles())
          a.id: produitDepuisArticle(a),
      };
      expect(produits['a']!.stock, NiveauStock.rupture);
      expect(produits['b']!.stock, NiveauStock.stockBas);
      expect(produits['c']!.stock, NiveauStock.enStock);
      expect(produits['c']!.kit, isTrue);
      expect(produits['a']!.kit, isFalse);
      expect(produits['a']!.cat, 'Franck Provost');
      expect(produits['d']!.cat, isNull);
      expect(produits['d']!.prix, isNull);
      expect(produits['a']!.ean, '3666085207382');
      expect(produits['a']!.code, 'Ca');
    });
  });

  group('migration', () {
    test(
      'une base de la version 1 (sans articles) est mise à niveau sans perte',
      () async {
        await base.close();
        fichier.deleteSync();
        // Base « version 1 » telle qu'elle existe sur les téléphones : table de métadonnées seule.
        final brut = sqlite.sqlite3.open(fichier.path);
        brut.execute("PRAGMA key = \"x'$_cle'\";");
        brut.execute(
          'CREATE TABLE meta_base (cle TEXT NOT NULL PRIMARY KEY, valeur TEXT NOT NULL, '
          "mis_a_jour_le INTEGER NOT NULL DEFAULT (strftime('%s','now')));",
        );
        brut.execute(
          "INSERT INTO meta_base (cle, valeur) VALUES ('creee_le', '2026-11-13T08:00:00Z');",
        );
        brut.execute('PRAGMA user_version = 1;');
        brut.close();

        base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
        expect(await base.meta(AppDatabase.cleCreeeLe), '2026-11-13T08:00:00Z');
        expect(await base.tousLesArticles(), isEmpty);
        await SyncCatalogue(_FauxApi([_article('a', 'A')]), base).telecharger();
        expect(await base.tousLesArticles(), hasLength(1));
      },
    );
  });

  group('catalogue de l\'app', () {
    Future<ProviderContainer> demarrer(_FauxApi api) async {
      final stockage = _StockageMemoire();
      final c = ProviderContainer(
        overrides: [
          baseLocaleProvider.overrideWithValue(base),
          apiClientProvider.overrideWithValue(api),
          stockageSessionProvider.overrideWithValue(StockageSession(stockage)),
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
      c.listen(catalogueProvider, (_, _) {});
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final p = c.read(catalogueProvider).phase;
        if (p != PhaseSynchro.chargement) break;
      }
      return c;
    }

    test('connecté : le catalogue réel remplace la démo', () async {
      final api = _FauxApi([
        _article('a', 'Vrai produit'),
        _article('b', 'Autre'),
      ]);
      final c = await demarrer(api);
      final etat = c.read(catalogueProvider);
      expect(etat.phase, PhaseSynchro.ok);
      expect(etat.nb, 2);
      expect(etat.majLe, isNotNull);
      expect(tousProduits().map((p) => p.nom).toSet(), {
        'Vrai produit',
        'Autre',
      });
      expect(produitParId('a')?.nom, 'Vrai produit');
      expect(marquesCatalogueActuelles(), ['Franck Provost']);
    });

    test('hors connexion : la copie locale est gardée et utilisée', () async {
      await SyncCatalogue(
        _FauxApi([_article('a', 'Copie locale')]),
        base,
      ).telecharger();
      final api = _FauxApi([])..erreur = const ErreurApi(TypeErreurApi.reseau);
      final c = await demarrer(api);
      expect(c.read(catalogueProvider).phase, PhaseSynchro.horsLigne);
      expect(c.read(catalogueProvider).nb, 1);
      expect(tousProduits().single.nom, 'Copie locale');
    });

    test('session expirée : retour à la connexion', () async {
      final api = _FauxApi([])
        ..erreur = const ErreurApi(TypeErreurApi.sessionExpiree);
      final c = await demarrer(api);
      expect(c.read(sessionProvider), isNull);
    });

    test('sans utilisateur (démo) : les produits de la maquette', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(catalogueProvider).phase, PhaseSynchro.demo);
      expect(tousProduits().length, greaterThan(20));
      expect(marquesCatalogueActuelles(), marquesCatalogue);
    });
  });
}

class _ApiBizarre implements ApiLecture {
  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async =>
      'pas un objet';
}
