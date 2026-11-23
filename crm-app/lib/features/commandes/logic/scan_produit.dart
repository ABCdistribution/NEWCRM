/// Lecture d'un code-barres de produit : retrouver le produit, le classer (inconnu, disponible, en rupture).
library;

import '../../../core/models/models.dart';

/// Issue d'un scan de produit.
enum ResultatScan { inconnu, disponible, rupture }

/// Produit lu et classement de la lecture ; `produit` est nul quand le code est inconnu.
class LectureScan {
  const LectureScan(this.resultat, this.produit);

  final ResultatScan resultat;
  final Produit? produit;
}

/// Vrai si le produit est indisponible : niveau « Rupture » ou quantité disponible à zéro (ou moins).
bool produitEnRupture(Produit p) =>
    p.stock == NiveauStock.rupture || (p.qte != null && p.qte! <= 0);

/// Chiffres seuls, sans zéros de tête : un UPC-A (12 chiffres) et l'EAN-13 qui commence par 0 désignent le même article.
String _normaliser(String code) =>
    code.trim().replaceFirst(RegExp(r'^0+(?=\d)'), '');

/// Retrouve un produit par le code lu, comparé à son EAN (gencode). Nul si le code est vide ou inconnu.
Produit? produitParCodeLu(String? code, Iterable<Produit> produits) {
  final lu = _normaliser(code ?? '');
  if (lu.isEmpty) return null;
  for (final p in produits) {
    if (p.ean.isNotEmpty && _normaliser(p.ean) == lu) return p;
  }
  return null;
}

/// Classe la lecture d'un code : produit inconnu, disponible ou en rupture de stock.
LectureScan classerScan(String? code, Iterable<Produit> produits) {
  final p = produitParCodeLu(code, produits);
  if (p == null) return const LectureScan(ResultatScan.inconnu, null);
  return LectureScan(
    produitEnRupture(p) ? ResultatScan.rupture : ResultatScan.disponible,
    p,
  );
}

/// Vrai si `code` est le même code que `dernier`, lu il y a moins de `delai` : une étiquette gardée devant la caméra
/// n'est comptée qu'une fois.
bool scanEnDoublon({
  required String code,
  required String? dernier,
  required DateTime vuLe,
  required DateTime maintenant,
  Duration delai = const Duration(seconds: 3),
}) => code == dernier && maintenant.difference(vuLe) < delai;
