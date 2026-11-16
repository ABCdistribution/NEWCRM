import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_icons.dart';

/// Teinte de l'élément sélectionné d'un segment ou d'un onglet.
enum TonSelection {
  /// Violet pâle sur texte violet foncé (`.seg button.on`).
  violet,

  /// Bleu pâle sur texte bleu foncé (`.seg.sales`).
  bleu,
}

/// Contrôle segmenté en pilule (`.seg`) : « Mes prospects | Timeline ».
///
/// ```dart
/// Segment(libelles: ['Liste', 'Timeline'], index: 0, onChanged: (i) {})
/// ```
class Segment extends StatelessWidget {
  const Segment({
    super.key,
    required this.libelles,
    required this.index,
    required this.onChanged,
    this.ton = TonSelection.violet,
    this.margeBas = 14,
  });

  final List<String> libelles;

  /// Index sélectionné ; -1 = aucun (ex. « Réalisée / Pas de visite PEM » avant réponse).
  final int index;
  final ValueChanged<int> onChanged;
  final TonSelection ton;
  final double margeBas;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final (fondSel, texteSel) = ton == TonSelection.bleu
        ? (AppColors.pBleuFond, AppColors.pBleuTexte)
        : (const Color(0xFFE7E0F7), u.violetFonce);
    return Container(
      margin: EdgeInsets.only(bottom: margeBas),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: u.ombreDouce,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Row(
          children: [
            for (var i = 0; i < libelles.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    color: i == index ? fondSel : null,
                    child: Text(
                      libelles[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.t(
                        13.5,
                        w: i == index ? FontWeight.w800 : FontWeight.w600,
                        c: i == index ? texteSel : AppColors.texte,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Onglets en pilules défilables (`.onglets`) : noir sélectionné par défaut, accent avec `accent`.
class OngletsPills extends StatelessWidget {
  const OngletsPills({
    super.key,
    required this.libelles,
    required this.index,
    required this.onChanged,
    this.accent = false,
  });

  final List<String> libelles;
  final int index;
  final ValueChanged<int> onChanged;

  /// Sélection en couleur d'accent au lieu de noir (`.on.sales`).
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < libelles.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: i == index
                        ? (accent ? u.acc : AppColors.texte)
                        : AppColors.grisOnglet,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    libelles[i],
                    style: AppText.t(
                      13.5,
                      w: FontWeight.w700,
                      c: i == index ? Colors.white : AppColors.texte,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Puce de choix (`.chip`) : contour gris ; sélectionnée = fond d'accent, texte blanc.
class ChipChoix extends StatelessWidget {
  const ChipChoix(
    this.label, {
    super.key,
    required this.selectionne,
    required this.onTap,
  });

  final String label;
  final bool selectionne;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne ? u.acc : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selectionne ? u.acc : AppColors.bordureChamp,
          ),
        ),
        child: Text(
          label,
          style: AppText.t(
            13.5,
            c: selectionne ? Colors.white : AppColors.texte,
          ),
        ),
      ),
    );
  }
}

/// Un jour du sélecteur de jours : « Mar », 3, « 2 RDV ».
class JourItem {
  const JourItem({
    required this.libelle,
    required this.numero,
    required this.compte,
  });
  final String libelle;
  final int numero;
  final String compte;
}

/// Sélecteur de jours de la semaine (`.jours` / `.jour`) : cinq tuiles, la sélectionnée en blanc.
class SelecteurJours extends StatelessWidget {
  const SelecteurJours({
    super.key,
    required this.jours,
    required this.index,
    required this.onChanged,
    this.margeHaut = 14,
  });

  final List<JourItem> jours;
  final int index;
  final ValueChanged<int> onChanged;
  final double margeHaut;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Padding(
      padding: EdgeInsets.only(top: margeHaut),
      child: Row(
        children: [
          for (var i = 0; i < jours.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: i == index ? u.ombreDouce : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        jours[i].libelle,
                        style: AppText.t(
                          12,
                          w: FontWeight.w600,
                          c: i == index ? u.acc : u.encre2,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '${jours[i].numero}',
                          style: AppText.t(19, w: FontWeight.w700, c: u.encre),
                        ),
                      ),
                      Text(
                        jours[i].compte,
                        style: AppText.t(
                          10.5,
                          w: FontWeight.w700,
                          c: i == index ? u.acc : u.encre2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sélecteur déroulant factice (`.selecteur`) : libellé et « ▾ », ouvre une feuille de choix.
class Selecteur extends StatelessWidget {
  const Selecteur(
    this.label, {
    super.key,
    required this.onTap,
    this.ombre = true,
  });

  final String label;
  final VoidCallback onTap;

  /// Faux dans une barre de recherche (`box-shadow: none`).
  final bool ombre;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.bordureChamp),
          boxShadow: ombre
              ? [
                  BoxShadow(
                    color: u.halo,
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Le libellé passe à la ligne comme dans `.selecteur` (pas de `text-overflow`).
            Expanded(child: Text(label, style: AppText.t(14.5))),
            const SizedBox(width: 8),
            const AppIcon(
              AppIcons.chevronBas,
              size: 16,
              color: AppColors.texte,
            ),
          ],
        ),
      ),
    );
  }
}
