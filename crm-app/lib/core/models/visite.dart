/// Visite chez un client : maquette `visites`, `VISITES_AUTRES`, `ETAPES_DPH`.
library;

/// État d'une visite (maquette : `brouillon`, `terminee`, `envoyee`).
enum EtatVisite {
  brouillon('Brouillon', 'En cours'),
  terminee('À envoyer', 'À envoyer'),
  envoyee('Envoyée', 'Envoyée');

  const EtatVisite(this.libelle, this.libelleBadge);

  /// Libellé de la pastille dans les listes (`LIB_VIS`).
  final String libelle;

  /// Libellé du badge de l'en-tête d'une visite (`badgeV`).
  final String libelleBadge;
}

/// Étapes de la visite DPH, dans l'ordre (`ETAPES_DPH`).
enum EtapeDph {
  debut('debut', 'Début visite DPH'),
  arrivee('arrivee', "Photos d'arrivée sur site"),
  rayonArrivee('rayonArrivee', "Photo(s) du rayon à l'arrivée"),
  dn('dn', 'Vérification DN'),
  concurrence('concurrence', 'Concurrence'),
  promos('promos', 'Vérification Promos'),
  face('face', 'Photos vue de face'),
  rayonFin('rayonFin', 'Photos du rayon de fin de visite DPH'),
  bilan('bilan', 'Bilan de visite');

  const EtapeDph(this.cle, this.libelle);
  final String cle;
  final String libelle;

  /// Étapes qui consistent à prendre des photos (`PHOTO_CLES`).
  bool get estPhoto =>
      this == arrivee ||
      this == rayonArrivee ||
      this == face ||
      this == rayonFin;
}

/// Marque concurrente relevée en rayon, avec son métrage linéaire.
class MarqueConcurrente {
  const MarqueConcurrente({required this.marque, required this.metrage});
  final String marque;

  /// Mètres linéaires.
  final double metrage;
}

/// Relevé de la concurrence d'une visite.
class Concurrence {
  const Concurrence({this.aucune = false, this.liste = const []});

  /// Vrai si le promoteur a coché « Aucune marque concurrente en rayon ».
  final bool aucune;
  final List<MarqueConcurrente> liste;
}

/// Visite PEM : réalisée ou non, avec la raison de l'absence (`pem`).
class VisitePem {
  const VisitePem({this.realisee, this.raison = ''});

  /// Nul tant que le promoteur n'a pas répondu.
  final bool? realisee;
  final String raison;
}

/// Commande liée à une visite (`cmd` : `{ id, ht, liv }`).
class CommandeLiee {
  const CommandeLiee({required this.id, required this.ht, required this.liv});
  final String id;

  /// Montant HT déjà formaté (« 2 340,00 € »).
  final String ht;

  /// Date de livraison « jj/mm/aaaa ».
  final String liv;
}

class Visite {
  const Visite({
    required this.id,
    required this.num,
    required this.magasinId,
    required this.par,
    required this.etat,
    required this.date,
    required this.age,
    required this.chrono,
    required this.photos,
    this.recu,
    this.dn = const {},
    this.kits = const [],
    this.promosConformes,
    this.promosNote = '',
    this.bilanValide = false,
    this.bilanNote = '',
    this.concurrence = const Concurrence(),
    this.pem = const VisitePem(),
    this.cmd,
  });

  final String id;

  /// Numéro de visite affiché (« Visite #218081 »).
  final int num;
  final String magasinId;

  /// Auteur de la visite (nom court du promoteur).
  final String par;
  final EtatVisite etat;

  /// « 4 nov. 08:30 ».
  final String date;

  /// Jours écoulés depuis la visite (0 = aujourd'hui).
  final int age;

  /// Horodatage de chaque étape faite (« 04/11/2026 08h30 »).
  final Map<EtapeDph, String> chrono;

  /// Horodatage de réception côté serveur (nul tant que la visite n'est pas terminée).
  final String? recu;

  /// Nombre de photos par étape photo.
  final Map<EtapeDph, int> photos;

  /// Distribution numérique : code du kit → nombre de références constatées.
  final Map<String, int> dn;

  /// Codes des kits constatés en rayon.
  final List<String> kits;

  /// Promotions conformes ? Nul = pas encore indiqué.
  final bool? promosConformes;
  final String promosNote;
  final bool bilanValide;
  final String bilanNote;
  final Concurrence concurrence;
  final VisitePem pem;
  final CommandeLiee? cmd;

  bool etapeFaite(EtapeDph e) => chrono.containsKey(e);

  Visite copyWith({
    EtatVisite? etat,
    int? age,
    Map<EtapeDph, String>? chrono,
    String? recu,
    Map<EtapeDph, int>? photos,
    Map<String, int>? dn,
    List<String>? kits,
    bool? promosConformes,
    String? promosNote,
    bool? bilanValide,
    String? bilanNote,
    Concurrence? concurrence,
    VisitePem? pem,
    CommandeLiee? cmd,
  }) {
    return Visite(
      id: id,
      num: num,
      magasinId: magasinId,
      par: par,
      etat: etat ?? this.etat,
      date: date,
      age: age ?? this.age,
      chrono: chrono ?? this.chrono,
      photos: photos ?? this.photos,
      recu: recu ?? this.recu,
      dn: dn ?? this.dn,
      kits: kits ?? this.kits,
      promosConformes: promosConformes ?? this.promosConformes,
      promosNote: promosNote ?? this.promosNote,
      bilanValide: bilanValide ?? this.bilanValide,
      bilanNote: bilanNote ?? this.bilanNote,
      concurrence: concurrence ?? this.concurrence,
      pem: pem ?? this.pem,
      cmd: cmd ?? this.cmd,
    );
  }
}
