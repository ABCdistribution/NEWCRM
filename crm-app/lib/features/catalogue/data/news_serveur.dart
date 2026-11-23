import '../../../core/logic/dates.dart';
import 'news_demo.dart';

/// Actualités réelles téléchargées du CRM (nul en démonstration : les news de la maquette servent alors).
List<News>? _newsServeur;

void definirNewsServeur(List<News>? news) => _newsServeur = news;

/// Actualités à afficher : celles du CRM, sinon celles de la démonstration (aucune en session réelle).
List<News> newsActuelles() =>
    _newsServeur ?? (DemoTemps.reel ? const <News>[] : newsDemo);

News? newsParIdActuelle(String id) {
  for (final n in newsActuelles()) {
    if (n.id == id) return n;
  }
  return null;
}

String _deuxChiffres(int n) => n.toString().padLeft(2, '0');

/// Texte brut d'un contenu : balises HTML retirées, une ligne par paragraphe.
List<String> paragraphes(String contenu) {
  final brut = contenu
      .replaceAll(
        RegExp(r'<\s*br\s*/?>|</\s*(p|div|li|h\d)\s*>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"');
  return [
    for (final l in brut.split(RegExp(r'\r?\n')))
      if (l.trim().isNotEmpty) l.trim(),
  ];
}

/// News de l'app à partir d'une news de l'API (`GET /news`) ; null si elle n'est pas publiée ou sans titre.
News? newsDepuisJson(Map<String, dynamic> j) {
  final id = j['id'];
  final titre = j['titre'];
  if (id is! String || titre is! String || titre.trim().isEmpty) return null;
  if (j['publiee'] == false) return null;
  final quand = DateTime.tryParse(
    '${j['publieeAt'] ?? j['createdAt'] ?? ''}',
  )?.toLocal();
  final contenu = j['contenu'];
  return News(
    id: id,
    titre: titre.trim(),
    date: quand == null
        ? ''
        : '${_deuxChiffres(quand.day)}/${_deuxChiffres(quand.month)}/${quand.year}',
    texte: contenu is String ? paragraphes(contenu) : const [],
  );
}
