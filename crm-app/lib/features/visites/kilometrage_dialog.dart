import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/visites_logique.dart';
import 'state/kilometrage.dart';

/// Moment du relevé de kilométrage : départ ou arrivée de la tournée (`phase` de la modale `km`).
enum PhaseKilometrage { depart, arrivee }

/// Dernier relevé connu du véhicule, proposé en exemple au départ (`48215` de la maquette).
const int _dernierReleve = 48215;

/// Ouvre le dialogue « Kilométrage ». Maquette : modale `km` l.1337-1343 et actions l.1536-1543.
/// Appelée par `AppRoutes.kilometrage(context, phase)`.
Future<void> ouvrirKilometrage(BuildContext context, PhaseKilometrage phase) =>
    showAppDialog<void>(
      context,
      builder: (_) => KilometrageDialog(phase: phase),
    );

/// Dialogue « Kilométrage » : 🚗 « Kilométrage de départ / d'arrivée », champ numérique « Dernier relevé : 48 215 km », Plus tard / Enregistrer.
class KilometrageDialog extends ConsumerStatefulWidget {
  const KilometrageDialog({super.key, required this.phase});

  /// Départ ou arrivée de la tournée.
  final PhaseKilometrage phase;

  @override
  ConsumerState<KilometrageDialog> createState() => _KilometrageDialogState();
}

class _KilometrageDialogState extends ConsumerState<KilometrageDialog> {
  final TextEditingController _saisie = TextEditingController();

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  bool get _depart => widget.phase == PhaseKilometrage.depart;

  void _enregistrer() {
    final releve = lireEntierKm(_saisie.text);
    final km = ref.read(kilometrageProvider);
    if (releve == null || releve == 0) {
      AppToast.show(
        context,
        'Indiquez le kilométrage, ou touchez « Plus tard ».',
      );
      return;
    }
    final depart = km.depart;
    if (!_depart && depart != null && releve < depart) {
      AppToast.show(
        context,
        "Le kilométrage d'arrivée ne peut pas être inférieur à celui du départ ($depart km).",
      );
      return;
    }
    ref
        .read(kilometrageProvider.notifier)
        .maj(
          (k) => _depart
              ? k.copyWith(depart: releve)
              : k.copyWith(arrivee: releve),
        );
    AppToast.show(
      context,
      !_depart && depart != null
          ? "Kilométrage enregistré : ${releve - depart} km parcourus aujourd'hui."
          : 'Kilométrage enregistré : $releve km.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reference = _depart
        ? _dernierReleve
        : (ref.watch(kilometrageProvider).depart ?? _dernierReleve);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text('🚗', style: TextStyle(fontSize: 30)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _depart ? 'Kilométrage de départ' : "Kilométrage d'arrivée",
                style: AppText.titreDialogue,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _depart
                          ? 'Relevez le compteur de votre véhicule avant de commencer votre tournée. '
                          : 'Votre tournée est terminée : relevez le compteur de votre véhicule. ',
                    ),
                    TextSpan(
                      text: 'Facultatif',
                      style: AppText.t(
                        14,
                        w: FontWeight.w700,
                        c: const Color(0xFF374151),
                        h: 1.45,
                      ),
                    ),
                    const TextSpan(text: ' : vous pouvez le faire plus tard.'),
                  ],
                ),
                style: AppText.t(14, c: const Color(0xFF374151), h: 1.45),
              ),
            ),
            ChampTexte(
              label: 'Kilométrage (km)',
              controller: _saisie,
              hint: 'Dernier relevé : ${milliersEspaces(reference)} km',
              clavier: TextInputType.number,
            ),
            Rangee(
              children: [
                AppBouton(
                  'Plus tard',
                  petit: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                AppBouton(
                  'Enregistrer',
                  petit: true,
                  variante: VarianteBouton.plein,
                  onPressed: _enregistrer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
