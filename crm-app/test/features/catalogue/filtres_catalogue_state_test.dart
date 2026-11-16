import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/catalogue/state/filtres_catalogue_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Les filtres reproduisent `prodsFiltres` (maquette l.1237-1240) ; les nombres attendus viennent de la liste
/// `PRODUITS` + `PRODUITS_KIT` + `PRODUITS_PEM` (14 + 2 + 8 = 24 références).
void main() {
  List<String> ids(ProviderContainer c) =>
      c.read(produitsFiltresProvider).map((p) => p.id).toList();

  test(
    'sans filtre : les 24 références, dans l’ordre catalogue, kits, PEM',
    () {
      final c = conteneurPour(Role.promoteur);
      final liste = ids(c);
      expect(liste.length, 24);
      expect(liste.first, 'a1');
      expect(liste[13], 'a14');
      expect(liste[14], 'kitKIT91265');
      expect(liste[16], 'pem20000');
      expect(liste.last, 'pem20021');
      expect(c.read(filtresCatalogueProvider).nombreActifs, 0);
    },
  );

  test(
    'recherche : nom, marque, EAN et code article, sans tenir compte de la casse',
    () {
      final c = conteneurPour(Role.promoteur);
      final f = c.read(filtresCatalogueProvider.notifier);
      f.chercher('milano');
      expect(ids(c), ['a9', 'a10', 'a11', 'a12', 'a13', 'a14']);
      f.chercher('376123450040');
      expect(ids(c), ['a13']);
      f.chercher('900016');
      expect(ids(c), ['a1']);
      f.chercher('KIT91267');
      expect(ids(c), ['kitKIT91267']);
      f.chercher('titanium');
      expect(ids(c), ['pem20003', 'pem20015']);
      f.chercher('introuvable');
      expect(ids(c), isEmpty);
      f.chercher('');
      expect(ids(c).length, 24);
      // La recherche n'est pas un filtre : elle ne compte pas sur le bouton.
      f.chercher('milano');
      expect(c.read(filtresCatalogueProvider).nombreActifs, 0);
    },
  );

  test('marque : seuls les produits de la marque, kits et PEM exclus', () {
    final c = conteneurPour(Role.cs);
    final f = c.read(filtresCatalogueProvider.notifier);
    f.choisirMarque('Franck Provost');
    expect(ids(c), ['a1', 'a2', 'a3', 'a4']);
    f.choisirMarque('Jean Louis David');
    expect(ids(c), ['a5', 'a6', 'a7', 'a8']);
    f.choisirMarque('MB Milano');
    expect(ids(c).length, 6);
    expect(c.read(filtresCatalogueProvider).nombreActifs, 1);
    f.choisirMarque(null);
    expect(ids(c).length, 24);
  });

  test('stock : les kits et les produits PEM (sans stock) disparaissent', () {
    final c = conteneurPour(Role.dir);
    final f = c.read(filtresCatalogueProvider.notifier);
    f.choisirStock(NiveauStock.stockBas);
    expect(ids(c), ['a2', 'a4', 'a7', 'a12']);
    f.choisirStock(NiveauStock.rupture);
    expect(ids(c), ['a13']);
    f.choisirStock(NiveauStock.enStock);
    expect(ids(c).length, 9);
    f.choisirStock(null);
    expect(ids(c).length, 24);
  });

  test('interrupteurs : kits 3, PEM 8, promotion et mis en avant 0', () {
    final c = conteneurPour(Role.promoteur);
    final f = c.read(filtresCatalogueProvider.notifier);
    f.basculerKit();
    expect(ids(c), ['a5', 'kitKIT91265', 'kitKIT91267']);
    f.basculerKit();
    f.basculerPem();
    expect(ids(c).length, 8);
    f.basculerPem();
    f.basculerPromo();
    expect(ids(c), isEmpty);
    f.basculerPromo();
    f.basculerAvant();
    expect(ids(c), isEmpty);
    f.basculerAvant();
    expect(ids(c).length, 24);
  });

  test('les filtres se cumulent et le compteur les compte un par un', () {
    final c = conteneurPour(Role.promoteur);
    final f = c.read(filtresCatalogueProvider.notifier);
    f.choisirMarque('MB Milano');
    f.choisirStock(NiveauStock.stockBas);
    expect(ids(c), ['a12']);
    expect(c.read(filtresCatalogueProvider).nombreActifs, 2);
    f.basculerKit();
    expect(ids(c), isEmpty);
    expect(c.read(filtresCatalogueProvider).nombreActifs, 3);
    f.basculerPem();
    f.basculerPromo();
    f.basculerAvant();
    expect(c.read(filtresCatalogueProvider).nombreActifs, 6);
  });

  test(
    'Réinitialiser remet stock et interrupteurs à zéro mais garde la marque et la recherche (p-reset)',
    () {
      final c = conteneurPour(Role.promoteur);
      final f = c.read(filtresCatalogueProvider.notifier);
      f.chercher('rouge');
      f.choisirMarque('MB Milano');
      f.choisirStock(NiveauStock.enStock);
      f.basculerPromo();
      f.basculerAvant();
      f.basculerKit();
      f.basculerPem();
      f.reinitialiser();
      final e = c.read(filtresCatalogueProvider);
      expect(e.stock, isNull);
      expect(e.promo || e.avant || e.kit || e.pem, isFalse);
      expect(e.marque, 'MB Milano');
      expect(e.q, 'rouge');
      expect(e.nombreActifs, 1);
      expect(ids(c), ['a9', 'a10', 'a14']);
    },
  );

  test('un changement de profil remet la recherche et les filtres à zéro', () {
    final c = conteneurPour(Role.promoteur);
    final f = c.read(filtresCatalogueProvider.notifier);
    f.chercher('milano');
    f.choisirMarque('MB Milano');
    f.basculerKit();
    c.read(roleProvider.notifier).choisir(Role.dir);
    final e = c.read(filtresCatalogueProvider);
    expect(e.q, '');
    expect(e.marque, isNull);
    expect(e.kit, isFalse);
    expect(ids(c).length, 24);
  });

  test('la liste du socle est celle de la maquette : 24 références', () {
    expect(tousProduits().length, 24);
    expect(marquesCatalogue, [
      'Franck Provost',
      'Jean Louis David',
      'MB Milano',
    ]);
  });
}
