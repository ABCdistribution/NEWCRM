/// Équipe et objectifs en euros : maquette `PROMOS`, `EQUIPE_CS`, `OBJ_EUR`.
///
/// Ce noyau est partagé par les lots accueil, planning et équipe. Le détail propre
/// à l'équipe (prévision enregistrée, rapports hebdomadaires…) reste dans `features/equipe`.
library;

/// Genre de la liste du secteur de l'encadrement : visites ou commandes (onglets « Visites » et « Commandes » du chef de secteur).
enum GenreSecteur { visites, commandes }

/// État d'une visite de la tournée du jour d'un promoteur.
enum EtatTourneePromo { realisee, enCours, aFaire }

/// Une visite de la tournée du jour d'un promoteur (`jour: [heure, client, état]`).
class VisiteJourPromo {
  const VisiteJourPromo(this.heure, this.client, this.etat);
  final String heure;
  final String client;
  final EtatTourneePromo etat;
}

class Promoteur {
  const Promoteur({
    required this.nom,
    required this.ini,
    required this.mag,
    required this.v,
    required this.p,
    required this.real,
    required this.cible,
    required this.jour,
    this.reel = false,
    this.commandes = 0,
    this.userId,
  });

  final String nom;
  final String ini;

  /// Nombre de clients.
  final int mag;

  /// Visites réalisées / prévues cette semaine.
  final int v;
  final int p;

  /// CA réalisé et objectif du mois, en euros.
  final double real;
  final double cible;
  final List<VisiteJourPromo> jour;

  /// Vrai pour un promoteur du CRM : `v` est alors le nombre de visites du mois, `p` vaut 0 et il n'y a ni tournée
  /// du jour ni planning.
  final bool reel;

  /// Commandes du mois (promoteur du CRM).
  final int commandes;

  /// Identifiant de l'utilisateur dans le CRM (promoteur du CRM), sert à sa photo.
  final String? userId;

  /// Taux d'atteinte de l'objectif, en % arrondi (`obj`).
  int get obj => cible <= 0 ? 0 : (real / cible * 100).round();
}

/// Chef de secteur (identité seulement).
class ChefSecteur {
  const ChefSecteur({
    required this.id,
    required this.nom,
    required this.ini,
    required this.region,
    required this.secteur,
    this.reel = false,
    this.visites = 0,
    this.commandes = 0,
    this.ca = 0,
    this.objectif = 0,
  });

  /// « n », « k » ou « s ».
  final String id;
  final String nom;
  final String ini;
  final String region;
  final String secteur;

  /// Vrai pour un chef de secteur du CRM (activité du mois ci-dessous, sans planning ni rapports).
  final bool reel;
  final int visites;
  final int commandes;
  final double ca;
  final double objectif;
}

/// Total réalisé / cible d'un groupe de promoteurs (`totalEq`).
class TotalObjectif {
  const TotalObjectif(this.real, this.cible);
  final double real;
  final double cible;

  double get reste => (cible - real) < 0 ? 0 : cible - real;
  double get ratio => cible == 0 ? 0 : real / cible;
}
