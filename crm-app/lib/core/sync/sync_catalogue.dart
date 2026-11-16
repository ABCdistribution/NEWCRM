import 'package:drift/drift.dart' show Value;

import '../api/api_client.dart';
import '../db/app_database.dart';
import 'pages_api.dart';

/// Télécharge le catalogue complet depuis le CRM (`GET /articles`, 100 par page) et le range dans la base locale.
///
/// Le catalogue est remplacé en bloc : tout ou rien, et un article supprimé côté serveur disparaît aussi du
/// téléphone. (La synchro par deltas viendra avec le filtre `modifieDepuis`, pas encore sur le serveur de dev.)
class SyncCatalogue {
  SyncCatalogue(this._api, this._base);

  final ApiLecture _api;
  final AppDatabase _base;

  static const taillePage = 100;

  /// Télécharge puis enregistre ; renvoie le nombre d'articles. Lève [ErreurApi] sans rien modifier en local.
  Future<int> telecharger({
    void Function(int recus, int total)? progression,
  }) async {
    final brutes = await lireToutesLesPages(
      _api,
      '/articles',
      taillePage: taillePage,
      progression: progression,
    );
    final lignes = <ArticlesLocauxCompanion>[];
    final vus = <String>{};
    for (final brut in brutes) {
      final ligne = articleDepuisJson(brut);
      if (ligne != null && vus.add(ligne.id.value)) lignes.add(ligne);
    }
    await _base.remplacerArticles(lignes);
    return lignes.length;
  }
}

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;
String? _nom(Object? v) => v is Map<String, dynamic> ? _texte(v['nom']) : null;

/// Ligne de la base à partir d'un article de l'API ; null si l'identifiant ou le libellé manque.
ArticlesLocauxCompanion? articleDepuisJson(Object? brut) {
  if (brut is! Map<String, dynamic>) return null;
  final id = brut['id'];
  final libelle = brut['libelle'];
  if (id is! String || libelle is! String) return null;
  return ArticlesLocauxCompanion.insert(
    id: id,
    codeAs400: _texte(brut['codeAs400']) ?? '',
    libelle: libelle.trim(),
    gencode: Value(_texte(brut['gencode'])),
    marque: Value(_nom(brut['marque'])),
    famille: Value(_nom(brut['famille'])),
    gamme: Value(_nom(brut['gamme'])),
    typeArticle: Value(_texte(brut['typeArticle'])),
    statut: Value(_texte(brut['statut'])),
    pcb: Value((brut['pcb'] as num?)?.toInt()),
    stock: Value((brut['stock'] as num?)?.toInt() ?? 0),
    actif: Value(brut['actif'] != false),
    prix: Value((brut['prixIndicatif'] as num?)?.toDouble()),
    enPromo: Value(brut['enPromo'] == true),
    promoLibelle: Value(_texte(brut['promoLibelle'])),
    misEnAvant: Value(brut['misEnAvant'] == true),
  );
}
