import 'package:flutter/material.dart';

/// Couleurs sémantiques communes aux deux univers (variables CSS `:root` de la maquette).
///
/// Les couleurs qui changent selon l'univers (accent, halo, encre, bleu, violet) sont dans
/// `UniversPalette`, lisible par `context.univers`.
class AppColors {
  const AppColors._();

  static const Color fond = Color(0xFFF1F3FB);
  static const Color carte = Colors.white;
  static const Color texte = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color ok = Color(0xFF059669);
  static const Color warn = Color(0xFFD97706);
  static const Color alert = Color(0xFFDC2626);
  static const Color ligne = Color(0xFFE5E7EF);

  /// Bordure des champs de saisie (`#c7cad6`).
  static const Color bordureChamp = Color(0xFFC7CAD6);

  /// Bordure des boutons contour et segments hors univers (`#9ca3af`).
  static const Color bordureBouton = Color(0xFF9CA3AF);

  /// Voile derrière une feuille ou un dialogue (`#0007`).
  static const Color voile = Color(0x77000000);

  /// Fond gris clair des ronds, chips et onglets inactifs.
  static const Color grisRond = Color(0xFFEDEFF3);
  static const Color grisOnglet = Color(0xFFE7E8F1);

  // Pastilles (variantes `.p-*`) : fond, texte.
  static const Color pGrisFond = Color(0xFFEDEFF3);
  static const Color pGrisTexte = Color(0xFF374151);
  static const Color pBleuFond = Color(0xFFDFE8FF);
  static const Color pBleuTexte = Color(0xFF1E3A8A);
  static const Color pJauneFond = Color(0xFFFCEFC6);
  static const Color pJauneTexte = Color(0xFF92400E);
  static const Color pVertFond = Color(0xFFDDF5E6);
  static const Color pVertTexte = Color(0xFF166534);
  static const Color pRougeFond = Color(0xFFFEE2E2);
  static const Color pRougeTexte = Color(0xFF991B1B);
  static const Color pClientFond = Color(0xFFEBE5FF);
  static const Color pClientTexte = Color(0xFF5B21B6);

  /// Fond des pastilles `.p-violet` et du rond « prochain » (`#6545C51f`) : toujours le violet d'origine à 12 %,
  /// dans les deux univers (seul le texte suit `--violet` de l'univers).
  static const Color violetTeinte = Color(0x1F6545C5);

  static const Color pRoseFond = Color(0xFFFCE7F3);
  static const Color pRoseTexte = Color(0xFF9D174D);

  /// Rond « fait » (✓) de la tournée.
  static const Color rondFait = Color(0xFFCDEFD9);

  /// Cloche : pastille de compteur (`#F59E0B`).
  static const Color compteur = Color(0xFFF59E0B);

  /// Barre de progression « barre-v » (fond) et « barre » (fond).
  static const Color barreVFond = Color(0xFFE5E7EF);
  static const Color barreFond = Color(0xFFE3E8F3);

  /// Écart de planning : fond gris de « À faire ».
  static const Color ecartGrisFond = Color(0xFFEDEFF3);
  static const Color ecartGrisTexte = Color(0xFF374151);
}
