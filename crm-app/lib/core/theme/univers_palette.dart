import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/role.dart';

/// Dégradé linéaire à la façon de CSS (`linear-gradient(135deg, …)`) : l'angle est exact quelle que soit la forme
/// du rectangle, les coins de départ et d'arrivée prenant la première et la dernière couleur.
///
/// Un `LinearGradient(begin: topLeft, end: bottomRight)` de Flutter relie les deux coins : sur un bouton large et bas,
/// les bandes de couleur deviennent presque verticales, alors que CSS garde des bandes à 45°.
class DegradeCss extends LinearGradient {
  const DegradeCss({required super.colors, super.stops, this.angle = 135});

  /// Angle CSS en degrés : 0 vers le haut, 90 vers la droite, 180 vers le bas.
  final double angle;

  /// Points de départ et d'arrivée de la ligne de dégradé dans `rect` (ligne qui passe par le centre).
  (Offset, Offset) extremites(Rect rect) {
    final a = angle * math.pi / 180;
    final dx = math.sin(a);
    final dy = -math.cos(a);
    final demiLongueur = (rect.width * dx.abs() + rect.height * dy.abs()) / 2;
    final c = rect.center;
    return (
      Offset(c.dx - dx * demiLongueur, c.dy - dy * demiLongueur),
      Offset(c.dx + dx * demiLongueur, c.dy + dy * demiLongueur),
    );
  }

  @override
  Shader createShader(Rect rect, {TextDirection? textDirection}) {
    final (debut, fin) = extremites(rect);
    final arrets =
        stops ??
        [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)];
    return ui.Gradient.linear(debut, fin, colors, arrets, tileMode);
  }
}

/// Palette d'un univers (`.u-sales` bleu pour le promoteur, `.u-pilot` violet pour l'encadrement).
///
/// Lecture : `context.univers.acc`. Les valeurs sont celles des variables CSS de la maquette
/// (l.262-307) : `--acc`, `--acc2`, `--halo`, `--encre`, `--encre2`, `--bleu`, `--violet`, `--violet-fonce`.
@immutable
class UniversPalette extends ThemeExtension<UniversPalette> {
  const UniversPalette({
    required this.univers,
    required this.acc,
    required this.acc2,
    required this.halo,
    required this.encre,
    required this.encre2,
    required this.bleu,
    required this.violet,
    required this.violetFonce,
    required this.fondCouleurs,
  });

  final Univers univers;

  /// Couleur d'accent (`--acc`) : boutons, liens, icônes de la nav active.
  final Color acc;

  /// Accent clair (`--acc2`), départ des dégradés de boutons.
  final Color acc2;

  /// Halo des ombres colorées (`--halo`).
  final Color halo;

  /// Texte sur le fond dégradé (`--encre`) et son variante (`--encre2`).
  final Color encre;
  final Color encre2;

  /// `--bleu` et `--violet` ne valent pas la même chose selon l'univers (voir CSS).
  final Color bleu;
  final Color violet;
  final Color violetFonce;

  /// Six couleurs du fond, aux arrêts 0, 12, 28, 46, 66 et 100 %.
  final List<Color> fondCouleurs;

  /// Arrêts du dégradé vertical de fond.
  static const List<double> fondArrets = [0, 0.12, 0.28, 0.46, 0.66, 1];

  /// Dégradé vertical de fond d'une page (`linear-gradient(180deg, …)`).
  LinearGradient get fond => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: fondCouleurs,
    stops: fondArrets,
  );

  /// Dégradé des boutons pleins, du FAB et du « + » (`linear-gradient(135deg, acc2, acc)`).
  LinearGradient get degradeBouton => DegradeCss(colors: [acc2, acc]);

  /// Ombre des cartes (`0 8px 22px halo`), des KPI, bandeaux et timelines.
  List<BoxShadow> get ombreCarte => [
    BoxShadow(color: halo, offset: const Offset(0, 8), blurRadius: 22),
  ];

  /// Ombre des tuiles, boutons tonals, recherche, segments, actions (`0 6px 16px halo`).
  List<BoxShadow> get ombreDouce => [
    BoxShadow(color: halo, offset: const Offset(0, 6), blurRadius: 16),
  ];

  /// Ombre des petits ronds : avatar, cloche, retour (`0 5px 14px halo`).
  List<BoxShadow> get ombreRond => [
    BoxShadow(color: halo, offset: const Offset(0, 5), blurRadius: 14),
  ];

  /// Ombre des boutons pleins (`0 8px 18px halo`).
  List<BoxShadow> get ombreBouton => [
    BoxShadow(color: halo, offset: const Offset(0, 8), blurRadius: 18),
  ];

  /// Ombre du bouton flottant (`0 10px 24px halo`).
  List<BoxShadow> get ombreFab => [
    BoxShadow(color: halo, offset: const Offset(0, 10), blurRadius: 24),
  ];

  /// Ombre de la barre de navigation (`0 -8px 22px halo`).
  List<BoxShadow> get ombreNav => [
    BoxShadow(color: halo, offset: const Offset(0, -8), blurRadius: 22),
  ];

  /// Univers « sales » : bleu, promoteur (`.ecran.u-sales`).
  static const UniversPalette sales = UniversPalette(
    univers: Univers.sales,
    acc: Color(0xFF1F7AEA),
    acc2: Color(0xFF65B8FD),
    halo: Color(0x6165B8FD), // rgba(101,184,253,.38)
    encre: Color(0xFF0B2545),
    encre2: Color(0xFF2E1B56),
    bleu: Color(0xFF1F7AEA),
    violet: Color(0xFF6545C5),
    violetFonce: Color(0xFF4B2FA0),
    fondCouleurs: [
      Color(0xFF65B8FD),
      Color(0xFF8CCBFE),
      Color(0xFFCBE6FF),
      Color(0xFFEEF7FF),
      Color(0xFFFAFDFF),
      Color(0xFFFFFFFF),
    ],
  );

  /// Univers « pilot » : violet, chef de secteur et directeur (`.ecran.u-pilot`).
  static const UniversPalette pilot = UniversPalette(
    univers: Univers.pilot,
    acc: Color(0xFF7A56E6),
    acc2: Color(0xFFB396FB),
    halo: Color(0x6BB396FB), // rgba(179,150,251,.42)
    encre: Color(0xFF241447),
    encre2: Color(0xFF2E1B56),
    bleu: Color(0xFF1D4ED8),
    violet: Color(0xFF7A56E6),
    violetFonce: Color(0xFF5B3CC4),
    fondCouleurs: [
      Color(0xFFB396FB),
      Color(0xFFC6B0FC),
      Color(0xFFE1D6FE),
      Color(0xFFF3EEFF),
      Color(0xFFFBF9FF),
      Color(0xFFFFFFFF),
    ],
  );

  static UniversPalette pour(Univers u) => u == Univers.sales ? sales : pilot;

  @override
  UniversPalette copyWith({
    Univers? univers,
    Color? acc,
    Color? acc2,
    Color? halo,
    Color? encre,
    Color? encre2,
    Color? bleu,
    Color? violet,
    Color? violetFonce,
    List<Color>? fondCouleurs,
  }) {
    return UniversPalette(
      univers: univers ?? this.univers,
      acc: acc ?? this.acc,
      acc2: acc2 ?? this.acc2,
      halo: halo ?? this.halo,
      encre: encre ?? this.encre,
      encre2: encre2 ?? this.encre2,
      bleu: bleu ?? this.bleu,
      violet: violet ?? this.violet,
      violetFonce: violetFonce ?? this.violetFonce,
      fondCouleurs: fondCouleurs ?? this.fondCouleurs,
    );
  }

  @override
  UniversPalette lerp(ThemeExtension<UniversPalette>? other, double t) {
    if (other is! UniversPalette) return this;
    return t < 0.5 ? this : other;
  }
}

/// Accès à la palette de l'univers courant : `context.univers`.
extension UniversContext on BuildContext {
  UniversPalette get univers =>
      Theme.of(this).extension<UniversPalette>() ?? UniversPalette.pilot;
}
