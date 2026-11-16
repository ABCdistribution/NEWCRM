/// Client (point de vente) : maquette `magasins`, `AUTRES_CLIENTS`.
library;

class Magasin {
  const Magasin({
    required this.id,
    required this.nom,
    required this.statut,
    required this.classe,
    required this.adresse,
    required this.ca,
    required this.evo,
    required this.cde,
    required this.cdeDate,
    required this.visites,
    required this.objectif,
    this.surface,
    this.contact,
    this.actif = true,
    this.secteurId,
    this.promoId,
    this.reel = false,
  });

  final String id;

  /// « Enseigne – Ville » (le tiret est un demi-cadratin avec espaces).
  final String nom;

  /// Libellé de statut affiché sur la fiche (« Client actif », « Client · À relancer »…).
  final String statut;

  /// Classification A++ … G (fréquence de visite attendue, voir `seuilVisite`).
  final String classe;
  final String adresse;

  /// CA 12 mois déjà formaté (« 29,4 k€ », « — »).
  final String ca;

  /// Évolution du CA (« −14 % », « +3 % », vide).
  final String evo;

  /// Montant et date de la dernière commande, déjà formatés.
  final String cde;
  final String cdeDate;

  /// Visites réalisées ce mois et objectif mensuel de visites.
  final int visites;
  final int objectif;
  final String? surface;
  final String? contact;

  /// Faux pour un client inactif (maquette : `actif === false`).
  final bool actif;

  /// Rattachement : secteur (« s1 », « s2 ») et promoteur (« j », « l », « a »).
  /// Nul pour les clients hors région (`AUTRES_CLIENTS`).
  final String? secteurId;
  final String? promoId;

  /// Vrai pour un client téléchargé du CRM (et non de la démonstration) : les chiffres que le CRM ne fournit pas
  /// encore (CA, objectifs, opérations promotionnelles) ne sont pas inventés.
  final bool reel;

  /// Enseigne = partie avant « – » (maquette : `enseigneDe`).
  String get enseigne => nom.split(' – ').first;
}
