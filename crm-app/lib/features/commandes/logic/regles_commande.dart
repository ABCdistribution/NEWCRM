/// Règles de la prise de commande portées de la maquette : stock affiché, produits de remplacement, catalogue filtré.
library;

import 'package:flutter/painting.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';

/// Ligne de stock d'un produit : texte et couleur (`stockInfo`).
class InfoStock {
  const InfoStock(this.texte, this.couleur);
  final String texte;
  final Color couleur;
}

/// Orange foncé du « Stock bas » (`#B45309`).
const Color couleurStockBas = Color(0xFFB45309);

InfoStock infoStock(Produit p) => switch (p.stock) {
  NiveauStock.rupture => InfoStock(
    'Rupture · disponible le ${p.reappro}',
    AppColors.alert,
  ),
  NiveauStock.stockBas => InfoStock(
    'Stock bas · ${p.qte} disponibles',
    couleurStockBas,
  ),
  _ => InfoStock('En stock · ${p.qte} disponibles', AppColors.ok),
};

/// Produits de remplacement : même marque, disponibles ; la même famille d'abord, puis le prix le plus proche.
/// Trois au plus (`remplacements`).
List<Produit> produitsDeRemplacement(Produit p) {
  final candidats = produitsCatalogue.where(
    (x) => x.id != p.id && x.cat == p.cat && x.stock != NiveauStock.rupture,
  );
  final tries = triStable<Produit>(candidats, (a, b) {
    final famille = (b.famille == p.famille ? 1 : 0).compareTo(
      a.famille == p.famille ? 1 : 0,
    );
    if (famille != 0) return famille;
    return ((a.prix ?? 0) - (p.prix ?? 0)).abs().compareTo(
      ((b.prix ?? 0) - (p.prix ?? 0)).abs(),
    );
  });
  return tries.take(3).toList();
}

/// Produits proposés à la commande selon la recherche, la marque et le masquage des ruptures (`cmdEcran`).
List<Produit> produitsProposes({
  required String q,
  String? cat,
  bool masquer = false,
}) {
  final texte = q.toLowerCase();
  return produitsCatalogue
      .where(
        (p) =>
            (texte.isEmpty ||
                (p.nom + p.marque + p.code + p.ean).toLowerCase().contains(
                  texte,
                )) &&
            (cat == null || p.cat == cat) &&
            !(masquer && p.stock == NiveauStock.rupture),
      )
      .toList();
}

/// Nombre de produits annoncé par « Voir N produits » : la marque et les ruptures, sans la recherche (`cmd-filtres`).
int nbProduitsFiltres({String? cat, bool masquer = false}) => produitsCatalogue
    .where(
      (p) =>
          (cat == null || p.cat == cat) &&
          !(masquer && p.stock == NiveauStock.rupture),
    )
    .length;

/// Passe de la forme ISO `aaaa-mm-jj` à « 16/11/2026 » (affichage d'un champ date).
String dateJourMoisAnnee(String iso) =>
    '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)}';

/// Libellé « 12 articles » du bas de la prise de commande (`article${n > 1 ? 's' : ''}`).
String libelleArticles(int n) => '$n article${n > 1 ? 's' : ''}';
