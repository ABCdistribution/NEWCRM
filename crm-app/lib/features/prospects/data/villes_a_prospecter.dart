/// Villes d'exemple de l'onglet « Magasins » d'une fiche prospect.
///
/// Maquette : `VILLES_A_PROSPECTER` (l.1758), « liste d'exemple » de magasins de la même enseigne renvoyés par l'API qui
/// ne sont ni clients ni prospects.
library;

/// Ville et code postal d'un point de vente « À prospecter ».
typedef VilleAProspecter = ({String ville, String codePostal});

const List<VilleAProspecter> villesAProspecter = [
  (ville: 'Le Havre', codePostal: '76600'),
  (ville: 'Dieppe', codePostal: '76200'),
  (ville: 'Pont-Audemer', codePostal: '27500'),
  (ville: 'Saint-Lô', codePostal: '50000'),
  (ville: 'Bayeux', codePostal: '14400'),
  (ville: 'Fécamp', codePostal: '76400'),
];
