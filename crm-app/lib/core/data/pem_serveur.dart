import '../logic/classes.dart';
import '../models/models.dart';

/// Propositions de visite PEM téléchargées du CRM (nul en démonstration : les propositions fictives servent alors).
List<PropositionPem>? _propositions;

void definirPropositionsPemServeur(List<PropositionPem>? liste) =>
    _propositions = liste;

List<PropositionPem>? propositionsPemServeur() => _propositions;

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Proposition de l'app à partir d'une proposition de l'API (`GET /pem/propositions`) ; nulle sans identifiant, sans
/// client, sans statut connu ou sans date proposée lisible.
PropositionPem? propositionPemDepuisJson(Map<String, dynamic> j) {
  final id = _texte(j['id']);
  final client = j['client'] is Map ? j['client'] as Map : const {};
  final clientId = _texte(client['id']);
  final statut = StatutPem.depuisCode(j['statut']);
  final date = j['dateProposee'] is String
      ? RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(j['dateProposee'] as String)
      : null;
  if (id == null || clientId == null || statut == null || date == null) {
    return null;
  }
  final enseigne = _texte(client['enseigne']) ?? '';
  final ville = _texte(client['ville']) ?? '';
  final nb = j['nbReports'] is num ? (j['nbReports'] as num).toInt() : 0;
  final restants = j['reportsRestants'] is num
      ? (j['reportsRestants'] as num).toInt()
      : null;
  return PropositionPem(
    id: id,
    clientId: clientId,
    clientNom: ville.isEmpty ? enseigne : '$enseigne – $ville',
    dateProposee: date.group(0)!,
    statut: statut,
    nbReports: nb < 0 ? 0 : nb,
    obligatoire: j['obligatoire'] == true,
    reportsRestants: restants == null ? null : (restants < 0 ? 0 : restants),
    motifDernierReport: _texte(j['motifDernierReport']),
    planningId: _texte(j['planningId']),
    visiteId: _texte(j['visiteId']),
    clientClasse: classeValide(_texte(client['niveauClass'])),
  );
}
