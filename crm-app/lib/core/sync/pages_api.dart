import '../api/api_client.dart';
import '../api/erreur_api.dart';

/// Lit toutes les pages d'une liste de l'API (`{data, total}`, ou `{items, total}` avec [cleListe]), 100 par page, et renvoie les lignes brutes.
///
/// Lève [ErreurApi] si une réponse n'a pas la forme attendue. [progression] reçoit (lignes lues, total annoncé).
Future<List<Object?>> lireToutesLesPages(
  ApiLecture api,
  String chemin, {
  Map<String, String> query = const {},
  int taillePage = 100,
  int pagesMax = 5000,
  int? maxLignes,
  String cleListe = 'data',
  String cleTaille = 'limit',
  void Function(int recus, int total)? progression,
}) async {
  final lignes = <Object?>[];
  var total = 0;
  for (var page = 1; page <= pagesMax; page++) {
    final reponse = await api.get(
      chemin,
      query: {...query, 'page': '$page', cleTaille: '$taillePage'},
    );
    if (reponse is! Map<String, dynamic> || reponse[cleListe] is! List) {
      throw const ErreurApi(TypeErreurApi.inattendue);
    }
    final data = reponse[cleListe] as List;
    total = (reponse['total'] as num?)?.toInt() ?? total;
    lignes.addAll(data);
    // Avec un plafond, la progression se mesure sur ce qu'on va réellement lire.
    final attendu = maxLignes == null || total < maxLignes ? total : maxLignes;
    progression?.call(lignes.length, attendu);
    if (data.length < taillePage || lignes.length >= attendu) break;
  }
  return maxLignes != null && lignes.length > maxLignes
      ? lignes.sublist(0, maxLignes)
      : lignes;
}
