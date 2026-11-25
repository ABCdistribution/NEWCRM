/// Classification des clients : fréquence de visite attendue et rang de tri.
library;

/// Fréquence de visite attendue, en jours, selon la classe (`SEUIL_VISITE`).
const Map<String, int> seuilVisite = {
  'A++': 7,
  'A+': 10,
  'A': 14,
  'B': 21,
  'C': 28,
  'D': 35,
  'E': 42,
  'F': 56,
  'G': 70,
};

final RegExp _classeConnue = RegExp(r'^(A\+\+|A\+|[A-G])$');

/// Classe affichable d'un client : « A » à « G » (et « A+ », « A++ » de la démonstration), en majuscule ; vide si
/// le CRM n'en donne pas (nul, « — », texte libre). Aucune pastille n'est affichée pour une classe vide.
String classeValide(String? brut) {
  final c = brut?.trim().toUpperCase() ?? '';
  return _classeConnue.hasMatch(c) ? c : '';
}

/// « Carrefour – Rouen · Classe B », ou le nom seul si la classe est inconnue (titres en texte brut).
String nomEtClasse(String nom, String? classe) {
  final c = classeValide(classe);
  return c.isEmpty ? nom : '$nom · Classe $c';
}

/// Seuil de la classe, 28 jours par défaut (maquette : `SEUIL_VISITE[classe] ?? 28`).
int seuilPourClasse(String classe) => seuilVisite[classe] ?? 28;

/// A++ < A+ < A < B … < G : le meilleur niveau d'abord (`classeRang`).
int classeRang(String c) {
  if (c.isEmpty) return 990; // sans classe : après la classe G
  final plus = '+'.allMatches(c).length;
  return (c.codeUnitAt(0) - 65) * 10 - plus;
}
