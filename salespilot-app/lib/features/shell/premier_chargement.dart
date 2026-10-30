import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../prechargement.dart';

/// Écran du tout premier lancement : le téléphone n'a encore aucune donnée. L'application se charge entièrement
/// (une seule fois) pour fonctionner ensuite sans réseau ; aux lancements suivants, la mise à jour se fait en
/// arrière-plan sans cet écran.
class PremierChargement extends ConsumerWidget {
  const PremierChargement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(prechargementProvider);
    final accent = SpacePalette.sales.accent;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(etat.echec ? Icons.cloud_off : Icons.cloud_download_outlined, size: 56, color: etat.echec ? StatusColors.warn : accent),
            const SizedBox(height: 20),
            Text(
              etat.echec ? 'Chargement impossible' : 'Préparation de l\'application',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              etat.echec
                  ? 'Le serveur n\'a pas répondu. Le premier chargement demande une connexion ; ensuite l\'application fonctionne sans réseau.'
                  : 'Téléchargement des magasins, des produits et de votre tournée pour travailler sans réseau. Cela n\'a lieu qu\'une fois.',
              style: const TextStyle(color: StatusColors.muted, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (etat.echec)
              FilledButton.icon(
                onPressed: () => ref.read(prechargementProvider.notifier).lancer(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: etat.verifie ? etat.fait / etat.total : null,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE3E8F3),
                  color: accent,
                ),
              ),
              const SizedBox(height: 10),
              Text(etat.etape.isEmpty ? 'Démarrage…' : '${etat.etape} (${etat.fait + 1}/${etat.total})', style: const TextStyle(fontSize: 12, color: StatusColors.muted)),
            ],
          ]),
        ),
      ),
    );
  }
}
