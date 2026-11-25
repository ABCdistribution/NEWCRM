import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/data/data.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import '../catalogue/fiche_produit_sheet.dart';
import 'logic/scan_produit.dart';
import 'produits_remplacement_sheet.dart';
import 'state/commande_provider.dart';
import 'state/scan_provider.dart';

/// Ouvre la feuille « Scanner un produit ». Maquette : modale `cmd-scan` l.1410-1415 et action l.1676-1680.
/// Appelée par `AppRoutes.scannerProduit(context)`.
Future<void> ouvrirScanProduit(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const ScanProduitSheet());

/// Ouvre la feuille de scan depuis le catalogue : le produit lu par son EAN ouvre sa fiche.
/// Appelée par `AppRoutes.scannerCatalogue(context)`.
Future<void> ouvrirScanCatalogue(BuildContext context) async {
  final produit = await showAppSheet<Produit>(
    context,
    builder: (_) => const ScanProduitSheet(pourCatalogue: true),
  );
  if (produit == null || !context.mounted) return;
  await ouvrirFicheProduit(context, produit.id);
}

/// Feuille « Scanner un produit ». Connecté au CRM : vraie caméra, le produit lu par son EAN est ajouté à la
/// commande ; un produit en rupture n'est pas ajouté, un message s'affiche aussitôt dans la feuille. En
/// démonstration : aperçu simulé (coins blancs, ligne rouge animée) et boutons « Simuler… ».
///
/// `pourCatalogue` : la feuille sert au référentiel produits. Le produit lu (disponible ou en rupture) est rendu à
/// l'appelant par la fermeture de la feuille, rien n'est ajouté à une commande.
class ScanProduitSheet extends ConsumerStatefulWidget {
  const ScanProduitSheet({super.key, this.pourCatalogue = false});

  final bool pourCatalogue;

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

  /// Connecté au CRM : vraie caméra (sinon simulation).
  final bool _reel = DemoTemps.reel;
  late final MobileScannerController? _camera = _reel
      ? MobileScannerController(
          formats: const [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
            BarcodeFormat.code128,
          ],
        )
      : null;

  /// Dernier code lu et heure de lecture (doublons de moins de 3 s ignorés).
  String? _dernier;
  DateTime _vuLe = DateTime.fromMillisecondsSinceEpoch(0);

  /// Produit en rupture lu : le message s'affiche et le scan est suspendu jusqu'à « Fermer ».
  Produit? _rupture;
  int _rangRupture = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduite = MediaQuery.disableAnimationsOf(context);
    if (reduite == _animationReduite) return;
    _animationReduite = reduite;
    if (reduite || _reel) {
      _anim.stop();
    } else {
      _anim.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _camera?.dispose();
    super.dispose();
  }

  /// Traite le produit lu : inconnu (message), disponible (ajouté à la commande) ou en rupture (message fixe).
  void _traiter(LectureScan lecture, String code) {
    final navigateur = Navigator.of(context);
    final p = lecture.produit;
    if (widget.pourCatalogue && p != null) {
      navigateur.pop(p);
      return;
    }
    switch (lecture.resultat) {
      case ResultatScan.inconnu:
        AppToast.show(context, 'Produit inconnu : $code');
      case ResultatScan.rupture:
        setState(() => _rupture = p);
      case ResultatScan.disponible:
        if (ref.read(commandeEnCoursProvider) == null) {
          navigateur.pop();
          return;
        }
        ref.read(commandeEnCoursProvider.notifier).ajouter(p!.id);
        AppToast.show(
          context,
          _reel ? '✓ ${p.nom} ajouté' : '✓ ${p.nom} ajouté · EAN ${p.ean}',
        );
        navigateur.pop();
    }
  }

  /// Lecture de la caméra : ignore les doublons immédiats et tout ce qui arrive pendant le message de rupture.
  void _lu(BarcodeCapture capture) {
    if (_rupture != null) return;
    for (final b in capture.barcodes) {
      final code = b.rawValue?.trim();
      if (code == null || code.isEmpty) continue;
      final maintenant = DateTime.now();
      final doublon = scanEnDoublon(
        code: code,
        dernier: _dernier,
        vuLe: _vuLe,
        maintenant: maintenant,
      );
      _vuLe = maintenant;
      if (doublon) return;
      _dernier = code;
      _traiter(classerScan(code, tousProduits()), code);
      return;
    }
  }

  /// `cmd-scan-ok` : le scan est simulé, il « lit » le produit disponible suivant du catalogue.
  void _simuler() {
    final navigateur = Navigator.of(context);
    if (!widget.pourCatalogue && ref.read(commandeEnCoursProvider) == null) {
      navigateur.pop();
      return;
    }
    final disponibles = produitsCatalogue
        .where((p) => !produitEnRupture(p))
        .toList();
    final rang = ref.read(scanSuivantProvider.notifier).prochain();
    final p = disponibles[rang % disponibles.length];
    _traiter(LectureScan(ResultatScan.disponible, p), p.ean);
  }

  /// Simulation d'un produit en rupture : passe en revue les ruptures du catalogue de démonstration.
  void _simulerRupture() {
    final ruptures = produitsCatalogue.where(produitEnRupture).toList();
    final p = ruptures[_rangRupture++ % ruptures.length];
    _traiter(LectureScan(ResultatScan.rupture, p), p.ean);
  }

  Future<void> _voirRemplacements() async {
    final p = _rupture;
    if (p == null) return;
    await ouvrirProduitsRemplacement(context, p.id);
    if (mounted) setState(() => _rupture = null);
  }

  Widget _apercu() {
    final camera = _camera;
    if (camera == null) {
      return Semantics(
        image: true,
        label: 'Aperçu de la caméra',
        child: _VueScan(animation: _anim, reduite: _animationReduite ?? false),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: _VueScan.hauteurApercu,
        width: double.infinity,
        child: MobileScanner(
          controller: camera,
          onDetect: _lu,
          errorBuilder: (context, erreur) => Container(
            color: const Color(0xFF111827),
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Text(
              "La caméra n'est pas disponible. Autorisez-la dans les réglages du téléphone, puis rouvrez le scan.",
              textAlign: TextAlign.center,
              style: AppText.t(14, c: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rupture = _rupture;
    return FeuilleBase(
      titre: 'Scanner un produit',
      children: [
        _apercu(),
        if (rupture != null)
          _MessageRupture(
            produit: rupture,
            onRemplacements: _voirRemplacements,
            onFermer: () => setState(() => _rupture = null),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                widget.pourCatalogue
                    ? 'Pointez la caméra vers le code-barres (EAN) du produit.'
                    : 'Pointez la caméra vers le code-barres (EAN) du produit : il est ajouté à la commande.',
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
              if (!_reel)
                AppBouton(
                  'Simuler un scan',
                  petit: true,
                  variante: VarianteBouton.plein,
                  onPressed: _simuler,
                ),
            ],
          ),
          if (!_reel && !widget.pourCatalogue)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: AppBouton(
                  'Simuler un produit en rupture',
                  petit: true,
                  onPressed: _simulerRupture,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Message affiché dès la lecture d'un produit en rupture : nom, date de réapprovisionnement si connue, deux actions.
class _MessageRupture extends StatelessWidget {
  const _MessageRupture({
    required this.produit,
    required this.onRemplacements,
    required this.onFermer,
  });

  final Produit produit;
  final VoidCallback onRemplacements;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    final reappro = produit.reappro;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pRougeFond,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              '${produit.nom} est en rupture de stock',
              style: AppText.t(
                15,
                w: FontWeight.w800,
                c: AppColors.pRougeTexte,
              ),
            ),
          ),
          if (reappro != null && reappro.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Réapprovisionnement prévu le $reappro',
                style: AppText.t(13, c: AppColors.pRougeTexte),
              ),
            ),
          const SizedBox(height: 12),
          Rangee(
            children: [
              AppBouton('Fermer', petit: true, onPressed: onFermer),
              AppBouton(
                'Voir les remplacements',
                petit: true,
                variante: VarianteBouton.plein,
                onPressed: onRemplacements,
              ),
            ],
          ),
        ],
      ),
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

  /// Hauteur de l'aperçu, la même pour la caméra réelle.
  static const double hauteurApercu = _hauteur;

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
