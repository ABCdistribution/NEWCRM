import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import 'ecarts_liste.dart';

/// Carte « Prévu vs réalisé » du planning (`ecartsCarte`) : taux de réalisation de la prévision, barre, et au toucher
/// le détail des écarts. Sans prévision, une carte statique explique qu'il n'y a rien à comparer.
class EcartsCarte extends StatelessWidget {
  const EcartsCarte({
    super.key,
    required this.ecarts,
    required this.ouvert,
    required this.valide,
    required this.onBasculer,
  });

  /// Comparaison prévision / planning, nulle sans prévision.
  final ResultatEcarts? ecarts;

  /// Détail déplié.
  final bool ouvert;

  /// Rapport figé (semaine validée) : le pied de carte change.
  final bool valide;
  final VoidCallback onBasculer;

  @override
  Widget build(BuildContext context) {
    final c = ecarts;
    if (c == null) {
      return AppCarte(
        margeBas: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prévu vs réalisé', style: AppText.t(14, w: FontWeight.w700)),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                "Prévision non renseignée cette semaine : il n'y a pas de comparaison possible.",
                style: AppText.sousCarte,
              ),
            ),
          ],
        ),
      );
    }
    final u = context.univers;
    String pluriel(int n, String mot) => '$n $mot${n > 1 ? 's' : ''}';
    final puces = <Widget>[
      if (c.ajoutees > 0)
        Pastille(
          pluriel(c.ajoutees, 'ajoutée'),
          variante: VariantePastille.bleu,
        ),
      if (c.retirees > 0)
        Pastille(
          pluriel(c.retirees, 'retirée'),
          variante: VariantePastille.rouge,
        ),
      if (c.deplacees > 0)
        Pastille(
          pluriel(c.deplacees, 'déplacée'),
          variante: VariantePastille.jaune,
        ),
      if (c.non > 0)
        Pastille(
          pluriel(c.non, 'non réalisée'),
          variante: VariantePastille.rouge,
        ),
      if (c.ajoutees + c.retirees + c.deplacees + c.non == 0)
        const Pastille('Aucun écart', variante: VariantePastille.vert),
    ];
    return AppCarte(
      margeBas: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBasculer,
            child: AppLigne(
              alignement: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Prévu vs réalisé',
                    style: AppText.t(14.5, w: FontWeight.w700),
                  ),
                ),
                Text(
                  '${c.pct} %',
                  style: AppText.t(20, w: FontWeight.w800, c: u.violet),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    ouvert ? '▲' : '▼',
                    style: AppText.t(16, c: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          BarreProgression(valeur: (c.pct > 100 ? 100 : c.pct) / 100),
          if (ouvert) ...[
            Chiffres([
              Chiffre('${c.prevues}', 'prévues'),
              Chiffre('${c.realisees}', 'réalisées'),
            ], margeHaut: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: puces),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: EcartsListe(c.lignes),
            ),
            Pied(
              valide
                  ? "Rapport figé : voici ce qui s'est réellement passé par rapport à la prévision."
                  : 'La prévision est figée depuis le mardi ; les écarts se mettent à jour au fil de la semaine.',
            ),
          ],
        ],
      ),
    );
  }
}
