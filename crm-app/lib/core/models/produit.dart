/// Produit du catalogue : maquette `PRODUITS`, `PRODUITS_KIT`, `PRODUITS_PEM`, `CATS`.
library;

/// Niveau de stock affiché (« En stock », « Stock bas », « Rupture »).
enum NiveauStock {
  enStock('En stock'),
  stockBas('Stock bas'),
  rupture('Rupture');

  const NiveauStock(this.libelle);
  final String libelle;
}

class Produit {
  const Produit({
    required this.id,
    required this.nom,
    required this.marque,
    required this.famille,
    required this.code,
    this.cat,
    this.ean = '',
    this.prix,
    this.stock,
    this.promo,
    this.avant = false,
    this.pcb,
    this.qte,
    this.kit = false,
    this.pem = false,
    this.actif,
    this.reappro,
  });

  final String id;
  final String nom;
  final String marque;

  /// Marque de filtre (`CATS`), nulle pour les kits et les produits PEM.
  final String? cat;
  final String famille;

  /// Code article.
  final String code;
  final String ean;

  /// Prix HT indicatif (nul pour les kits et les produits PEM).
  final double? prix;
  final NiveauStock? stock;

  /// Libellé de promotion en cours, nul sinon.
  final String? promo;

  /// Produit mis en avant.
  final bool avant;

  /// Colisage (unités par colis).
  final int? pcb;

  /// Quantité disponible.
  final int? qte;
  final bool kit;
  final bool pem;

  /// Statut d'un produit PEM (nul = non renseigné).
  final bool? actif;

  /// Date de réapprovisionnement (produits en rupture), en texte.
  final String? reappro;
}
