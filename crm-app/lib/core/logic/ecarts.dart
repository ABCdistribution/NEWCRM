/// Écarts prévu / réalisé : logique partagée par les lots planning (Mon planning, Mes rapports) et équipe
/// (rapports des chefs de secteur). Maquette : `calcEcarts` l.964-977, `ECART_STYLE` l.979, `ecartsListe` l.980-989,
/// `resumeEcarts` l.1000-1008 et `fixE` l.763.
library;

import '../models/models.dart';
import 'dates.dart';

/// Genre d'un écart (`k` dans la maquette).
enum GenreEcart {
  /// Réalisé comme prévu.
  fait,

  /// Prévu, pas encore fait (semaine en cours).
  avenir,

  /// Prévu, non réalisé (semaine validée).
  non,

  /// Retiré du planning, non réalisé.
  retire,

  /// Ajouté, non prévu.
  ajoute,

  /// Déplacé (jour ou heure changés).
  deplace,
}

/// Présentation d'un genre d'écart : symbole du rond, couleurs (ARGB) et libellé (`ECART_STYLE`).
class StyleEcart {
  const StyleEcart(this.symbole, this.texte, this.fond, this.libelle);
  final String symbole;

  /// Couleur du symbole.
  final int texte;

  /// Fond du rond.
  final int fond;
  final String libelle;
}

/// Styles des écarts, dans l'ordre de la maquette.
const Map<GenreEcart, StyleEcart> stylesEcart = {
  GenreEcart.fait: StyleEcart(
    '✓',
    0xFF166534,
    0xFFDDF5E6,
    'Réalisé comme prévu',
  ),
  GenreEcart.avenir: StyleEcart('…', 0xFF374151, 0xFFEDEFF3, 'À faire'),
  GenreEcart.non: StyleEcart('✕', 0xFF991B1B, 0xFFFEE2E2, 'Non réalisé'),
  GenreEcart.retire: StyleEcart(
    '✕',
    0xFF991B1B,
    0xFFFEE2E2,
    'Retiré du planning, non réalisé',
  ),
  GenreEcart.ajoute: StyleEcart(
    '＋',
    0xFF1E3A8A,
    0xFFDFE8FF,
    'Ajouté (non prévu)',
  ),
  GenreEcart.deplace: StyleEcart('↔', 0xFF92400E, 0xFFFCEFC6, 'Déplacé'),
};

/// Ordre d'affichage d'une liste d'écarts : retirés, non réalisés, déplacés, ajoutés, à faire, faits.
const Map<GenreEcart, int> ordreEcarts = {
  GenreEcart.retire: 0,
  GenreEcart.non: 1,
  GenreEcart.deplace: 2,
  GenreEcart.ajoute: 3,
  GenreEcart.avenir: 4,
  GenreEcart.fait: 5,
};

/// Une ligne de planning vue par la comparaison : titre, jour (nul pour un résumé sans date), heure, note.
class PointPlanning {
  const PointPlanning({
    required this.titre,
    this.jour,
    this.heure = '',
    this.note = '',
    this.fait = false,
  });

  /// Reprend une ligne du planning.
  factory PointPlanning.depuis(EtapePlanning e) => PointPlanning(
    titre: e.titre,
    jour: e.jour,
    heure: e.heure,
    note: e.note,
    fait: e.fait,
  );

  final String titre;
  final int? jour;
  final String heure;
  final String note;
  final bool fait;

  /// « Mar 09:00 », vide si la ligne n'a pas de jour (`quand`).
  String get quand => jour == null ? '' : '${joursCourts[jour!]} $heure'.trim();
}

/// Une ligne d'écart : son genre, la ligne prévue (`p`) et la ligne réelle (`e`).
class EcartPlanning {
  const EcartPlanning(this.genre, {this.prevu, this.reel});

  /// Écart donné par un résumé « titre + détail » (rapports d'équipe, `fixE`) : aucune date, le détail est la note.
  factory EcartPlanning.resume(GenreEcart genre, String titre, String? detail) {
    final p = PointPlanning(titre: titre, note: detail ?? '');
    return EcartPlanning(genre, prevu: p, reel: p);
  }

  final GenreEcart genre;
  final PointPlanning? prevu;
  final PointPlanning? reel;

  /// Ligne affichée : la réelle, à défaut la prévue.
  PointPlanning get point => (reel ?? prevu)!;

  /// Titre de la ligne.
  String get titre => point.titre;

  /// Détail après le libellé du genre (`ecartsListe`) : « prévu Mer 11:30 → réalisé Mer 15:00 », « prévu Mar 09:00 »…
  String get detail {
    final p = point;
    if (p.jour == null) return p.note;
    return switch (genre) {
      GenreEcart.deplace =>
        'prévu ${prevu!.quand} → ${reel!.fait ? 'réalisé' : 'planifié'} ${reel!.quand}',
      GenreEcart.retire => 'prévu ${prevu!.quand}',
      GenreEcart.ajoute => reel!.quand,
      _ => p.quand,
    };
  }

  /// Texte de la deuxième ligne : « Retiré du planning, non réalisé · prévu Jeu 14:00 ».
  String get sousTitre {
    final d = detail;
    final libelle = stylesEcart[genre]!.libelle;
    return d.isEmpty ? libelle : '$libelle · $d';
  }
}

/// Écarts triés pour l'affichage (`ecartsListe`) ; le tri est stable à genre égal.
List<EcartPlanning> ecartsTries(Iterable<EcartPlanning> lignes) {
  final l = lignes.toList();
  final indexes = {for (var i = 0; i < l.length; i++) l[i]: i};
  l.sort((a, b) {
    final c = ordreEcarts[a.genre]!.compareTo(ordreEcarts[b.genre]!);
    return c != 0 ? c : indexes[a]!.compareTo(indexes[b]!);
  });
  return l;
}

/// Résumé en une ligne : « +1 ajoutée · 1 retirée », « aucun écart » (`resumeEcarts`).
String resumeEcarts(Iterable<GenreEcart> genres) {
  final l = genres.toList();
  int n(GenreEcart k) => l.where((x) => x == k).length;
  final t = <String>[
    if (n(GenreEcart.ajoute) > 0)
      '+${n(GenreEcart.ajoute)} ajoutée${n(GenreEcart.ajoute) > 1 ? 's' : ''}',
    if (n(GenreEcart.retire) > 0)
      '${n(GenreEcart.retire)} retirée${n(GenreEcart.retire) > 1 ? 's' : ''}',
    if (n(GenreEcart.deplace) > 0)
      '${n(GenreEcart.deplace)} déplacée${n(GenreEcart.deplace) > 1 ? 's' : ''}',
    if (n(GenreEcart.non) > 0)
      '${n(GenreEcart.non)} non réalisée${n(GenreEcart.non) > 1 ? 's' : ''}',
  ];
  return t.isEmpty ? 'aucun écart' : t.join(' · ');
}

/// Résultat de la comparaison prévision / planning réel (`calcEcarts`).
class ResultatEcarts {
  const ResultatEcarts({
    required this.lignes,
    required this.prevues,
    required this.realisees,
  });

  final List<EcartPlanning> lignes;

  /// Nombre de lignes de la prévision.
  final int prevues;

  /// Lignes prévues, toujours présentes et faites.
  final int realisees;

  int _n(GenreEcart k) => lignes.where((l) => l.genre == k).length;
  int get ajoutees => _n(GenreEcart.ajoute);
  int get retirees => _n(GenreEcart.retire);
  int get deplacees => _n(GenreEcart.deplace);
  int get non => _n(GenreEcart.non);

  /// Taux de réalisation de la prévision, en pourcentage arrondi.
  int get pct => (realisees / prevues * 100).round();
}

/// Compare la prévision enregistrée (`prevu`) au planning actuel (`etapes`) ; nul sans prévision.
///
/// `valide` : rapport validé (semaine passée) : une ligne prévue, non faite et non déplacée devient « non réalisée »
/// au lieu de « à faire ». Les lignes sont rapprochées par `id`.
ResultatEcarts? calculerEcarts({
  required List<EtapePlanning>? prevu,
  required List<EtapePlanning> etapes,
  required bool valide,
}) {
  if (prevu == null || prevu.isEmpty) return null;
  final courantes = {for (final e in etapes) e.id: e};
  final prevus = {for (final p in prevu) p.id};
  final lignes = <EcartPlanning>[];
  for (final p in prevu) {
    final e = courantes[p.id];
    final pp = PointPlanning.depuis(p);
    if (e == null) {
      lignes.add(EcartPlanning(GenreEcart.retire, prevu: pp));
    } else if (e.jour != p.jour || e.heure != p.heure) {
      lignes.add(
        EcartPlanning(
          GenreEcart.deplace,
          prevu: pp,
          reel: PointPlanning.depuis(e),
        ),
      );
    } else {
      lignes.add(
        EcartPlanning(
          e.fait
              ? GenreEcart.fait
              : valide
              ? GenreEcart.non
              : GenreEcart.avenir,
          prevu: pp,
          reel: PointPlanning.depuis(e),
        ),
      );
    }
  }
  for (final e in etapes) {
    if (!prevus.contains(e.id)) {
      lignes.add(
        EcartPlanning(GenreEcart.ajoute, reel: PointPlanning.depuis(e)),
      );
    }
  }
  final realisees = prevu.where((p) {
    final e = courantes[p.id];
    return e != null && e.fait;
  }).length;
  return ResultatEcarts(
    lignes: lignes,
    prevues: prevu.length,
    realisees: realisees,
  );
}
