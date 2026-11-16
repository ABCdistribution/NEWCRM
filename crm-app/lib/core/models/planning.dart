/// Planning de la semaine : maquette `etapes` (lignes de planning) et `tourneeSales` (tournée du promoteur).
library;

/// Nature d'une ligne de planning.
enum CiblePlanning {
  client('client', 'Client'),
  prospect('prospect', 'Prospect'),
  adm('adm', 'ADM'),
  libre('libre', 'Libre');

  const CiblePlanning(this.code, this.libelle);
  final String code;
  final String libelle;
}

/// Une ligne du planning (RDV, visite, tâche administrative…).
class EtapePlanning {
  const EtapePlanning({
    required this.id,
    required this.jour,
    required this.heure,
    required this.cible,
    required this.titre,
    this.ref,
    this.visite = true,
    this.acc = false,
    this.rdv = false,
    this.appel = false,
    this.remp = false,
    this.soiree = false,
    this.soireeLieu,
    this.soireeAdr,
    this.note = '',
    this.fait = false,
    this.sem,
  });

  final String id;

  /// 0 = lundi … 4 = vendredi.
  final int jour;

  /// « 09:30 » (peut être vide).
  final String heure;
  final CiblePlanning cible;

  /// Id du magasin ou du prospect visé (nul pour « Libre » et « ADM »).
  final String? ref;
  final String titre;
  final bool visite;

  /// Accompagnement.
  final bool acc;
  final bool rdv;

  /// Appel téléphonique.
  final bool appel;

  /// Visite de remplacement.
  final bool remp;

  /// Soirée étape (lieu et adresse obligatoires).
  final bool soiree;
  final String? soireeLieu;
  final String? soireeAdr;
  final String note;
  final bool fait;

  /// Décalage de semaine (planning d'un promoteur ouvert par son encadrement) ; nul = semaine courante.
  final int? sem;

  EtapePlanning copyWith({
    int? jour,
    String? heure,
    CiblePlanning? cible,
    String? ref,
    String? titre,
    bool? visite,
    bool? acc,
    bool? rdv,
    bool? appel,
    bool? remp,
    bool? soiree,
    String? soireeLieu,
    String? soireeAdr,
    String? note,
    bool? fait,
    int? sem,
  }) {
    return EtapePlanning(
      id: id,
      jour: jour ?? this.jour,
      heure: heure ?? this.heure,
      cible: cible ?? this.cible,
      ref: ref ?? this.ref,
      titre: titre ?? this.titre,
      visite: visite ?? this.visite,
      acc: acc ?? this.acc,
      rdv: rdv ?? this.rdv,
      appel: appel ?? this.appel,
      remp: remp ?? this.remp,
      soiree: soiree ?? this.soiree,
      soireeLieu: soireeLieu ?? this.soireeLieu,
      soireeAdr: soireeAdr ?? this.soireeAdr,
      note: note ?? this.note,
      fait: fait ?? this.fait,
      sem: sem ?? this.sem,
    );
  }
}

/// Une étape de la tournée du jour du promoteur (`tourneeSales`).
class TourneeVisite {
  const TourneeVisite({
    required this.id,
    required this.magasinId,
    required this.heure,
    required this.type,
  });

  final String id;
  final String magasinId;
  final String heure;

  /// « Planifiée », « Appel client », « Passage opportunité », « Urgence »…
  final String type;
}
