import 'dart:convert';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';

/// Proposition de visite PEM telle que la renvoie `GET /pem/propositions`.
Map<String, dynamic> propositionPem(
  String id, {
  String clientId = 'm5',
  String enseigne = 'U EXPRESS',
  String ville = 'PARIS',
  String dateProposee = '2026-11-09',
  String statut = 'PROPOSEE',
  int nbReports = 0,
  bool obligatoire = false,
  String? motifDernierReport,
}) => {
  'id': id,
  'client': {'id': clientId, 'enseigne': enseigne, 'ville': ville},
  'promoteur': {'id': 'u', 'displayName': 'Jean DUPONT'},
  'dateProposee': dateProposee,
  'statut': statut,
  'nbReports': nbReports,
  'obligatoire': obligatoire,
  'reportsRestants': obligatoire || nbReports >= 3 ? 0 : 3 - nbReports,
  'motifDernierReport': motifDernierReport,
  'planningId': null,
  'visiteId': null,
};

/// Ligne de `GET /pem/articles`.
Map<String, dynamic> articlePemApi(
  String id, {
  String? libelle,
  String code = '20015',
  String? marque = 'Titanium',
}) => {
  'id': 'l$id',
  'article': {
    'id': id,
    'codeAs400': code,
    'libelle': libelle ?? 'Article PEM $id',
    'gencode': null,
    'marque': marque == null ? null : {'nom': marque},
  },
};

Map<String, dynamic> _copie(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Serveur simulé pour `/pem` : propositions ouvertes, articles, acceptation et report avec les règles et les messages
/// de l'API (obligation au troisième report, fenêtres de dates).
class FauxServeurPem implements ApiLecture, ApiEcriture {
  FauxServeurPem({DateTime? aujourdhui})
    : aujourdhui = aujourdhui ?? DateTime(2026, 11, 4);

  final DateTime aujourdhui;
  final Map<String, Map<String, dynamic>> propositions = {};
  final List<Map<String, dynamic>> articles = [];
  final List<(String, String, Object?)> ecritures = [];
  final List<String> lectures = [];

  /// Erreur renvoyée par toutes les lectures tant qu'elle est posée.
  ErreurApi? erreurLecture;

  /// Erreur renvoyée par la prochaine écriture (puis remise à zéro).
  ErreurApi? erreurEcriture;

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    lectures.add(chemin);
    if (erreurLecture != null) throw erreurLecture!;
    if (chemin == '/pem/propositions') {
      final data = [
        for (final p in propositions.values)
          if (p['statut'] == 'PROPOSEE' || p['statut'] == 'ACCEPTEE') _copie(p),
      ];
      return {'data': data, 'total': data.length, 'page': 1, 'limit': 200};
    }
    if (chemin == '/pem/articles') return [for (final a in articles) _copie(a)];
    if (chemin == '/plannings') return <Object?>[];
    throw const ErreurApi(TypeErreurApi.inattendue, statut: 404);
  }

  ErreurApi _erreur(int statut, String message) =>
      ErreurApi.depuisReponse(statut, jsonEncode({'message': message}));

  bool _dansFenetre(Object? date, int dMin) {
    final d = date is String ? DateTime.tryParse(date) : null;
    if (d == null) return false;
    final min = DateTime(
      aujourdhui.year,
      aujourdhui.month,
      aujourdhui.day + dMin,
    );
    final max = DateTime(
      aujourdhui.year,
      aujourdhui.month,
      aujourdhui.day + 14,
    );
    return !d.isBefore(min) && !d.isAfter(max);
  }

  @override
  Future<Object?> envoyer(
    String methode,
    String chemin, {
    Object? corps,
  }) async {
    ecritures.add((methode, chemin, corps));
    final e = erreurEcriture;
    if (e != null) {
      erreurEcriture = null;
      throw e;
    }
    final parts = chemin.split('/');
    final p = propositions[parts[3]];
    if (p == null) throw _erreur(404, 'Proposition PEM introuvable');
    final c = (corps as Map?) ?? const {};
    if (parts.last == 'accepter') {
      if (c['date'] != null && !_dansFenetre(c['date'], 0)) {
        throw _erreur(
          400,
          'La date doit être comprise dans les 14 prochains jours',
        );
      }
      p['statut'] = 'ACCEPTEE';
      if (c['date'] != null) p['dateProposee'] = c['date'];
      p['planningId'] = 'plan-${p['id']}';
      return _copie(p);
    }
    if (parts.last == 'reporter') {
      if (p['obligatoire'] == true) {
        throw _erreur(
          409,
          'Cette visite PEM est obligatoire : elle ne peut plus être reportée',
        );
      }
      if (c['date'] != null && !_dansFenetre(c['date'], 1)) {
        throw _erreur(
          400,
          'La date de report doit être comprise entre demain et 14 jours',
        );
      }
      final n = (p['nbReports'] as int) + 1;
      p['nbReports'] = n;
      p['motifDernierReport'] = c['motif'];
      p['dateProposee'] =
          c['date'] ??
          _iso(DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day + 7));
      if (n >= 3) {
        p['obligatoire'] = true;
        p['statut'] = 'ACCEPTEE';
        p['reportsRestants'] = 0;
      } else {
        p['reportsRestants'] = 3 - n;
      }
      return _copie(p);
    }
    throw _erreur(404, 'Route inconnue');
  }
}
