import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Ligne « clé : valeur » d'une feuille basse (`.feuille .ch`) : 15 px, filet dessous, libellé gris à gauche et
/// valeur en gras à droite (`l(k, v)` de la modale `sproduit`).
///
/// Ce n'est pas la `LigneCle` de `core/ui`, qui reproduit `.corps .ch` (14 px, marges 9 / 2) : dans une feuille la
/// règle `.feuille .ch` s'applique, avec 14 px de marge verticale et 4 px sur les côtés.
class LigneFeuille extends StatelessWidget {
  const LigneFeuille(this.cle, this.valeur, {super.key});

  final String cle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ligne)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(cle, style: AppText.t(15, c: AppColors.muted)),
          ),
          Flexible(
            child: Text(valeur, style: AppText.t(15, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
