/// Visites PEM : propositions du CRM (une toutes les 4 semaines par magasin suivi), que le promoteur accepte ou reporte.
library;

/// État d'une proposition de visite PEM (`statut` du CRM).
enum StatutPem {
  proposee,
  acceptee,
  realisee,
  annulee;

  static StatutPem? depuisCode(Object? code) => switch (code) {
    'PROPOSEE' => proposee,
    'ACCEPTEE' => acceptee,
    'REALISEE' => realisee,
    'ANNULEE' => annulee,
    _ => null,
  };
}

/// Nombre de reports successifs après lequel la visite devient obligatoire.
const int nbReportsAvantObligation = 3;

/// Une proposition de visite PEM faite au promoteur responsable d'un magasin.
class PropositionPem {
  const PropositionPem({
    required this.id,
    required this.clientId,
    required this.clientNom,
    required this.dateProposee,
    required this.statut,
    this.nbReports = 0,
    this.obligatoire = false,
    int? reportsRestants,
    this.motifDernierReport,
    this.planningId,
    this.visiteId,
    this.clientClasse = '',
  }) : reportsRestants =
           reportsRestants ??
           (nbReports >= nbReportsAvantObligation
               ? 0
               : nbReportsAvantObligation - nbReports);

  final String id;
  final String clientId;

  /// « Enseigne – Ville » d'après le CRM, quand le client n'est pas dans le portefeuille local.
  final String clientNom;

  /// Classe du client d'après le CRM (« A » à « G »), vide si inconnue.
  final String clientClasse;

  /// Date proposée, `aaaa-mm-jj`.
  final String dateProposee;
  final StatutPem statut;
  final int nbReports;
  final bool obligatoire;

  /// Reports encore possibles avant que la visite devienne obligatoire (jamais négatif).
  final int reportsRestants;
  final String? motifDernierReport;

  /// Ligne du planning créée par le CRM à l'acceptation.
  final String? planningId;

  /// Visite réalisée en réponse à la proposition, une fois faite.
  final String? visiteId;

  /// Proposition encore à traiter : à accepter ou à faire.
  bool get ouverte =>
      statut == StatutPem.proposee || statut == StatutPem.acceptee;

  /// Le promoteur peut encore la reporter : proposée, non obligatoire, avec au moins un report restant.
  bool get reportable =>
      statut == StatutPem.proposee && !obligatoire && reportsRestants > 0;

  PropositionPem copyWith({
    String? dateProposee,
    StatutPem? statut,
    int? nbReports,
    bool? obligatoire,
    int? reportsRestants,
    String? motifDernierReport,
  }) => PropositionPem(
    id: id,
    clientId: clientId,
    clientNom: clientNom,
    dateProposee: dateProposee ?? this.dateProposee,
    statut: statut ?? this.statut,
    nbReports: nbReports ?? this.nbReports,
    obligatoire: obligatoire ?? this.obligatoire,
    reportsRestants: reportsRestants ?? this.reportsRestants,
    motifDernierReport: motifDernierReport ?? this.motifDernierReport,
    planningId: planningId,
    visiteId: visiteId,
    clientClasse: clientClasse,
  );
}
