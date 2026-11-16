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

/// Seuil de la classe, 28 jours par défaut (maquette : `SEUIL_VISITE[classe] ?? 28`).
int seuilPourClasse(String classe) => seuilVisite[classe] ?? 28;

/// A++ < A+ < A < B … < G : le meilleur niveau d'abord (`classeRang`).
int classeRang(String c) {
  final plus = '+'.allMatches(c).length;
  return (c.codeUnitAt(0) - 65) * 10 - plus;
}
