/// Modèles des filtres de l'équipe : `S.eqf` (type et région, directeur) et `S.sec` (visites et commandes du secteur,
/// chef de secteur). Fonctions pures, sans Riverpod : les providers sont dans `equipe_state.dart`.
library;

import '../../../core/models/models.dart';

/// Valeur « aucun filtre » d'un promoteur, d'un client (`'tous'`).
const String filtreTous = 'tous';

/// Valeur « aucun filtre » de la région (`'toutes'`).
const String regionToutes = 'toutes';

/// Ce que le directeur affiche dans « Mon équipe » : ses chefs de secteur ou leurs promoteurs (`eqf.type`).
enum TypeEquipe {
  chefsSecteur('Chefs de secteur'),
  promoteurs('Promoteurs');

  const TypeEquipe(this.libelle);
  final String libelle;
}

/// Filtres de l'onglet « Mon équipe » du directeur (`S.eqf`).
class FiltresEquipe {
  const FiltresEquipe({
    this.type = TypeEquipe.chefsSecteur,
    this.region = regionToutes,
  });

  final TypeEquipe type;

  /// Une région ou `regionToutes`.
  final String region;

  /// Pastille du bouton filtre : un par filtre qui s'écarte de la valeur par défaut.
  int get nb =>
      (type != TypeEquipe.chefsSecteur ? 1 : 0) +
      (region != regionToutes ? 1 : 0);

  /// Libellé du sélecteur : « Chefs de secteur · Nord ».
  String get libelle =>
      '${type.libelle}${region != regionToutes ? ' · $region' : ''}';

  FiltresEquipe copyWith({TypeEquipe? type, String? region}) =>
      FiltresEquipe(type: type ?? this.type, region: region ?? this.region);
}

/// Portée de la liste du secteur : tout le secteur ou les seules visites et commandes du chef de secteur (`portee`).
enum PorteeSecteur { secteur, moi }

/// Origine d'une commande : toutes, EDI ou saisies dans l'appli (`src`).
enum SourceCommande {
  toutes(filtreTous, 'Toutes les commandes'),
  edi('EDI', 'Commandes EDI'),
  appli('Appli', 'Commandes appli');

  const SourceCommande(this.code, this.libelle);

  /// Valeur de `src` dans les données (« EDI », « Appli »).
  final String code;
  final String libelle;
}

/// Filtres d'une liste du secteur (`S.sec.vis` ou `S.sec.cmd`).
class FiltreSecteur {
  const FiltreSecteur({
    this.portee = PorteeSecteur.secteur,
    this.promo = filtreTous,
    this.client = filtreTous,
    this.src = SourceCommande.toutes,
  });

  final PorteeSecteur portee;

  /// Nom court d'un promoteur ou `filtreTous`.
  final String promo;

  /// Nom d'un client ou `filtreTous`.
  final String client;
  final SourceCommande src;

  /// Pastille du bouton filtre : un par filtre actif.
  int get nb =>
      (portee != PorteeSecteur.secteur ? 1 : 0) +
      (promo != filtreTous ? 1 : 0) +
      (client != filtreTous ? 1 : 0) +
      (src != SourceCommande.toutes ? 1 : 0);

  /// Libellé du sélecteur : « Visites du secteur · Léa P. · Carrefour – Rouen ».
  String resume(GenreSecteur genre) {
    final vis = genre == GenreSecteur.visites;
    final base = portee == PorteeSecteur.moi
        ? (vis ? 'Mes visites' : 'Mes commandes')
        : (vis ? 'Visites du secteur' : 'Commandes du secteur');
    return base +
        (promo != filtreTous ? ' · $promo' : '') +
        (client != filtreTous ? ' · $client' : '') +
        (src != SourceCommande.toutes ? ' · ${src.libelle}' : '');
  }

  FiltreSecteur copyWith({
    PorteeSecteur? portee,
    String? promo,
    String? client,
    SourceCommande? src,
  }) => FiltreSecteur(
    portee: portee ?? this.portee,
    promo: promo ?? this.promo,
    client: client ?? this.client,
    src: src ?? this.src,
  );
}

/// Les deux listes du secteur : visites et commandes (`S.sec`).
class FiltresSecteur {
  const FiltresSecteur({
    this.visites = const FiltreSecteur(),
    this.commandes = const FiltreSecteur(),
  });

  final FiltreSecteur visites;
  final FiltreSecteur commandes;

  FiltreSecteur de(GenreSecteur genre) =>
      genre == GenreSecteur.visites ? visites : commandes;

  FiltresSecteur avec(GenreSecteur genre, FiltreSecteur f) =>
      genre == GenreSecteur.visites
      ? FiltresSecteur(visites: f, commandes: commandes)
      : FiltresSecteur(visites: visites, commandes: f);
}
