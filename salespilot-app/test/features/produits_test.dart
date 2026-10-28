import 'package:flutter_test/flutter_test.dart';
import 'package:salespilot/features/produits/produit_repository.dart';

void main() {
  Produit p({int stock = 100, int? pcb}) => Produit(id: '1', code: 'A1', libelle: 'Sérum', stock: stock, pcb: pcb);

  test('niveau de stock : rupture, bas, en stock', () {
    expect(p(stock: 0).niveauStock, NiveauStock.rupture);
    expect(p(stock: 5).niveauStock, NiveauStock.bas);
    expect(p(stock: 20).niveauStock, NiveauStock.enStock);
  });

  test('le seuil monte à deux colis quand le colisage est grand', () {
    expect(p(stock: 30, pcb: 24).niveauStock, NiveauStock.bas); // seuil 48
    expect(p(stock: 48, pcb: 24).niveauStock, NiveauStock.enStock);
  });

  test('lecture d\'un article de l\'API', () {
    final a = Produit.fromJson({
      'id': 'x',
      'codeAs400': '12345',
      'libelle': ' Crème nuit 50 ml ',
      'gencode': '3760001245018',
      'pcb': 6,
      'stock': 42,
      'marque': {'nom': 'ABC'},
      'famille': {'nom': 'Soin visage'},
      'prixIndicatif': 22.4,
      'enPromo': true,
      'promoLibelle': 'Promo -5 %',
      'misEnAvant': false,
    });
    expect(a.libelle, 'Crème nuit 50 ml');
    expect(a.marque, 'ABC');
    expect(a.famille, 'Soin visage');
    expect(a.prix, 22.4);
    expect(a.enPromo, isTrue);
  });
}
