import '../db/app_database.dart';
import '../models/models.dart';

/// Produit de l'app à partir d'un article téléchargé du CRM.
///
/// Stock : rupture à 0 ou moins, « stock bas » sous le colisage, sinon « en stock ». Un kit est un article dont le
/// code ou le libellé commence par « KIT ».
Produit produitDepuisArticle(ArticleLocal a) {
  final marque = a.marque ?? '';
  final stock = a.stock <= 0
      ? NiveauStock.rupture
      : (a.pcb != null && a.stock < a.pcb!
            ? NiveauStock.stockBas
            : NiveauStock.enStock);
  final promo = a.promoLibelle ?? (a.enPromo ? 'Promo' : null);
  return Produit(
    id: a.id,
    nom: a.libelle,
    marque: marque,
    cat: marque.isEmpty ? null : marque,
    famille: a.famille ?? a.gamme ?? '',
    code: a.codeAs400,
    ean: a.gencode ?? '',
    prix: a.prix,
    stock: stock,
    promo: promo,
    avant: a.misEnAvant,
    pcb: a.pcb,
    qte: a.stock,
    kit: _commenceParKit(a.codeAs400) || _commenceParKit(a.libelle),
    actif: a.actif,
  );
}

bool _commenceParKit(String s) => s.trimLeft().toUpperCase().startsWith('KIT');
