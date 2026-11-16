import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../logic/regles_commande.dart';

/// Ligne de stock d'un produit : « ● En stock · 98 disponibles », colorée selon le niveau.
class LigneStock extends StatelessWidget {
  const LigneStock(this.info, {super.key, this.taille = 12.5, this.suite = ''});

  final InfoStock info;

  /// 12,5 px dans le catalogue de prise de commande, 12 px dans le panier et les remplacements.
  final double taille;

  /// Texte ajouté à la suite (« · 3,46 € HT »).
  final String suite;

  @override
  Widget build(BuildContext context) => Text(
    '● ${info.texte}$suite',
    style: AppText.t(taille, w: FontWeight.w700, c: info.couleur),
  );
}

/// Message d'erreur de stock (`.erreur` compact) dont la fin est un lien souligné : « Stock insuffisant : 8
/// disponibles pour 12 demandés. Compléter avec un remplacement › ».
class ErreurStock extends StatefulWidget {
  const ErreurStock({
    super.key,
    required this.texte,
    required this.lien,
    required this.onLien,
  });

  final String texte;
  final String lien;
  final VoidCallback onLien;

  @override
  State<ErreurStock> createState() => _ErreurStockState();
}

class _ErreurStockState extends State<ErreurStock> {
  late final TapGestureRecognizer _appui = TapGestureRecognizer()
    ..onTap = () => widget.onLien();

  @override
  void dispose() {
    _appui.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppText.t(12.5, c: AppColors.pRougeTexte);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pRougeFond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          text: '${widget.texte} ',
          children: [
            TextSpan(
              text: widget.lien,
              recognizer: _appui,
              style: style.copyWith(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        style: style,
      ),
    );
  }
}

/// Bouton « Remplacer › » d'un produit en rupture : contour et texte rouges (`.btn.sm` aux couleurs d'alerte).
class BoutonRemplacer extends StatelessWidget {
  const BoutonRemplacer({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remplacer ›',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.alert),
          ),
          child: Text(
            'Remplacer ›',
            maxLines: 1,
            style: AppText.t(13, w: FontWeight.w700, c: AppColors.alert),
          ),
        ),
      ),
    );
  }
}
