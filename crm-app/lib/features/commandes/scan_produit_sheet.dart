import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'state/commande_provider.dart';
import 'state/scan_provider.dart';

/// Ouvre la feuille « Scanner un produit ». Maquette : modale `cmd-scan` l.1410-1415 et action l.1676-1680.
/// Appelée par `AppRoutes.scannerProduit(context)`.
Future<void> ouvrirScanProduit(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const ScanProduitSheet());

/// Feuille « Scanner un produit » : aperçu de caméra simulé (coins blancs, ligne rouge animée), « Simuler un scan »
/// ajoute un produit à la commande.
class ScanProduitSheet extends ConsumerStatefulWidget {
  const ScanProduitSheet({super.key});

  @override
  ConsumerState<ScanProduitSheet> createState() => _ScanProduitSheetState();
}

class _ScanProduitSheetState extends ConsumerState<ScanProduitSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool? _animationReduite;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduite = MediaQuery.disableAnimationsOf(context);
    if (reduite == _animationReduite) return;
    _animationReduite = reduite;
    if (reduite) {
      _anim.stop();
    } else {
      _anim.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// `cmd-scan-ok` : le scan est simulé, il « lit » le produit disponible suivant du catalogue.
  void _simuler() {
    final navigateur = Navigator.of(context);
    if (ref.read(commandeEnCoursProvider) == null) {
      navigateur.pop();
      return;
    }
    final disponibles = produitsCatalogue
        .where((p) => p.stock != NiveauStock.rupture)
        .toList();
    final rang = ref.read(scanSuivantProvider.notifier).prochain();
    final p = disponibles[rang % disponibles.length];
    ref.read(commandeEnCoursProvider.notifier).ajouter(p.id);
    AppToast.show(context, '✓ ${p.nom} ajouté · EAN ${p.ean}');
    navigateur.pop();
  }

  @override
  Widget build(BuildContext context) {
    return FeuilleBase(
      titre: 'Scanner un produit',
      children: [
        Semantics(
          image: true,
          label: 'Aperçu de la caméra',
          child: _VueScan(
            animation: _anim,
            reduite: _animationReduite ?? false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              'Pointez la caméra vers le code-barres (EAN) du produit : il est ajouté à la commande.',
              textAlign: TextAlign.center,
              style: AppText.t(13, c: AppColors.muted),
            ),
          ),
        ),
        Rangee(
          children: [
            AppBouton(
              'Annuler',
              petit: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppBouton(
              'Simuler un scan',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: _simuler,
            ),
          ],
        ),
      ],
    );
  }
}

/// Aperçu de caméra simulé (`.scan-vue`) : fond sombre de 190 px, quatre coins blancs et une ligne rouge qui va
/// et vient de 32 à 156 px en 1,8 s. Animation réduite : la ligne reste à mi-hauteur.
class _VueScan extends StatelessWidget {
  const _VueScan({required this.animation, required this.reduite});

  final Animation<double> animation;
  final bool reduite;

  static const double _hauteur = 190;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: _hauteur,
        width: double.infinity,
        color: const Color(0xFF111827),
        child: Stack(
          children: [
            for (final (gauche, haut) in const [
              (true, true),
              (false, true),
              (true, false),
              (false, false),
            ])
              Positioned(
                left: gauche ? 18 : null,
                right: gauche ? null : 18,
                top: haut ? 18 : null,
                bottom: haut ? null : 18,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CustomPaint(
                    painter: _CoinScan(versGauche: gauche, versHaut: haut),
                  ),
                ),
              ),
            Positioned(
              left: 30,
              right: 30,
              top: 0,
              child: reduite
                  ? Transform.translate(
                      offset: const Offset(0, _hauteur / 2),
                      child: const _LigneScan(),
                    )
                  : AnimatedBuilder(
                      animation: animation,
                      builder: (_, enfant) => Transform.translate(
                        offset: Offset(
                          0,
                          32 +
                              (156 - 32) *
                                  Curves.easeInOut.transform(animation.value),
                        ),
                        child: enfant,
                      ),
                      child: const _LigneScan(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La ligne rouge du scan : 2 px de haut, halo rouge de 10 px (`--alert`).
class _LigneScan extends StatelessWidget {
  const _LigneScan();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: const BoxDecoration(
        color: AppColors.alert,
        boxShadow: [BoxShadow(color: AppColors.alert, blurRadius: 10)],
      ),
    );
  }
}

/// Un coin de visée (`.scan-vue .c`) : carré de 34 px, traits blancs de 4 px sur deux côtés seulement, coin
/// extérieur arrondi à 6 px.
class _CoinScan extends CustomPainter {
  const _CoinScan({required this.versGauche, required this.versHaut});

  /// Le coin est à gauche (sinon à droite) et en haut (sinon en bas) du cadre.
  final bool versGauche;
  final bool versHaut;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Le tracé de référence est le coin haut gauche ; les autres s'obtiennent par symétrie.
    if (!versGauche) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (!versHaut) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    // Ligne médiane du trait : à 2 px des bords, rayon 6 - 2 = 4 (le rayon extérieur vaut 6, l'intérieur 2).
    final chemin = Path()
      ..moveTo(2, size.height)
      ..lineTo(2, 6)
      ..arcTo(const Rect.fromLTWH(2, 2, 8, 8), math.pi, math.pi / 2, false)
      ..lineTo(size.width, 2);
    canvas.drawPath(
      chemin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoinScan old) =>
      old.versGauche != versGauche || old.versHaut != versHaut;
}
