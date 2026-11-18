/// Rapports de semaine de la démo : maquette `S.rapports` (l.487-492), semaines 44 à 41.
library;

import '../../../core/logic/logic.dart';

/// Un rapport hebdomadaire validé automatiquement (`{ n, p, v, pct, rdv, prevues, pied, auto, ecarts }`).
class RapportSemaine {
  const RapportSemaine({
    required this.numero,
    required this.periode,
    required this.visites,
    required this.pct,
    required this.rdv,
    required this.prevues,
    required this.pied,
    required this.ecarts,
    this.auto = true,
    this.valide = true,
    this.ecartsConnus = true,
    this.lundi,
  });

  /// Numéro de la semaine (45 = en cours, 44 à 41 = validées).
  final int numero;

  /// « 26 – 30 octobre ».
  final String periode;

  /// Visites réalisées (`v`).
  final int visites;

  /// Part de la prévision réalisée, nulle sans prévision.
  final int? pct;

  /// RDV obtenus.
  final int rdv;

  /// Lignes de la prévision, nul sans prévision.
  final int? prevues;

  /// « Validé automatiquement le lun. 2 nov. à 04:00 ».
  final String pied;

  /// Écarts avec la prévision : un titre et un détail par ligne (aucune date, le détail est la note).
  final List<EcartPlanning> ecarts;

  /// Validé automatiquement (pastille grise « Validé auto ») ou à la main (pastille verte « Validé »).
  final bool auto;

  /// Faux pour une semaine passée dont le rapport n'a pas été validé (rapport réel seulement).
  final bool valide;

  /// Faux quand la liste des écarts n'est pas connue sans ouvrir le détail (rapport réel : elle est chargée à l'ouverture).
  final bool ecartsConnus;

  /// Lundi de la semaine, « yyyy-mm-dd » (rapport réel seulement).
  final String? lundi;
}

/// Rapports précédents, du plus récent au plus ancien (`S.rapports`).
final List<RapportSemaine> rapportsDemo = [
  RapportSemaine(
    numero: 44,
    periode: '26 – 30 octobre',
    visites: 14,
    pct: 93,
    rdv: 4,
    prevues: 15,
    pied: 'Validé automatiquement le lun. 2 nov. à 04:00',
    ecarts: [
      EcartPlanning.resume(
        GenreEcart.ajoute,
        'Auchan – Rouen',
        'visite non prévue',
      ),
      EcartPlanning.resume(GenreEcart.retire, 'Monoprix – Caen', 'prévu mardi'),
    ],
  ),
  RapportSemaine(
    numero: 43,
    periode: '19 – 23 octobre',
    visites: 12,
    pct: 86,
    rdv: 2,
    prevues: 14,
    pied: 'Validé automatiquement le lun. 26 oct. à 04:00',
    ecarts: [
      EcartPlanning.resume(
        GenreEcart.retire,
        'Carrefour – Ivry-sur-Seine',
        'prévu lundi',
      ),
      EcartPlanning.resume(
        GenreEcart.retire,
        'U Express – Paris',
        'prévu jeudi',
      ),
      EcartPlanning.resume(
        GenreEcart.deplace,
        'Carrefour Market – Rouen',
        'prévu mardi, réalisé jeudi',
      ),
    ],
  ),
  const RapportSemaine(
    numero: 42,
    periode: '12 – 16 octobre',
    visites: 15,
    pct: 100,
    rdv: 3,
    prevues: 15,
    pied: 'Validé automatiquement le lun. 19 oct. à 04:00',
    ecarts: [],
  ),
  RapportSemaine(
    numero: 41,
    periode: '5 – 9 octobre',
    visites: 11,
    pct: 85,
    rdv: 1,
    prevues: 13,
    pied: 'Validé automatiquement le lun. 12 oct. à 04:00',
    ecarts: [
      EcartPlanning.resume(
        GenreEcart.non,
        'Carrefour Market – Versailles',
        'prévu vendredi',
      ),
      EcartPlanning.resume(
        GenreEcart.non,
        'Carrefour – Rouen',
        'prévu vendredi',
      ),
    ],
  ),
];
