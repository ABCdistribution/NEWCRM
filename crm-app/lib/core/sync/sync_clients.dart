import 'package:drift/drift.dart' show Value;

import '../api/api_client.dart';
import '../db/app_database.dart';
import 'pages_api.dart';

/// Télécharge les clients actifs du périmètre de l'utilisateur (`GET /clients?mes=1`, 100 par page) dans la base locale.
///
/// `mes=1` demande le périmètre du rôle : le promoteur reçoit ses clients, le chef de secteur ceux de ses promoteurs,
/// le directeur régional sa région. Les clients inactifs ne sont pas téléchargés. Remplacement en bloc, tout ou rien.
class SyncClients {
  SyncClients(this._api, this._base);

  final ApiLecture _api;
  final AppDatabase _base;

  Future<int> telecharger({
    void Function(int recus, int total)? progression,
  }) async {
    final brutes = await lireToutesLesPages(
      _api,
      '/clients',
      query: const {'mes': '1', 'actif': 'true'},
      progression: progression,
    );
    final lignes = <ClientsLocauxCompanion>[];
    final vus = <String>{};
    for (final brut in brutes) {
      final ligne = clientDepuisJson(brut);
      // Garde-fou : un client inactif renvoyé par un ancien serveur ne va pas dans la base.
      if (ligne != null && ligne.actif.value && vus.add(ligne.id.value)) {
        lignes.add(ligne);
      }
    }
    await _base.remplacerClients(lignes);
    return lignes.length;
  }
}

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Ligne de la base à partir d'un client de l'API ; null si l'identifiant ou l'enseigne manque.
ClientsLocauxCompanion? clientDepuisJson(Object? brut) {
  if (brut is! Map<String, dynamic>) return null;
  final id = brut['id'];
  final enseigne = _texte(brut['enseigne']);
  if (id is! String || enseigne == null) return null;
  final classe = _texte(brut['niveauClass'])?.toUpperCase();
  return ClientsLocauxCompanion.insert(
    id: id,
    codeAs400: _texte(brut['codeAs400']) ?? '',
    enseigne: enseigne,
    raisonSociale: _texte(brut['raisonSociale']) ?? enseigne,
    adresse1: Value(_texte(brut['adresse1'])),
    codePostal: Value(_texte(brut['codePostal'])),
    ville: Value(_texte(brut['ville'])),
    telephone: Value(_texte(brut['tel1'])),
    contact: Value(_texte(brut['contact1'])),
    actif: Value(brut['actif'] != false),
    niveauClass: Value(
      classe != null && RegExp(r'^[A-G]$').hasMatch(classe) ? classe : null,
    ),
  );
}
