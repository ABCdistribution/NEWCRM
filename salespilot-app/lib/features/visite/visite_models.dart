/// Question du questionnaire de visite (définie côté web).
class Question {
  const Question({required this.id, required this.libelle, required this.type, required this.obligatoire});

  final String id;
  final String libelle;

  /// CASE_A_COCHER · TEXTE · NOMBRE · NOTE_1_5
  final String type;
  final bool obligatoire;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        libelle: (j['libelle'] as String?) ?? '',
        type: (j['type'] as String?) ?? 'TEXTE',
        obligatoire: (j['obligatoire'] as bool?) ?? false,
      );
}

/// Contenu saisi d'une visite : sérialisé dans le brouillon à chaque modification.
class VisiteData {
  const VisiteData({
    this.motif,
    this.dnAbc,
    this.dnConcurrence,
    this.dnGondoleHaute,
    this.dnGondoleBasse,
    this.commentaire = '',
    this.reponses = const {},
    this.photos = const [],
  });

  final String? motif;
  final int? dnAbc;
  final int? dnConcurrence;
  final int? dnGondoleHaute;
  final int? dnGondoleBasse;
  final String commentaire;

  /// questionId → valeur saisie.
  final Map<String, String> reponses;

  /// Chemins locaux des photos (déjà compressées).
  final List<String> photos;

  VisiteData copyWith({
    String? motif,
    int? dnAbc,
    int? dnConcurrence,
    int? dnGondoleHaute,
    int? dnGondoleBasse,
    String? commentaire,
    Map<String, String>? reponses,
    List<String>? photos,
    bool clearDnAbc = false,
    bool clearDnConcurrence = false,
    bool clearDnGondoleHaute = false,
    bool clearDnGondoleBasse = false,
  }) =>
      VisiteData(
        motif: motif ?? this.motif,
        dnAbc: clearDnAbc ? null : (dnAbc ?? this.dnAbc),
        dnConcurrence: clearDnConcurrence ? null : (dnConcurrence ?? this.dnConcurrence),
        dnGondoleHaute: clearDnGondoleHaute ? null : (dnGondoleHaute ?? this.dnGondoleHaute),
        dnGondoleBasse: clearDnGondoleBasse ? null : (dnGondoleBasse ?? this.dnGondoleBasse),
        commentaire: commentaire ?? this.commentaire,
        reponses: reponses ?? this.reponses,
        photos: photos ?? this.photos,
      );

  Map<String, dynamic> toJson() => {
        'motif': motif,
        'dnAbc': dnAbc,
        'dnConcurrence': dnConcurrence,
        'dnGondoleHaute': dnGondoleHaute,
        'dnGondoleBasse': dnGondoleBasse,
        'commentaire': commentaire,
        'reponses': reponses,
        'photos': photos,
      };

  factory VisiteData.fromJson(Map<String, dynamic> j) => VisiteData(
        motif: j['motif'] as String?,
        dnAbc: j['dnAbc'] as int?,
        dnConcurrence: j['dnConcurrence'] as int?,
        dnGondoleHaute: j['dnGondoleHaute'] as int?,
        dnGondoleBasse: j['dnGondoleBasse'] as int?,
        commentaire: (j['commentaire'] as String?) ?? '',
        reponses: ((j['reponses'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, v as String)),
        photos: ((j['photos'] as List?) ?? const []).cast<String>(),
      );
}

/// Motifs de visite proposés (texte libre côté API, ≤ 60 caractères).
const motifsVisite = ['Planifiée', 'Appel client', 'Passage opportunité', 'Urgence', 'Prospection'];

/// Résultat du contrôle avant validation (CDC §3.4 : on ne valide pas une visite incomplète par erreur).
class VisiteControle {
  const VisiteControle({
    required this.bloquants,
    required this.questionsRepondues,
    required this.questionsTotal,
    required this.photos,
  });

  /// Problèmes qui empêchent la validation.
  final List<String> bloquants;
  final int questionsRepondues;
  final int questionsTotal;
  final int photos;

  bool get peutValider => bloquants.isEmpty;
}

abstract final class VisiteValidator {
  /// Contrôle une visite : motif renseigné, questions obligatoires répondues (la liste des champs obligatoires
  /// est à fixer avec le métier — CDC §10, question 14).
  static VisiteControle controle(VisiteData d, List<Question> questions) {
    final bloquants = <String>[];
    if ((d.motif ?? '').trim().isEmpty) bloquants.add('Le motif de la visite est obligatoire.');

    var repondues = 0;
    for (final q in questions) {
      final v = d.reponses[q.id]?.trim() ?? '';
      if (v.isNotEmpty) repondues++;
      if (q.obligatoire && v.isEmpty) bloquants.add('Question obligatoire sans réponse : « ${q.libelle} ».');
    }
    return VisiteControle(
      bloquants: bloquants,
      questionsRepondues: repondues,
      questionsTotal: questions.length,
      photos: d.photos.length,
    );
  }
}
