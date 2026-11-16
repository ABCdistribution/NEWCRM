import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

/// Carte d'un client dans la liste (`.carte` : nom, adresse, pastille de classe). Un appui ouvre la fiche.
class CarteClient extends StatelessWidget {
  const CarteClient({super.key, required this.magasin, required this.onTap});

  final Magasin magasin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = magasin;
    return AppCarte(
      onTap: onTap,
      child: AppLigne(
        alignement: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.nom, style: AppText.titreCarte),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(m.adresse, style: AppText.sousCarte),
                ),
              ],
            ),
          ),
          Pastille(
            '${m.actif ? '' : 'Inactif · '}Classe ${m.classe}',
            variante: m.actif ? VariantePastille.client : VariantePastille.gris,
          ),
        ],
      ),
    );
  }
}

/// Lien de bascule du promoteur au-dessus de la liste (`.liv-lien`) : « Voir tous les clients du secteur (6) » suivi
/// d'un « › », texte d'accent gras et souligné.
class LienPortee extends StatelessWidget {
  const LienPortee({super.key, required this.libelle, required this.onTap});

  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppText.t(
      14.5,
      w: FontWeight.w700,
      c: context.univers.acc,
      deco: TextDecoration.underline,
    ).copyWith(decorationThickness: 1.5);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(libelle, style: style)),
            const SizedBox(width: 8),
            Text('›', style: style),
          ],
        ),
      ),
    );
  }
}
