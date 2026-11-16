import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Styles de texte de la maquette (police Inter, tailles en px CSS = dp).
///
/// `AppText.t(14.5, w: FontWeight.w800)` pour un style libre, ou les styles nommés ci-dessous.
class AppText {
  const AppText._();

  static const String famille = 'Inter';

  /// Interligne de la maquette : `line-height: normal`, soit (1 984 + 494) / 2 048 = 1,21 pour la police Inter.
  ///
  /// Material 3 impose sinon 1,43 (`bodyMedium`) ou 1,5 (`bodyLarge`, saisie des champs) à tout texte sans interligne
  /// explicite : chaque ligne serait ~18 % plus haute que dans la maquette. `AppText.t` et le thème (`AppTheme.pour`)
  /// posent donc 1,21 partout ; un style qui a un interligne propre (`h:`) le garde.
  static const double interligne = 1.21;

  /// Style de base : 16 px, couleur de texte, interligne `normal` de la maquette (`interligne`) sauf si `h` est fourni.
  static TextStyle t(
    double taille, {
    FontWeight w = FontWeight.w400,
    Color? c,
    double? h,
    double? espacement,
    TextDecoration? deco,
  }) => TextStyle(
    fontFamily: famille,
    fontSize: taille,
    fontWeight: w,
    color: c ?? AppColors.texte,
    height: h ?? interligne,
    letterSpacing: espacement,
    decoration: deco,
  );

  /// Corps de page par défaut (`body` : 16 px).
  static final TextStyle corps = t(16);

  /// Titre d'entête `.entete h1` (23 px, 800).
  static final TextStyle titreEntete = t(23, w: FontWeight.w800);

  /// Titre de section `.titre-ligne h2` (19 px, 800).
  static final TextStyle titreSection = t(19, w: FontWeight.w800);

  /// Titre de carte `.carte h4` (14.5 px, 800).
  static final TextStyle titreCarte = t(14.5, w: FontWeight.w800);

  /// Sous-titre de carte `.carte p` (12.5 px, gris).
  static final TextStyle sousCarte = t(12.5, c: AppColors.muted);

  /// Texte en gras `<b>` (700).
  static final TextStyle gras = t(16, w: FontWeight.w700);

  /// Titre de feuille `.feuille h3` (17 px, 700).
  static final TextStyle titreFeuille = t(17, w: FontWeight.w700);

  /// Titre de dialogue `.dialogue h3` (18,72 px, 700).
  static final TextStyle titreDialogue = t(18.72, w: FontWeight.w700);

  /// Petit texte de pied `.pied` (11,5 px, gris).
  static final TextStyle pied = t(11.5, c: AppColors.muted);

  /// Texte courant des champs (`.champ input` : 14 px).
  static final TextStyle champ = t(14);

  /// Étiquette de champ `.champ label` (12 px, 600, gris).
  static final TextStyle etiquetteChamp = t(
    12,
    w: FontWeight.w600,
    c: AppColors.muted,
  );
}
