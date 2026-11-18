import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/visites_logique.dart';
import 'state/actions_visite.dart';

/// Scan des colis d'une commande à mettre en rayon : la caméra lit les codes-barres ou QR codes, chaque code lu est
/// ajouté à la visite. L'écran reste ouvert pour enchaîner les colis ; « Terminé » revient à la visite.
/// Ouvert par `AppRoutes.scannerColis`.
class ScanColisScreen extends ConsumerStatefulWidget {
  const ScanColisScreen({super.key, required this.visiteId});

  final String visiteId;

  @override
  ConsumerState<ScanColisScreen> createState() => _ScanColisScreenState();
}

class _ScanColisScreenState extends ConsumerState<ScanColisScreen> {
  final MobileScannerController _camera = MobileScannerController(
    formats: const [
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.itf14,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
    ],
  );

  /// Dernier code lu et heure de lecture : une même étiquette gardée devant la caméra n'est comptée qu'une fois.
  String? _dernier;
  DateTime _vuLe = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _lu(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final code = codeColisValide(b.rawValue);
      if (code == null) continue;
      final maintenant = DateTime.now();
      if (code == _dernier &&
          maintenant.difference(_vuLe) < const Duration(seconds: 3)) {
        _vuLe = maintenant;
        return;
      }
      _dernier = code;
      _vuLe = maintenant;
      final visite = ref.read(visiteParIdProvider(widget.visiteId));
      final deja = visite?.colis.contains(code) ?? false;
      ActionsVisite(
        ref.read(crmProvider.notifier),
        widget.visiteId,
      ).ajouterColis(code);
      AppToast.show(context, deja ? 'Déjà scanné : $code' : '✓ Colis $code');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colis =
        ref.watch(visiteParIdProvider(widget.visiteId))?.colis ?? const [];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _lu,
            errorBuilder: (context, erreur) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "La caméra n'est pas disponible. Autorisez-la dans les réglages du téléphone, ou saisissez le code du colis à la main.",
                  textAlign: TextAlign.center,
                  style: AppText.t(15, c: Colors.white),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Présentez le code-barres du colis devant la caméra',
                      textAlign: TextAlign.center,
                      style: AppText.t(14, w: FontWeight.w600, c: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${colis.length} colis scanné${colis.length > 1 ? 's' : ''}'
                          '${colis.isEmpty ? '' : ' · dernier : ${colis.last}'}',
                          textAlign: TextAlign.center,
                          style: AppText.t(
                            14,
                            w: FontWeight.w700,
                            c: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppBouton(
                          '✓ Terminé',
                          variante: VarianteBouton.plein,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
