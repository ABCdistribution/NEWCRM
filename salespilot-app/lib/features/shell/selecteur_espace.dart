import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/role.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// Sélecteur Sales / Pilotage des en-têtes d'accueil. Pilotage est verrouillé pour les rôles sans accès : le
/// serveur reste juge, l'application ne propose simplement pas l'espace (CDC §3.0).
class SelecteurEspace extends ConsumerWidget {
  const SelecteurEspace({super.key, required this.space});

  /// Espace affiché (celui de l'écran sur lequel se trouve le sélecteur).
  final Space space;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peutBasculer = ref.watch(currentRoleProvider)?.canSwitchSpace ?? false;
    final couleur = SpacePalette.of(space).accent;

    Widget onglet(Space cible, String label) {
      final actif = cible == space;
      final verrou = cible == Space.pilot && !peutBasculer;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: actif
              ? null
              : () {
                  if (verrou) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('ABC Pilot est réservé à l\'encadrement.')));
                  } else {
                    ref.read(spaceProvider.notifier).select(cible);
                  }
                },
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: actif ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (verrou) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.lock_outline, size: 16, color: Colors.white)),
              Text(label, style: TextStyle(color: actif ? couleur : Colors.white, fontWeight: actif ? FontWeight.w800 : FontWeight.w700)),
            ]),
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
