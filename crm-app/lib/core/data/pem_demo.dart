/// Visites PEM de démonstration : deux propositions pour le promoteur de la démo et la liste des articles à vérifier.
library;

import '../models/models.dart';
import 'produits_demo.dart';
import 'referentiels_visite.dart';

/// Propositions faites au promoteur de la démo : une à reporter ou accepter, une devenue obligatoire.
const List<PropositionPem> propositionsPemDemo = [
  PropositionPem(
    id: 'pem-d1',
    clientId: 'm5',
    clientNom: 'U Express – Paris',
    dateProposee: '2026-11-09',
    statut: StatutPem.proposee,
    nbReports: 1,
  ),
  PropositionPem(
    id: 'pem-d2',
    clientId: 'm4',
    clientNom: 'Carrefour – Ivry-sur-Seine',
    dateProposee: '2026-11-06',
    statut: StatutPem.proposee,
    nbReports: nbReportsAvantObligation,
    obligatoire: true,
  ),
];

/// Articles PEM actifs du catalogue de démonstration.
final List<ArticlePem> articlesPemDemo = [
  for (final p in produitsPem)
    if (p.actif == true)
      ArticlePem(articleId: p.id, libelle: p.nom, code: p.code),
];
