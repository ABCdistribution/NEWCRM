import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../models/role.dart';
import 'app_colors.dart';
import 'app_text.dart';
import 'univers_palette.dart';

/// `ThemeData` Material 3 de l'application, un par univers.
///
/// Le thème est posé au niveau de `MaterialApp` selon le rôle choisi : feuilles, dialogues et
/// pages héritent donc automatiquement de la bonne palette (`context.univers`).
class AppTheme {
  const AppTheme._();

  static ThemeData pour(Univers univers) {
    final palette = UniversPalette.pour(univers);
    final schema =
        ColorScheme.fromSeed(
          seedColor: palette.acc,
          brightness: Brightness.light,
        ).copyWith(
          primary: palette.acc,
          onPrimary: Colors.white,
          secondary: palette.acc2,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: AppColors.texte,
          error: AppColors.alert,
          outline: AppColors.ligne,
          outlineVariant: AppColors.ligne,
        );
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppText.famille,
      colorScheme: schema,
      brightness: Brightness.light,
    );
    final texte = _interligneMaquette(
      base.textTheme
          .apply(
            fontFamily: AppText.famille,
            bodyColor: AppColors.texte,
            displayColor: AppColors.texte,
          )
          .copyWith(
            bodyMedium: AppText.corps,
            bodyLarge: AppText.corps,
            bodySmall: AppText.t(12),
            labelLarge: AppText.t(14, w: FontWeight.w700),
            titleMedium: AppText.t(16, w: FontWeight.w600),
            titleLarge: AppText.t(19, w: FontWeight.w800),
          ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.fond,
      canvasColor: Colors.white,
      textTheme: texte,
      primaryTextTheme: texte,
      dividerColor: AppColors.ligne,
      dividerTheme: const DividerThemeData(
        color: AppColors.ligne,
        space: 1,
        thickness: 1,
      ),
      // Pas d'ondulation : la maquette ne marque aucun retour tactile.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        modalBarrierColor: AppColors.voile,
        elevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: palette.acc),
      extensions: [palette],
    );
  }

  /// Pose l'interligne `normal` de la maquette (`AppText.interligne`) sur les quinze styles du thème.
  ///
  /// Material 3 donne 1,43 au texte courant (`DefaultTextStyle`, repris par chaque `Text` sans interligne) et 1,5 à la
  /// saisie des champs : sans cette correction, tout le texte de l'application est ~18 % trop haut.
  static TextTheme _interligneMaquette(TextTheme t) {
    TextStyle? h(TextStyle? s) => s?.copyWith(height: AppText.interligne);
    return t.copyWith(
      displayLarge: h(t.displayLarge),
      displayMedium: h(t.displayMedium),
      displaySmall: h(t.displaySmall),
      headlineLarge: h(t.headlineLarge),
      headlineMedium: h(t.headlineMedium),
      headlineSmall: h(t.headlineSmall),
      titleLarge: h(t.titleLarge),
      titleMedium: h(t.titleMedium),
      titleSmall: h(t.titleSmall),
      bodyLarge: h(t.bodyLarge),
      bodyMedium: h(t.bodyMedium),
      bodySmall: h(t.bodySmall),
      labelLarge: h(t.labelLarge),
      labelMedium: h(t.labelMedium),
      labelSmall: h(t.labelSmall),
    );
  }

  static final ThemeData sales = pour(Univers.sales);
  static final ThemeData pilot = pour(Univers.pilot);
}
