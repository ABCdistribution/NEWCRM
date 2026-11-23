/// Listes du CRM qui servent au parcours de visite : questionnaire de fin de visite, raisons d'absence de commande,
/// promotions du briefing. Toutes en lecture seule.
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

/// Produit que le CRM exige en rayon chez les magasins d'une enseigne (centrale) ; le promoteur relève s'il est présent.
class ProduitIndispensable {
  const ProduitIndispensable({
    required this.articleId,
    required this.libelle,
    this.code = '',
    this.marque = '',
  });

  final String articleId;
  final String libelle;

  /// Code AS400 de l'article.
  final String code;
  final String marque;
}

/// Article PEM actif que le promoteur relève lors d'une visite PEM (présent ou absent, mis en avant ou non).
class ArticlePem {
  const ArticlePem({
    required this.articleId,
    required this.libelle,
    this.code = '',
    this.marque = '',
  });

  final String articleId;
  final String libelle;

  /// Code AS400 de l'article.
  final String code;
  final String marque;
}

class RaisonAbsence {
  const RaisonAbsence({required this.id, required this.libelle});

  final String id;
  final String libelle;
}

/// Promotion en cours ou à venir, présentée dans le briefing du magasin.
class PromoOp {
  const PromoOp({
    required this.id,
    required this.libelle,
    this.article = '',
    this.debut,
    this.fin,
  });

  final String id;
  final String libelle;

  /// Nom de l'article concerné.
  final String article;

  /// Période de la promotion (jours, à minuit) ; nulle = pas de borne.
  final DateTime? debut;
  final DateTime? fin;
}

/// Jour (à minuit, heure locale) d'une date ISO de l'API ; nul si elle manque ou est illisible.
DateTime? _jourDe(Object? v) {
  final d = v is String ? DateTime.tryParse(v)?.toLocal() : null;
  return d == null ? null : DateTime(d.year, d.month, d.day);
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

/// Produits indispensables du magasin (`GET /produits-indispensables/client/:id`), dans l'ordre de l'API ; les lignes
/// sans article ou sans libellé sont ignorées.
List<ProduitIndispensable> indispensablesDepuisJson(Object? json) => [
  if (json is List)
    for (final l in json)
      if (l is Map<String, dynamic> && l['article'] is Map)
        if (_texte(l['articleId'] ?? (l['article'] as Map)['id']) != null &&
            _texte((l['article'] as Map)['libelle']) != null)
          ProduitIndispensable(
            articleId: _texte(l['articleId'] ?? (l['article'] as Map)['id'])!,
            libelle: _texte((l['article'] as Map)['libelle'])!,
            code: _texte((l['article'] as Map)['codeAs400']) ?? '',
            marque: (l['article'] as Map)['marque'] is Map
                ? _texte(((l['article'] as Map)['marque'] as Map)['nom']) ?? ''
                : '',
          ),
];

/// Articles PEM à vérifier (`GET /pem/articles`), dans l'ordre de l'API ; les lignes sans article ou sans libellé sont
/// ignorées.
List<ArticlePem> articlesPemDepuisJson(Object? json) => [
  if (json is List)
    for (final l in json)
      if (l is Map<String, dynamic> && l['article'] is Map)
        if (_texte((l['article'] as Map)['id'] ?? l['articleId']) != null &&
            _texte((l['article'] as Map)['libelle']) != null)
          ArticlePem(
            articleId: _texte((l['article'] as Map)['id'] ?? l['articleId'])!,
            libelle: _texte((l['article'] as Map)['libelle'])!,
            code: _texte((l['article'] as Map)['codeAs400']) ?? '',
            marque: (l['article'] as Map)['marque'] is Map
                ? _texte(((l['article'] as Map)['marque'] as Map)['nom']) ?? ''
                : '',
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
          debut: _jourDe(l['dateDebut']),
          fin: _jourDe(l['dateFin']),
        ),
];
