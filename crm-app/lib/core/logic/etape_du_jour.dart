/// Rattachement d'une visite à l'étape prévue du jour : la visite planifiée du CRM (ligne de planning du promoteur)
/// qu'elle solde à l'envoi.
library;

import '../envoi/corps_visite.dart' show estUuid;
import '../models/models.dart';

/// Identifiant de la visite planifiée du jour à laquelle rattacher une visite chez `magasinId`, ou null s'il n'y en a pas.
///
/// `tournee` : les visites planifiées d'aujourd'hui du promoteur (leur `id` est celui de la ligne de planning du CRM),
/// dans l'ordre du jour ; `lignes` : les lignes du planning, où se lit si une visite est déjà faite. Seule une étape du
/// CRM (identifiant UUID), chez ce magasin et pas encore faite compte. Si plusieurs conviennent, la première du jour
/// l'emporte.
String? planningIdDuJour({
  required Iterable<TourneeVisite> tournee,
  required Iterable<EtapePlanning> lignes,
  required String magasinId,
}) {
  final faites = {
    for (final l in lignes)
      if (l.fait) l.id,
  };
  for (final t in tournee) {
    if (t.magasinId == magasinId && estUuid(t.id) && !faites.contains(t.id)) {
      return t.id;
    }
  }
  return null;
}
