/// News du siège de la démo : maquette `NEWS` l.1042-1047 (titre, début du texte, date de publication ; pas de nom d'auteur).
library;

/// Une information du siège.
class News {
  const News({
    required this.id,
    required this.titre,
    required this.date,
    required this.texte,
  });

  /// Identifiant (« n1 » à « n4 »).
  final String id;
  final String titre;

  /// Date de publication, au format de la maquette (« 26/05/2026 »).
  final String date;

  /// Paragraphes du texte (le dernier est tronqué par « … », comme dans la liste fournie).
  final List<String> texte;
}

/// Les quatre news de la démo (`NEWS`).
const List<News> newsDemo = [
  News(
    id: 'n1',
    titre: 'Nouveautés HQ Mai',
    date: '26/05/2026',
    texte: [
      'Bonjour à tous,',
      'Je vous informe que les 3 nouveautés HQ suivantes sont disponibles :',
      '- Mas…',
    ],
  ),
  News(
    id: 'n2',
    titre: "JLD MANUCURE - RUPTURE PAE JUSQU'A FIN MAI 2026",
    date: '06/05/2026',
    texte: [
      'Rupture sur les nouvelles références PAE JLD',
      '- Anciennes références à commander : 21244212…',
    ],
  ),
  News(
    id: 'n3',
    titre: 'CRAVATE BUCCODENTAIRE APOTEKE DISPONIBLE',
    date: '11/03/2026',
    texte: [
      'Bonjour à tous,',
      "L'ensemble des références buccodentaire APOTEKE est de nouveau disponible (grat…",
    ],
  ),
  News(
    id: 'n4',
    titre: 'LES MASQUES COREENS ET LA CRAVATE HQ SONT DE NOUVEAU EN STOCK !',
    date: '10/03/2026',
    texte: [
      'Bonjour à tous,',
      'Le masque Collagène HQ Made in Corée est de nouveau en stock ainsi que la crava…',
    ],
  ),
];

/// Retrouve une news par son identifiant (`NEWS.find`), nulle si elle n'existe pas.
News? newsParId(String id) {
  for (final n in newsDemo) {
    if (n.id == id) return n;
  }
  return null;
}
