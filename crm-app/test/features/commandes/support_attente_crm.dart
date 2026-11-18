import 'dart:convert';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';

/// Détail d'une commande en attente tel que le renvoie `GET /commandes/apk/:id`.
Map<String, dynamic> detailAttente(
  String id, {
  String clientId = 'm8',
  String enseigne = 'U EXPRESS',
  String ville = 'BOULOGNE',
  String? clientEmail = 'magasin@exemple.fr',
  String date = '2026-11-10T09:30:00.000Z',
  String? commentaire,
  String? nePasLivrerAvant,
  String? motifNePasLivrerAvant,
  String? emailValidation,
  String? emailEnvoyeLe,
  String statut = 'EN_ATTENTE',
  List<Map<String, dynamic>>? lignes,
}) {
  final l =
      lignes ??
      [
        ligneAttente('a2', 12, prix: 22.62),
        ligneAttente('a9', 24, prix: '16.28'),
      ];
  return {
    'id': id,
    'idCommandeApk': 'APK$id',
    'dateCommande': date,
    'commentaire': commentaire,
    'nePasLivrerAvant': nePasLivrerAvant,
    'motifNePasLivrerAvant': motifNePasLivrerAvant,
    'statut': statut,
    'emailValidation': emailValidation,
    'emailEnvoyeLe': emailEnvoyeLe,
    'valideeLe': null,
    'client': {
      'id': clientId,
      'codeAs400': 'K1',
      'enseigne': enseigne,
      'ville': ville,
      'email': clientEmail,
    },
    'promoteur': {'id': 'u', 'displayName': 'Jean DUPONT'},
    'integree': false,
    'lignes': l,
    'totalIndicatif': l.fold<double>(
      0,
      (t, x) =>
          t +
          (x['quantite'] as int) *
              (double.tryParse('${x['prixIndicatif']}') ?? 0),
    ),
  };
}

Map<String, dynamic> ligneAttente(String articleId, int qte, {Object? prix}) =>
    {
      'ordre': 1,
      'quantite': qte,
      'prixIndicatif': prix,
      'article': {
        'id': articleId,
        'codeAs400': 'C$articleId',
        'libelle': 'Article $articleId',
        'gencode': null,
        'pcb': 6,
      },
    };

Map<String, dynamic> _copie(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

/// Serveur simulé pour `/commandes/apk` : lecture (liste, détail) et écritures, avec les erreurs de l'API.
class FauxServeurCommandes implements ApiLecture, ApiEcriture {
  final Map<String, Map<String, dynamic>> commandes = {};
  final List<(String, String, Object?)> ecritures = [];
  final List<String> lectures = [];

  /// Erreur renvoyée par la prochaine écriture (puis remise à zéro).
  ErreurApi? erreurEcriture;

  /// Erreur renvoyée par toutes les lectures tant qu'elle est posée.
  ErreurApi? erreurLecture;
  int _suivant = 1;

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    lectures.add(chemin);
    if (erreurLecture != null) throw erreurLecture!;
    if (chemin == '/commandes/apk') {
      final data = [
        for (final c in commandes.values)
          if (c['statut'] == query?['statut']) c,
      ];
      return {'data': data, 'total': data.length, 'page': 1, 'limit': 100};
    }
    final id = chemin.split('/').last;
    final c = commandes[id];
    if (c == null) throw const ErreurApi(TypeErreurApi.inattendue, statut: 404);
    return _copie(c);
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
    if (methode == 'POST' && chemin == '/commandes/apk') {
      final c = corps as Map<String, Object?>;
      for (final x in commandes.values) {
        if (x['idCommandeApk'] == c['idCommandeApk']) {
          return {'id': x['id'], 'dejaSynchronisee': true};
        }
      }
      final id = 'cmd-${_suivant++}';
      commandes[id] = detailAttente(
        id,
        clientId: c['clientId'] as String,
        commentaire: c['commentaire'] as String?,
        nePasLivrerAvant: c['nePasLivrerAvant'] as String?,
        motifNePasLivrerAvant: c['motifNePasLivrerAvant'] as String?,
        lignes: [
          for (final l in (c['lignes'] as List).cast<Map<String, Object?>>())
            ligneAttente(
              l['articleId'] as String,
              l['quantite'] as int,
              prix: l['prixIndicatif'],
            ),
        ],
      )..['idCommandeApk'] = c['idCommandeApk'];
      return {
        'id': id,
        'idCommandeApk': c['idCommandeApk'],
        'statut': 'EN_ATTENTE',
        'dejaSynchronisee': false,
      };
    }
    final id = parts[3];
    final c = commandes[id]!;
    if (methode == 'DELETE') {
      commandes.remove(id);
      return {'id': id, 'supprimee': true};
    }
    if (methode == 'PATCH') {
      final m = corps as Map<String, Object?>;
      if (m.containsKey('commentaire')) c['commentaire'] = m['commentaire'];
      // `nePasLivrerAvant: null` efface la date et le motif ; le motif seul ne change que le motif.
      if (m.containsKey('nePasLivrerAvant')) {
        c['nePasLivrerAvant'] = m['nePasLivrerAvant'];
        if (m['nePasLivrerAvant'] == null) c['motifNePasLivrerAvant'] = null;
      }
      if (m['motifNePasLivrerAvant'] != null) {
        c['motifNePasLivrerAvant'] = m['motifNePasLivrerAvant'];
      }
      if (m['lignes'] != null) {
        c['lignes'] = [
          for (final l in (m['lignes'] as List).cast<Map<String, Object?>>())
            ligneAttente(
              l['articleId'] as String,
              l['quantite'] as int,
              prix: l['prixIndicatif'],
            ),
        ];
      }
      return _copie(c);
    }
    if (chemin.endsWith('/valider')) {
      c['statut'] = 'VALIDEE';
      return _copie(c);
    }
    if (chemin.endsWith('/envoyer-mail')) {
      c['emailValidation'] = (corps as Map)['email'];
      c['emailEnvoyeLe'] = '2026-11-11T10:00:00.000Z';
      return _copie(c);
    }
    return null;
  }
}
