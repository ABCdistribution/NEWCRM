/// Prospect et timeline de prospection : maquette `prospects`, `LIB_STATUT`, `groupe()`, `segments()`.
library;

/// Statut d'un prospect (codes de la maquette : NOUVEAU, CONTACTE, VISITE…).
enum StatutProspect {
  nouveau('NOUVEAU', 'Fiche créée', 10),
  contacte('CONTACTE', 'Contacté', 20),
  visite('VISITE', 'RDV pris', 40),
  proposition('PROPOSITION', 'Proposition', 55),
  negociation('NEGOCIATION', 'En négociation', 60),
  gagne('GAGNE', 'Référencé', 100),
  perdu('PERDU', 'Perdu', 0);

  const StatutProspect(this.code, this.libelle, this.probaParDefaut);

  /// Code technique (celui de la maquette et de l'API).
  final String code;

  /// Libellé de la maquette (`LIB_STATUT`).
  final String libelle;

  /// Probabilité appliquée par défaut quand on change d'étape.
  final int probaParDefaut;

  /// Colonne du pipeline (`groupe()`), nulle pour « Perdu ».
  GroupeProspect? get groupe => switch (this) {
    nouveau || contacte => GroupeProspect.aContacter,
    visite => GroupeProspect.rdvPris,
    proposition || negociation => GroupeProspect.enNego,
    gagne => GroupeProspect.reference,
    perdu => null,
  };

  /// Nombre de segments remplis dans la barre d'étapes (`segments()`).
  int get segments => switch (this) {
    nouveau => 1,
    contacte => 2,
    visite => 3,
    proposition || negociation => 4,
    gagne => 5,
    perdu => 1,
  };

  static StatutProspect depuisCode(String code) =>
      StatutProspect.values.firstWhere((s) => s.code == code);
}

/// Groupes du pipeline (tuiles de la page Prospects).
enum GroupeProspect {
  aContacter('À contacter'),
  rdvPris('RDV pris'),
  enNego('En négo'),
  reference('Référencé');

  const GroupeProspect(this.libelle);
  final String libelle;
}

/// Icône d'un événement de timeline (la maquette utilise des emojis).
enum IconeEvenement {
  cal('📅'),
  pin('📍'),
  doc('📄'),
  tel('📞'),
  plus('＋');

  const IconeEvenement(this.emoji);
  final String emoji;
}

/// Événement de la timeline d'un prospect (`tl`).
class EvenementProspect {
  const EvenementProspect({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.date,
    required this.detail,
  });

  final IconeEvenement icone;

  /// Couleur d'accent ARGB (le fond de l'icône est cette couleur à ~13 %).
  final int couleur;
  final String titre;

  /// Date en texte libre (« 30 oct. », « ven. 6 nov. », « auj. »).
  final String date;
  final String detail;
}

class Prospect {
  const Prospect({
    required this.id,
    required this.nom,
    required this.raison,
    required this.classe,
    required this.cp,
    required this.statut,
    required this.pot,
    required this.proba,
    required this.timeline,
    this.contact,
    this.secteurId,
    this.cs,
    this.attente = false,
  });

  final String id;
  final String nom;
  final String raison;
  final String classe;

  /// Code postal et ville (« 78000 Versailles »).
  final String cp;
  final StatutProspect statut;

  /// Potentiel annuel en k€.
  final double pot;

  /// Probabilité de signature, en %.
  final int proba;
  final String? contact;
  final List<EvenementProspect> timeline;

  /// Secteur (« s1 », « s2 ») et chef de secteur responsable (« Nadia H. »).
  final String? secteurId;
  final String? cs;

  /// Vrai tant que le prospect créé sur le téléphone n'est pas envoyé (« En attente d'envoi »).
  final bool attente;

  GroupeProspect? get groupe => statut.groupe;

  Prospect copyWith({
    String? nom,
    String? raison,
    String? classe,
    String? cp,
    StatutProspect? statut,
    double? pot,
    int? proba,
    String? contact,
    List<EvenementProspect>? timeline,
    String? secteurId,
    String? cs,
    bool? attente,
  }) {
    return Prospect(
      id: id,
      nom: nom ?? this.nom,
      raison: raison ?? this.raison,
      classe: classe ?? this.classe,
      cp: cp ?? this.cp,
      statut: statut ?? this.statut,
      pot: pot ?? this.pot,
      proba: proba ?? this.proba,
      contact: contact ?? this.contact,
      timeline: timeline ?? this.timeline,
      secteurId: secteurId ?? this.secteurId,
      cs: cs ?? this.cs,
      attente: attente ?? this.attente,
    );
  }
}
