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

/// Nature d'une visite : visite commerciale, ou visite PEM (parcours distinct, lié à une proposition du CRM).
enum TypeVisite {
  commerciale,
  pem;

  static TypeVisite depuisCode(Object? code) =>
      code == 'PEM' ? pem : commerciale;
}

/// Étapes de la visite, dans l'ordre (`ETAPES_DPH` de la maquette, remplacées par le parcours réel). `debut` est posée à
/// la création ; les autres sont parcourues avec « Précédent » / « Suivant » (« Produits indispensables » seulement
/// quand la liste de l'enseigne du magasin est connue).
enum EtapeDph {
  debut('debut', 'Début de visite'),
  arrivee('arrivee', "Photo d'arrivée sur site"),
  rayonArrivee('rayonArrivee', 'Photo du rayon'),
  colis('colis', 'Commande à mettre en rayon'),
  dn('dn', 'Vérification DN'),
  indispensables('indispensables', 'Vérification des produits indispensables'),
  articlesPem('articlesPem', 'Vérification des articles PEM'),
  commande('commande', 'Commande liée à la visite'),
  questionnaire('questionnaire', 'Questionnaire de fin de visite'),
  rayonFin('rayonFin', 'Photo du rayon de fin de visite');

  const EtapeDph(this.cle, this.libelle);
  final String cle;
  final String libelle;

  /// Étapes qui consistent à prendre des photos.
  bool get estPhoto =>
      this == arrivee || this == rayonArrivee || this == rayonFin;

  /// Étapes du parcours commercial « Précédent / Suivant » (toutes sauf le début et la vérification PEM).
  static List<EtapeDph> get parcours => [
    for (final e in values)
      if (e != debut && e != articlesPem) e,
  ];

  /// Étapes du parcours d'une visite PEM : pas de commande, de DN ni de produits indispensables.
  static const List<EtapeDph> parcoursPem = [
    arrivee,
    rayonArrivee,
    articlesPem,
    questionnaire,
    rayonFin,
  ];

  /// Étapes réellement proposées : sans « Produits indispensables » quand le magasin n'a pas de liste.
  static List<EtapeDph> parcoursPour({required bool indispensables}) => [
    for (final e in parcours)
      if (indispensables || e != EtapeDph.indispensables) e,
  ];

  /// Parcours d'une visite PEM : sans « Vérification des articles PEM » quand la liste des articles est inconnue.
  static List<EtapeDph> parcoursPemPour({required bool articles}) => [
    for (final e in parcoursPem)
      if (articles || e != EtapeDph.articlesPem) e,
  ];

  /// Libellé de l'étape dans une visite de ce type (les photos du rayon s'appellent « avant » et « après » en PEM).
  String libellePour(TypeVisite type) {
    if (type != TypeVisite.pem) return libelle;
    return switch (this) {
      rayonArrivee => 'Photo du rayon avant',
      rayonFin => 'Photo du rayon après',
      _ => libelle,
    };
  }
}

/// Relevé d'un article PEM : présent ou absent, et mis en avant ou non (seulement s'il est présent).
typedef ReleveArticlePem = ({bool present, bool misEnAvant});

/// Commande liée à une visite (`cmd` : `{ id, ht, liv }`).
class CommandeLiee {
  const CommandeLiee({
    required this.id,
    required this.ht,
    required this.liv,
    this.idApk,
  });
  final String id;

  /// Identifiant mobile de la commande (`idCommandeApk`) : le compte-rendu de visite envoyé au CRM s'y rattache. Nul
  /// pour une commande qui ne passe pas par la file d'envoi (démonstration, visite venue du CRM).
  final String? idApk;

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
    this.raisonAbsenceId,
    this.raisonAbsence = '',
    this.reponses = const {},
    this.indispensables = const {},
    this.libellesIndispensables = const {},
    this.cmd,
    this.typeVisite = TypeVisite.commerciale,
    this.propositionPemId,
    this.planningId,
    this.articlesPem = const {},
    this.libellesArticlesPem = const {},
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

  /// Raison d'absence de commande choisie (identifiant CRM et libellé), vides tant qu'aucune n'est choisie.
  final String? raisonAbsenceId;
  final String raisonAbsence;

  /// Réponses au questionnaire de fin de visite : identifiant de la question → valeur (« true », texte, nombre, note).
  final Map<String, String> reponses;

  /// Produits indispensables relevés : identifiant de l'article → présent (vrai) ou absent (faux).
  final Map<String, bool> indispensables;

  /// Libellés des articles relevés, quand le CRM les donne avec la visite (identifiant de l'article → libellé).
  final Map<String, String> libellesIndispensables;

  final CommandeLiee? cmd;

  /// Visite commerciale ou visite PEM.
  final TypeVisite typeVisite;

  /// Proposition PEM du CRM à laquelle la visite répond (visite PEM seulement).
  final String? propositionPemId;

  /// Visite planifiée du CRM (ligne de planning du promoteur) que cette visite solde : renseignée seulement quand la
  /// visite démarre depuis « Ma tournée du jour » (étape venue du CRM), nulle sinon.
  final String? planningId;

  /// Articles PEM relevés : identifiant de l'article → présent / mis en avant.
  final Map<String, ReleveArticlePem> articlesPem;

  /// Libellés des articles PEM relevés, quand le CRM les donne avec la visite (identifiant de l'article → libellé).
  final Map<String, String> libellesArticlesPem;

  bool get estPem => typeVisite == TypeVisite.pem;

  /// Étapes du parcours de cette visite (sans le début), toutes proposées.
  List<EtapeDph> get etapes =>
      estPem ? EtapeDph.parcoursPem : EtapeDph.parcours;

  /// Nombre de produits indispensables relevés absents.
  int get indispensablesAbsents =>
      indispensables.values.where((p) => !p).length;

  /// Nombre d'articles PEM relevés absents.
  int get articlesPemAbsents =>
      articlesPem.values.where((a) => !a.present).length;

  /// Nombre d'articles PEM relevés présents et mis en avant.
  int get articlesPemMisEnAvant =>
      articlesPem.values.where((a) => a.present && a.misEnAvant).length;

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
    String? raisonAbsenceId,
    String? raisonAbsence,
    Map<String, String>? reponses,
    Map<String, bool>? indispensables,
    Map<String, String>? libellesIndispensables,
    CommandeLiee? cmd,
    Map<String, ReleveArticlePem>? articlesPem,
    Map<String, String>? libellesArticlesPem,
    String? planningId,
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
      raisonAbsenceId: raisonAbsenceId ?? this.raisonAbsenceId,
      raisonAbsence: raisonAbsence ?? this.raisonAbsence,
      reponses: reponses ?? this.reponses,
      indispensables: indispensables ?? this.indispensables,
      libellesIndispensables:
          libellesIndispensables ?? this.libellesIndispensables,
      cmd: cmd ?? this.cmd,
      typeVisite: typeVisite,
      propositionPemId: propositionPemId,
      planningId: planningId ?? this.planningId,
      articlesPem: articlesPem ?? this.articlesPem,
      libellesArticlesPem: libellesArticlesPem ?? this.libellesArticlesPem,
    );
  }
}
