/// Présentation d'une ligne de planning : couleurs et libellé de pastille (maquette : `couleur(e)` de `pageTournee`).
library;

import '../models/models.dart';

/// Couleurs (ARGB) et libellé d'une carte de planning.
class StyleEtape {
  const StyleEtape(this.fond, this.texte, this.libelle);
  final int fond;
  final int texte;
  final String libelle;
}

/// Style d'une ligne : « Fait ✓ » vert, ADM gris, Libre gris clair, Prospect bleu (jaune « Négo »
/// si le prospect est en négociation), Client violet pâle.
///
/// `masquerFait` : pendant la saisie de la prévision, les lignes faites ne sont pas grisées en vert.
StyleEtape styleEtapePlanning(
  EtapePlanning e, {
  Prospect? prospect,
  bool masquerFait = false,
}) {
  if (e.fait && !masquerFait) {
    return const StyleEtape(0xFFDDF5E6, 0xFF166534, 'Fait ✓');
  }
  switch (e.cible) {
    case CiblePlanning.adm:
      return const StyleEtape(0xFFEDEFF3, 0xFF374151, 'ADM');
    case CiblePlanning.libre:
      return const StyleEtape(0xFFEFEFEF, 0xFF374151, 'Libre');
    case CiblePlanning.prospect:
      if (prospect != null && prospect.groupe == GroupeProspect.enNego) {
        return const StyleEtape(0xFFFCEFC6, 0xFF92400E, 'Négo');
      }
      return const StyleEtape(0xFFDFE8FF, 0xFF1E3A8A, 'Prospect');
    case CiblePlanning.client:
      return const StyleEtape(0xFFEBE5FF, 0xFF5B21B6, 'Client');
  }
}

/// Lignes d'un jour donné, triées par heure (maquette : `lignesDe`).
/// `sem` filtre sur le décalage de semaine (planning d'un promoteur ouvert par son encadrement).
List<EtapePlanning> lignesDuJour(
  List<EtapePlanning> etapes,
  int jour, {
  int? sem,
}) {
  final l = etapes
      .where((e) => e.jour == jour && (sem == null || (e.sem ?? 0) == sem))
      .toList();
  l.sort((a, b) => a.heure.compareTo(b.heure));
  return l;
}
