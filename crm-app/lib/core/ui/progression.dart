import 'package:flutter/material.dart';

import '../logic/objectifs.dart';
import '../theme/theme.dart';

/// Couleur d'un taux d'atteinte : vert ≥ 90 %, orange ≥ 70 %, rouge en dessous (`couleurObj`).
Color couleurObjectif(num pct) => switch (niveauObjectif(pct)) {
  NiveauObjectif.bon => AppColors.ok,
  NiveauObjectif.moyen => AppColors.warn,
  NiveauObjectif.faible => AppColors.alert,
};

/// Barre de progression fine (`.barre-v` violette, `.barre` bleue). `valeur` entre 0 et 1.
class BarreProgression extends StatelessWidget {
  const BarreProgression({
    super.key,
    required this.valeur,
    this.couleur,
    this.fond,
    this.margeHaut = 8,
  });

  final double valeur;

  /// Couleur de remplissage ; à défaut le violet de l'univers.
  final Color? couleur;
  final Color? fond;
  final double margeHaut;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Padding(
      padding: EdgeInsets.only(top: margeHaut),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 6,
          width: double.infinity,
          color: fond ?? AppColors.barreVFond,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: valeur.clamp(0, 1).toDouble(),
            child: Container(color: couleur ?? u.violet),
          ),
        ),
      ),
    );
  }
}

/// Barre d'objectif en euros (`barreEur`) : remplissage vert, orange ou rouge selon l'atteinte.
class BarreObjectif extends StatelessWidget {
  const BarreObjectif({
    super.key,
    required this.real,
    required this.cible,
    this.margeHaut = 8,
  });

  final double real;
  final double cible;
  final double margeHaut;

  @override
  Widget build(BuildContext context) {
    final ratio = cible == 0 ? 0.0 : real / cible;
    return BarreProgression(
      valeur: ratio,
      couleur: couleurObjectif(ratio * 100),
      margeHaut: margeHaut,
    );
  }
}

/// Barre d'étapes d'un prospect (`.etape-barre`) : segments remplis jusqu'à l'étape courante, noms dessous.
class EtapesBarre extends StatelessWidget {
  const EtapesBarre({super.key, required this.noms, required this.segments});

  final List<String> noms;

  /// Nombre de segments remplis (1 à `noms.length`).
  final int segments;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < noms.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < segments ? u.violet : AppColors.ligne,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    noms[i],
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: AppText.t(
                      10,
                      w: i == segments - 1 ? FontWeight.w800 : FontWeight.w400,
                      c: i == segments - 1 ? u.violet : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// État d'un segment de la barre de livraison.
enum EtatSegmentLivraison { vide, rempli, partiel }

/// Barre de suivi de livraison (`.liv-barre`) : « Reçue · Expédiée · Livrée ».
class BarreLivraison extends StatelessWidget {
  const BarreLivraison({super.key, required this.noms, required this.etats});

  final List<String> noms;
  final List<EtatSegmentLivraison> etats;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < noms.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  etats[i] == EtatSegmentLivraison.partiel
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: const SizedBox(
                            height: 5,
                            width: double.infinity,
                            child: CustomPaint(painter: _RayuresPartiel()),
                          ),
                        )
                      : Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: etats[i] == EtatSegmentLivraison.rempli
                                ? u.bleu
                                : AppColors.ligne,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      noms[i],
                      style: AppText.t(10, c: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rayures du segment « partiel » de la barre de livraison : rouge `#DC2626` sur 5 px puis rose `#fecaca` sur 4 px,
/// à la verticale (`repeating-linear-gradient(90deg, #DC2626 0 5px, #fecaca 5px 9px)`).
class _RayuresPartiel extends CustomPainter {
  const _RayuresPartiel();

  @override
  void paint(Canvas canvas, Size size) {
    final rouge = Paint()..color = AppColors.alert;
    final rose = Paint()..color = const Color(0xFFFECACA);
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 5, size.height), rouge);
      canvas.drawRect(Rect.fromLTWH(x + 5, 0, 4, size.height), rose);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
