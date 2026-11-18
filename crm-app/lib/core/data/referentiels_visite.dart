/// Listes du CRM qui servent au parcours de visite : questionnaire de fin de visite, raisons d'absence de commande,
/// promotions à pointer (OP). Toutes en lecture seule.
library;

/// Type de réponse attendu à une question du questionnaire (`TypeQuestion` du CRM).
enum TypeQuestionFin {
  caseACocher,
  texte,
  nombre,
  note;

  static TypeQuestionFin depuisCode(Object? code) => switch (code) {
    'TEXTE' => texte,
    'NOMBRE' => nombre,
    'NOTE_1_5' => note,
    _ => caseACocher,
  };
}

class QuestionFin {
  const QuestionFin({
    required this.id,
    required this.libelle,
    required this.type,
    required this.obligatoire,
  });

  final String id;
  final String libelle;
  final TypeQuestionFin type;
  final bool obligatoire;
}

class RaisonAbsence {
  const RaisonAbsence({required this.id, required this.libelle});

  final String id;
  final String libelle;
}

/// Promotion en cours à pointer en rayon (étape « Pointage OP »).
class PromoOp {
  const PromoOp({required this.id, required this.libelle, this.article = ''});

  final String id;
  final String libelle;

  /// Nom de l'article concerné.
  final String article;
}

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Questions actives, dans l'ordre de l'API ; les lignes sans identifiant ou sans libellé sont ignorées.
List<QuestionFin> questionsDepuisJson(Object? json) => [
  if (json is List)
    for (final l in json)
      if (l is Map<String, dynamic> &&
          _texte(l['id']) != null &&
          _texte(l['libelle']) != null &&
          l['actif'] != false)
        QuestionFin(
          id: l['id'] as String,
          libelle: _texte(l['libelle'])!,
          type: TypeQuestionFin.depuisCode(l['type']),
          obligatoire: l['obligatoire'] == true,
        ),
];

List<RaisonAbsence> raisonsDepuisJson(Object? json) => [
  if (json is List)
    for (final l in json)
      if (l is Map<String, dynamic> &&
          _texte(l['id']) != null &&
          _texte(l['libelle']) != null &&
          l['actif'] != false)
        RaisonAbsence(id: l['id'] as String, libelle: _texte(l['libelle'])!),
];

List<PromoOp> promosOpDepuisJson(Object? json) => [
  if (json is List)
    for (final l in json)
      if (l is Map<String, dynamic> && _texte(l['id']) != null)
        PromoOp(
          id: l['id'] as String,
          libelle:
              _texte(l['libelle']) ??
              (l['article'] is Map
                  ? _texte((l['article'] as Map)['libelle'])
                  : null) ??
              'Promotion',
          article: l['article'] is Map
              ? _texte((l['article'] as Map)['libelle']) ?? ''
              : '',
        ),
];
