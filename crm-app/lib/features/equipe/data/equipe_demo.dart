/// Données propres au lot « équipe », portées de la maquette : `EQUIPE_CS` détaillé (prévision `prev`, rapport `rap`,
/// semaine `s44`, l.751-762), `SEM44_N` et `compareSemaine` (l.787-801), `semainesCS` (l.802-815) et `FILTRES_SEM` (l.836-840).
///
/// L'identité des chefs de secteur et des promoteurs (noyau partagé) reste dans `core/data`.
library;

import '../../../core/logic/logic.dart';

/// Une ligne de prévision ou de réalisé : `['Mar', '09:00', 'Carrefour – Rouen']`.
class LignePrevision {
  const LignePrevision(this.jour, this.heure, this.titre);

  /// Jour court : « Lun », « Mar »…
  final String jour;
  final String heure;
  final String titre;

  /// « Mar 09:00 ».
  String get quand => '$jour $heure';
}

/// Prévision enregistrée le lundi par un chef de secteur (`prev`).
class PrevisionEnregistree {
  const PrevisionEnregistree(this.at, this.lignes);

  /// « lun. 2 nov. à 08:40 ».
  final String at;
  final List<LignePrevision> lignes;
}

/// Rapport d'activité de la semaine en cours (`rap`) : prévu, réalisé à ce jour, écarts.
class RapportEnCours {
  const RapportEnCours({
    required this.pct,
    required this.prevues,
    required this.realisees,
    required this.ecarts,
  });

  final int pct;
  final int prevues;
  final int realisees;
  final List<EcartPlanning> ecarts;
}

/// Semaine 44, validée automatiquement (`s44`) ; `pct` et `prevues` sont nuls sans prévision.
class Semaine44 {
  const Semaine44({
    this.pct,
    this.prevues,
    required this.v,
    required this.ecarts,
    this.note,
  });

  final int? pct;
  final int? prevues;

  /// Visites réalisées.
  final int v;
  final List<EcartPlanning> ecarts;

  /// Explication quand la prévision n'était pas renseignée.
  final String? note;
}

/// Détail d'un chef de secteur (`EQUIPE_CS`, hors identité qui est dans `chefsSecteurDemo`).
class DetailChefSecteur {
  const DetailChefSecteur({
    required this.id,
    this.prev,
    this.rap,
    required this.s44,
  });

  final String id;
  final PrevisionEnregistree? prev;
  final RapportEnCours? rap;
  final Semaine44 s44;
}

EcartPlanning _ecart(GenreEcart genre, String titre, String detail) =>
    EcartPlanning.resume(genre, titre, detail);

/// Prévision, rapport en cours et semaine 44 des trois chefs de secteur de la démo.
final List<DetailChefSecteur> detailsChefsSecteur = [
  DetailChefSecteur(
    id: 'n',
    prev: const PrevisionEnregistree('lun. 2 nov. à 08:40', [
      LignePrevision('Mar', '09:00', 'Carrefour – Rouen'),
      LignePrevision('Mar', '11:30', 'Carrefour – Paris'),
      LignePrevision('Mer', '10:00', 'Super U – Versailles'),
      LignePrevision('Jeu', '14:00', 'Carrefour Market – Rouen'),
      LignePrevision('Ven', '09:30', 'Carrefour – Ivry-sur-Seine'),
    ]),
    rap: RapportEnCours(
      pct: 60,
      prevues: 5,
      realisees: 3,
      ecarts: [
        _ecart(GenreEcart.ajoute, 'Auchan – Rouen', 'visite non prévue'),
        _ecart(
          GenreEcart.retire,
          'Carrefour Market – Rouen',
          'prévu jeu. 14:00',
        ),
      ],
    ),
    s44: Semaine44(
      pct: 93,
      prevues: 15,
      v: 14,
      ecarts: [
        _ecart(GenreEcart.ajoute, 'Auchan – Rouen', 'visite non prévue'),
        _ecart(GenreEcart.retire, 'Monoprix – Caen', 'prévu mardi'),
      ],
    ),
  ),
  DetailChefSecteur(
    id: 'k',
    prev: const PrevisionEnregistree('lun. 2 nov. à 09:15', [
      LignePrevision('Mar', '10:00', 'Super U – Amiens'),
      LignePrevision('Mer', '14:00', 'Carrefour – Rouen'),
      LignePrevision('Jeu', '09:30', 'Monoprix – Caen'),
      LignePrevision('Ven', '11:00', 'Carrefour – Versailles'),
    ]),
    rap: const RapportEnCours(pct: 75, prevues: 4, realisees: 3, ecarts: []),
    s44: const Semaine44(pct: 100, prevues: 12, v: 12, ecarts: []),
  ),
  const DetailChefSecteur(
    id: 's',
    s44: Semaine44(
      v: 9,
      ecarts: [],
      note: 'Prévision non renseignée cette semaine-là : pas de comparaison.',
    ),
  ),
];

/// Détail d'un chef de secteur par id (« n », « k » ou « s »).
DetailChefSecteur detailChefSecteur(String id) =>
    detailsChefsSecteur.firstWhere((d) => d.id == id);

/// Prévision de la semaine 44 de Nadia H. (`SEM44_N.prevision`).
const List<LignePrevision> prevision44Nadia = [
  LignePrevision('Lun', '09:30', 'Carrefour – Rouen'),
  LignePrevision('Mar', '10:00', 'Super U – Versailles'),
  LignePrevision('Mar', '14:30', 'Carrefour – Paris'),
  LignePrevision('Mer', '11:00', 'Monoprix – Caen'),
  LignePrevision('Jeu', '09:00', 'E.Leclerc – Paris'),
  LignePrevision('Ven', '10:00', 'Carrefour – Ivry-sur-Seine'),
];

/// Réalisé de la semaine 44 de Nadia H. (`SEM44_N.realise`).
const List<LignePrevision> realise44Nadia = [
  LignePrevision('Lun', '09:30', 'Carrefour – Rouen'),
  LignePrevision('Mar', '10:00', 'Super U – Versailles'),
  LignePrevision('Mer', '15:00', 'Carrefour – Paris'),
  LignePrevision('Jeu', '09:00', 'E.Leclerc – Paris'),
  LignePrevision('Jeu', '14:00', 'Auchan – Rouen'),
  LignePrevision('Ven', '10:00', 'Carrefour – Ivry-sur-Seine'),
];

/// Sort d'une ligne comparée à la prévision (`k` de `compareSemaine`).
enum GenreComparaison { fait, deplace, ajoute, retire }

/// Une ligne du réalisé (`l`) comparée à la ligne prévue (`p`, nulle si non prévue).
class LigneComparee {
  const LigneComparee(this.genre, this.reel, [this.prevu]);

  final GenreComparaison genre;
  final LignePrevision reel;
  final LignePrevision? prevu;
}

/// Résultat de `compareSemaine` : le réalisé ligne à ligne, puis le prévu non réalisé.
class ComparaisonSemaine {
  const ComparaisonSemaine(this.lignes, this.manquees);

  final List<LigneComparee> lignes;
  final List<LigneComparee> manquees;
}

/// Compare ce qui était prévu et ce qui s'est passé : réalisé comme prévu, déplacé, ajouté, ou prévu mais pas fait.
/// Les lignes sont rapprochées par leur titre (`compareSemaine`).
ComparaisonSemaine compareSemaine(
  List<LignePrevision> prevision,
  List<LignePrevision> realise,
) {
  final prevus = {for (final l in prevision) l.titre: l};
  final vus = <String>{};
  final lignes = <LigneComparee>[];
  for (final l in realise) {
    final p = prevus[l.titre];
    if (p != null) vus.add(l.titre);
    if (p == null) {
      lignes.add(LigneComparee(GenreComparaison.ajoute, l));
    } else {
      lignes.add(
        LigneComparee(
          p.jour == l.jour && p.heure == l.heure
              ? GenreComparaison.fait
              : GenreComparaison.deplace,
          l,
          p,
        ),
      );
    }
  }
  final manquees = [
    for (final l in prevision)
      if (!vus.contains(l.titre)) LigneComparee(GenreComparaison.retire, l),
  ];
  return ComparaisonSemaine(lignes, manquees);
}

/// Une semaine du rapport d'un chef de secteur (`semainesCS`).
class SemaineCs {
  const SemaineCs({
    required this.n,
    required this.periode,
    required this.nonRenseignee,
    this.enCours = false,
    this.prevues,
    this.realisees,
    this.pct,
    this.ecarts = const [],
    this.valide,
    this.prevision = const [],
    this.comparaison,
    this.auto = true,
    this.nonValide = false,
  });

  final int n;

  /// « 2 – 6 novembre ».
  final String periode;

  /// Vrai quand la prévision n'a pas été renseignée : pas de comparaison possible.
  final bool nonRenseignee;
  final bool enCours;
  final int? prevues;
  final int? realisees;
  final int? pct;
  final List<EcartPlanning> ecarts;

  /// « lun. 2 nov. à 04:00 » ; nul pour la semaine en cours.
  final String? valide;
  final List<LignePrevision> prevision;

  /// Comparaison ligne à ligne, seulement pour la semaine 44 de Nadia H.
  final ComparaisonSemaine? comparaison;

  /// Validée automatiquement (pastille « Validé auto ») ou à la main (« Validé »).
  final bool auto;

  /// Semaine passée dont le rapport n'a pas été validé (rapport réel seulement).
  final bool nonValide;
}

/// Semaines d'un chef de secteur : la semaine en cours (45), puis les semaines validées automatiquement (44 à 39).
List<SemaineCs> semainesChefSecteur(String csId) {
  final c = detailChefSecteur(csId);
  final sans = c.prev == null;
  final base =
      c.prev?.lignes ??
      const [
        LignePrevision('Mar', '09:00', 'Carrefour – Rouen'),
        LignePrevision('Mer', '10:00', 'Super U – Versailles'),
        LignePrevision('Jeu', '14:00', 'Carrefour – Paris'),
        LignePrevision('Ven', '09:30', 'E.Leclerc – Paris'),
      ];
  List<LignePrevision> prevDe(int k) => sans
      ? const []
      : [
          ...base.skip(k % 2),
          if (k % 2 == 1)
            const LignePrevision('Lun', '11:00', 'Auchan – Rouen'),
        ];
  // `nonRenseignee` nul : valeur par défaut `sans`, et prévision vide quand il n'y a pas de prévision.
  SemaineCs sem(
    int n,
    String periode, {
    bool? nonRenseignee,
    bool enCours = false,
    int? prevues,
    int? realisees,
    int? pct,
    List<EcartPlanning> ecarts = const [],
    String? valide,
    List<LignePrevision>? prevision,
  }) => SemaineCs(
    n: n,
    periode: periode,
    nonRenseignee: nonRenseignee ?? sans,
    enCours: enCours,
    prevues: prevues,
    realisees: realisees,
    pct: pct,
    ecarts: ecarts,
    valide: valide,
    prevision: nonRenseignee == null && sans
        ? const []
        : (prevision ?? prevDe(n)),
  );

  SemaineCs semaine44() {
    if (csId != 'n') {
      return sem(
        44,
        '26 – 30 octobre',
        nonRenseignee: c.s44.pct == null,
        prevues: c.s44.prevues,
        realisees: c.s44.v,
        pct: c.s44.pct,
        ecarts: c.s44.ecarts,
        valide: 'lun. 2 nov. à 04:00',
      );
    }
    final cmp = compareSemaine(prevision44Nadia, realise44Nadia);
    final ecarts = [
      for (final x in cmp.manquees)
        _ecart(
          GenreEcart.retire,
          x.reel.titre,
          'prévu ${x.reel.jour} ${x.reel.heure}',
        ),
      for (final x in cmp.lignes)
        if (x.genre == GenreComparaison.deplace)
          _ecart(
            GenreEcart.deplace,
            x.reel.titre,
            'prévu ${x.prevu!.quand} → réalisé ${x.reel.quand}',
          ),
      for (final x in cmp.lignes)
        if (x.genre == GenreComparaison.ajoute)
          _ecart(
            GenreEcart.ajoute,
            x.reel.titre,
            'non prévu · ${x.reel.quand}',
          ),
    ];
    return SemaineCs(
      n: 44,
      periode: '26 – 30 octobre',
      nonRenseignee: false,
      prevues: 6,
      realisees: 5,
      pct: 83,
      ecarts: ecarts,
      valide: 'lun. 2 nov. à 04:00',
      prevision: prevision44Nadia,
      comparaison: cmp,
    );
  }

  return [
    sem(
      45,
      '2 – 6 novembre',
      enCours: true,
      prevues: c.rap?.prevues,
      realisees: c.rap?.realisees,
      pct: c.rap?.pct,
      ecarts: c.rap?.ecarts ?? const [],
      prevision: c.prev?.lignes ?? const [],
      nonRenseignee: sans,
    ),
    semaine44(),
    sem(
      43,
      '19 – 23 octobre',
      prevues: 14,
      realisees: 13,
      pct: 93,
      ecarts: [
        _ecart(GenreEcart.ajoute, 'Auchan – Rouen', 'visite non prévue'),
      ],
      valide: 'lun. 26 oct. à 04:00',
    ),
    sem(
      42,
      '12 – 16 octobre',
      prevues: 15,
      realisees: 15,
      pct: 100,
      valide: 'lun. 19 oct. à 04:00',
    ),
    sem(
      41,
      '5 – 9 octobre',
      prevues: 13,
      realisees: 11,
      pct: 85,
      ecarts: [
        _ecart(GenreEcart.retire, 'Carrefour – Versailles', 'prévu vendredi'),
        _ecart(GenreEcart.retire, 'Super U – Versailles', 'prévu vendredi'),
      ],
      valide: 'lun. 12 oct. à 04:00',
    ),
    sem(
      40,
      '28 sept. – 2 octobre',
      prevues: 12,
      realisees: 12,
      pct: 100,
      ecarts: [
        _ecart(GenreEcart.ajoute, 'Auchan – Rouen', 'visite non prévue'),
      ],
      valide: 'lun. 5 oct. à 04:00',
    ),
    sem(
      39,
      '21 – 25 septembre',
      nonRenseignee: true,
      realisees: 9,
      valide: 'lun. 28 sept. à 04:00',
      prevision: const [],
    ),
  ];
}

/// Filtres des semaines d'un chef de secteur (`FILTRES_SEM`) : clé et libellé dans l'ordre de la feuille.
enum FiltreSemaines {
  toutes('Toutes les semaines'),
  enCours('Semaine en cours'),
  validees('Semaines validées'),
  ecarts('Avec des écarts'),
  sans('Prévision non renseignée');

  const FiltreSemaines(this.libelle);
  final String libelle;

  /// Vrai si la semaine passe le filtre (`semainesFiltrees`).
  bool accepte(SemaineCs w) => switch (this) {
    toutes => true,
    enCours => w.enCours,
    validees => !w.enCours,
    ecarts => w.ecarts.isNotEmpty,
    sans => w.nonRenseignee,
  };
}

/// Semaines d'un chef de secteur qui passent le filtre.
List<SemaineCs> semainesFiltrees(String csId, FiltreSemaines filtre) => [
  for (final w in semainesChefSecteur(csId))
    if (filtre.accepte(w)) w,
];

/// Clients de la démo propres à chaque chef de secteur, pour ses visites et ses commandes (`activitePromo` de `pageCS`).
/// La liste de Nadia H. est aussi `CLIENTS_CS` (ses propres visites dans l'onglet « Visites » du secteur).
const Map<String, List<String>> clientsParChefSecteur = {
  'Nadia H.': clientsChefSecteur,
  'Karim B.': [
    'Auchan – Avignon',
    'Carrefour Market – Marseille',
    'Intermarché – Lyon',
  ],
  'Sophie L.': [
    'Monoprix – Nice',
    'U Express – Marseille',
    'Super U – Avignon',
  ],
};

/// `CLIENTS_CS` : clients de Nadia H.
const List<String> clientsChefSecteur = [
  'Carrefour – Rouen',
  'Super U – Versailles',
  'Carrefour – Paris',
  'Auchan – Rouen',
];
