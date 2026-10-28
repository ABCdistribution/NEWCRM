import 'package:flutter/material.dart';

import '../auth/role.dart';

/// Palette de la plateforme : bleu marine pour ABC Sales, violet pour ABC Pilot (comme le web).
class SpacePalette {
  const SpacePalette({required this.nav, required this.active, required this.accent});

  /// Fond des barres sombres (en-tête, navigation).
  final Color nav;

  /// Fond de l'entrée active de la navigation.
  final Color active;

  /// Couleur des boutons et des accents.
  final Color accent;

  static const sales = SpacePalette(nav: Color(0xFF050F33), active: Color(0xFF1C347D), accent: Color(0xFF2952E3));
  static const pilot = SpacePalette(nav: Color(0xFF130D25), active: Color(0xFF55399B), accent: Color(0xFF6545C5));

  static SpacePalette of(Space space) => space == Space.sales ? sales : pilot;
}

/// Couleurs d'état communes aux deux espaces.
abstract final class StatusColors {
  static const ok = Color(0xFF059669);
  static const warn = Color(0xFFD97706);
  static const alert = Color(0xFFDC2626);
  static const muted = Color(0xFF6B7280);
}

ThemeData buildTheme(Space space) {
  final p = SpacePalette.of(space);
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: Brightness.light).copyWith(
    primary: p.accent,
    onPrimary: Colors.white,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: const Color(0xFFF1F4FB),
    appBarTheme: AppBarTheme(
      backgroundColor: p.nav,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    // Navigation claire : entrée active en couleur d'accent, les autres en gris (maquette de l'accueil).
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.accent : StatusColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.accent : StatusColors.muted),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE8EAF2))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        minimumSize: const Size.fromHeight(48), // grandes cibles tactiles : utilisable à une main
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
