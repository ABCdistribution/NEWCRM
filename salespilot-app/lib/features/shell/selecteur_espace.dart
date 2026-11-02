import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/role.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// Sélecteur Sales / Pilotage des en-têtes d'accueil, réservé à l'encadrement : pour les autres rôles il est masqué.
/// Le serveur reste juge, l'application ne propose simplement pas l'espace (CDC §3.0).
class SelecteurEspace extends ConsumerWidget {
  const SelecteurEspace({super.key, required this.space});

  /// Espace affiché (celui de l'écran sur lequel se trouve le sélecteur).
  final Space space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Promoteur, ADV, marketing : aucun accès à ABC Pilot, le sélecteur n'est pas affiché du tout.
    final peutBasculer = ref.watch(currentRoleProvider)?.canSwitchSpace ?? false;
    if (!peutBasculer) return const SizedBox.shrink();
    final couleur = SpacePalette.of(space).accent;

    Widget onglet(Space cible, String label) {
      final actif = cible == space;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: actif ? null : () => ref.read(spaceProvider.notifier).select(cible),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: actif ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: TextStyle(color: actif ? couleur : Colors.white, fontWeight: actif ? FontWeight.w800 : FontWeight.w700)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [onglet(Space.sales, 'Sales'), onglet(Space.pilot, 'Pilotage')]),
    );
  }
}
