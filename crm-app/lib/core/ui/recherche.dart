import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'boutons.dart';

/// Champ de recherche blanc ombré (`.recherche`).
class ChampRecherche extends StatelessWidget {
  const ChampRecherche({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.valeurInitiale,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  /// Texte initial si aucun `controller` n'est fourni.
  final String? valeurInitiale;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    // `.recherche` : padding 12 px 14 px autour d'une ligne de 14 px, soit ≈ 42 px de haut (hauteur fixe : la
    // hauteur d'une ligne de texte dépend de la police, la maquette est bâtie sur le padding).
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: u.ombreDouce,
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? valeurInitiale : null,
        onChanged: onChanged,
        style: AppText.champ,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppText.t(14, c: AppColors.muted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isCollapsed: true,
        ),
      ),
    );
  }
}

/// Barre de recherche avec boutons à droite (`.barre-rech`) : champ, scan optionnel, filtres avec compteur.
///
/// ```dart
/// BarreRecherche(hint: 'Rechercher un client…', onChanged: (q) {}, nbFiltres: 1, onFiltres: () {})
/// ```
class BarreRecherche extends StatelessWidget {
  const BarreRecherche({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onFiltres,
    this.nbFiltres = 0,
    this.controller,
    this.valeurInitiale,
    this.actionsSup = const [],
    this.margeHaut = 14,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  /// Ouvre la feuille de filtres ; nul = pas de bouton filtre.
  final VoidCallback? onFiltres;
  final int nbFiltres;
  final TextEditingController? controller;
  final String? valeurInitiale;

  /// Boutons supplémentaires entre le champ et le filtre (ex. scan d'un code-barres).
  final List<Widget> actionsSup;
  final double margeHaut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: margeHaut),
      child: Row(
        children: [
          Expanded(
            child: ChampRecherche(
              hint: hint,
              onChanged: onChanged,
              controller: controller,
              valeurInitiale: valeurInitiale,
            ),
          ),
          for (final a in actionsSup) ...[const SizedBox(width: 10), a],
          if (onFiltres != null) ...[
            const SizedBox(width: 10),
            BoutonFiltre(onTap: onFiltres!, nbFiltres: nbFiltres),
          ],
        ],
      ),
    );
  }
}
