import 'dart:convert';

import '../api/api_client.dart';
import '../db/app_database.dart';
import 'pages_api.dart';

/// Télécharge un jeu de données secondaire (commandes, visites, prospects…) et le range tel quel dans la base locale.
///
/// Une liste paginée de l'API (`{data, total}`) est lue en entier ; remplacement en bloc, tout ou rien.
class SyncDomaine {
  SyncDomaine(this._api, this._base, this.domaine);

  final ApiLecture _api;
  final AppDatabase _base;
  final String domaine;

  /// Liste paginée de l'API.
  Future<int> telecharger(
    String chemin, {
    Map<String, String> query = const {},
    String cleListe = 'data',
    String cleTaille = 'limit',
    int? maxLignes,
    void Function(int recus, int total)? progression,
  }) async {
    final brutes = await lireToutesLesPages(
      _api,
      chemin,
      query: query,
      cleListe: cleListe,
      cleTaille: cleTaille,
      maxLignes: maxLignes,
      progression: progression,
    );
    return enregistrer(brutes);
  }

  /// Range des lignes déjà lues ; les lignes sans identifiant texte sont ignorées, les doublons aussi.
  Future<int> enregistrer(List<Object?> brutes) async {
    final vus = <String>{};
    final lignes = <({String id, String json})>[];
    for (final brut in brutes) {
      if (brut is! Map<String, dynamic>) continue;
      final id = brut['id'];
      if (id is String && vus.add(id)) {
        lignes.add((id: id, json: jsonEncode(brut)));
      }
    }
    await _base.remplacerEnregistrements(domaine, lignes);
    return lignes.length;
  }
}

/// Lignes JSON d'un domaine décodées ; les lignes illisibles sont ignorées.
List<Map<String, dynamic>> lignesDecodees(List<String> brutes) {
  final lignes = <Map<String, dynamic>>[];
  for (final b in brutes) {
    try {
      final j = jsonDecode(b);
      if (j is Map<String, dynamic>) lignes.add(j);
    } catch (_) {}
  }
  return lignes;
}
