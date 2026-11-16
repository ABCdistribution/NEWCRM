/// Alerte de la cloche : maquette `alertes()`, `alertesProspects()`.
library;

/// Niveau d'urgence : « haut » = fond rouge pâle, « moy » = fond bleu pâle.
enum NiveauAlerte { haut, moy }

class Alerte {
  const Alerte({
    required this.niveau,
    required this.icone,
    required this.titre,
    required this.classe,
    required this.detail,
    required this.rang,
    this.magasinId,
    this.prospectId,
  });

  final NiveauAlerte niveau;

  /// Alerte client : id du magasin (ouvre sa fiche).
  final String? magasinId;

  /// Alerte prospect : id du prospect (ouvre sa fiche).
  final String? prospectId;

  /// Emoji (📍 visite en retard, 🚚 livraison, 💤 inactif, 📅 RDV, 💬 relance, 🎯 à contacter).
  final String icone;
  final String titre;
  final String classe;
  final String detail;

  /// Ordre de tri : plus petit = plus urgent.
  final int rang;

  bool get estProspect => prospectId != null;
}
