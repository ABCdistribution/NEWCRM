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

/// Étapes de la visite, dans l'ordre (`ETAPES_DPH` de la maquette, remplacées par le parcours réel). `debut` est posée à
/// la création ; les huit autres sont parcourues avec « Précédent » / « Suivant ».
enum EtapeDph {
  debut('debut', 'Début de visite'),
  arrivee('arrivee', "Photo d'arrivée sur site"),
  rayonArrivee('rayonArrivee', 'Photo du rayon'),
  colis('colis', 'Commande à mettre en rayon'),
  dn('dn', 'Vérification DN'),
  commande('commande', 'Commande liée à la visite'),
  questionnaire('questionnaire', 'Questionnaire de fin de visite'),
  op('op', 'Pointage OP'),
  rayonFin('rayonFin', 'Photo du rayon de fin de visite');

  const EtapeDph(this.cle, this.libelle);
  final String cle;
  final String libelle;

  /// Étapes qui consistent à prendre des photos.
  bool get estPhoto => this == arrivee || this == rayonArrivee || this == rayonFin;

  /// Étapes du parcours « Précédent / Suivant » (toutes sauf le début).
  static List<EtapeDph> get parcours => [
    for (final e in values)
      if (e != debut) e,
  ];
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
    this.parId,
    this.dn = const {},
    this.kits = const [],
    this.commandeEnRayon,
    this.colis = const [],
    this.raisonAbsenceId,
    this.raisonAbsence = '',
    this.reponses = const {},
    this.op = const {},
    this.cmd,
  });

  final String id;

  /// Numéro de visite affiché (« Visite #218081 »).
  final int num;
  final String magasinId;

  /// Auteur de la visite (nom court du promoteur).
  final String par;

  /// Identifiant CRM de l'auteur (visites venues du CRM).
  final String? parId;
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

  /// Y a-t-il une commande à mettre en rayon ? Nul tant que le promoteur n'a pas répondu.
  final bool? commandeEnRayon;

  /// Codes des colis de la commande à mettre en rayon.
  final List<String> colis;

  /// Raison d'absence de commande choisie (identifiant CRM et libellé), vides tant qu'aucune n'est choisie.
  final String? raisonAbsenceId;
  final String raisonAbsence;

  /// Réponses au questionnaire de fin de visite : identifiant de la question → valeur (« true », texte, nombre, note).
  final Map<String, String> reponses;

  /// Pointage OP : identifiant de la promotion → présente en rayon ?
  final Map<String, bool> op;
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
    bool? commandeEnRayon,
    List<String>? colis,
    String? raisonAbsenceId,
    String? raisonAbsence,
    Map<String, String>? reponses,
    Map<String, bool>? op,
    CommandeLiee? cmd,
  }) {
    return Visite(
      id: id,
      num: num,
      magasinId: magasinId,
      par: par,
      parId: parId,
      etat: etat ?? this.etat,
      date: date,
      age: age ?? this.age,
      chrono: chrono ?? this.chrono,
      photos: photos ?? this.photos,
      recu: recu ?? this.recu,
      dn: dn ?? this.dn,
      kits: kits ?? this.kits,
      commandeEnRayon: commandeEnRayon ?? this.commandeEnRayon,
      colis: colis ?? this.colis,
      raisonAbsenceId: raisonAbsenceId ?? this.raisonAbsenceId,
      raisonAbsence: raisonAbsence ?? this.raisonAbsence,
      reponses: reponses ?? this.reponses,
      op: op ?? this.op,
      cmd: cmd ?? this.cmd,
    );
  }
}
