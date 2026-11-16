import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'state/prospects_state.dart';

/// Ouvre la feuille « Filtres ». Maquette : modale `pv-filtres` l.1858-1864.
/// Appelée par `AppRoutes.filtresProspects(context)`.
Future<void> ouvrirFiltresProspects(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const FiltresProspectsSheet());

/// Feuille « Filtres » : directeur seulement : interrupteurs par chef de secteur (avec son nombre de prospects), statut
/// (tous les statuts ou un groupe du pipeline), « Réinitialiser » et « Voir N prospects ». Les choix s'appliquent
/// aussitôt à la page Prospects.
class FiltresProspectsSheet extends ConsumerWidget {
  const FiltresProspectsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prospects = ref.watch(prospectsProvider);
    final chefsRetenus = ref.watch(chefsSecteurRetenusProvider);
    final filtre = ref.watch(filtreGroupeProvider);
    final chefs = {
      for (final p in prospects)
        if (p.cs != null && p.cs!.isNotEmpty) p.cs!,
    }.toList()..sort(compareFr);
    final nb = prospects
        .where(
          (p) =>
              (filtre == null || p.groupe == filtre) &&
              (chefsRetenus.isEmpty || chefsRetenus.contains(p.cs)),
        )
        .length;
    final chefsNotifier = ref.read(chefsSecteurRetenusProvider.notifier);
    final filtreNotifier = ref.read(filtreGroupeProvider.notifier);
    return FeuilleBase(
      titre: 'Filtres',
      children: [
        const TitreFiltre('Chefs de secteur'),
        for (final c in chefs)
          _LigneChefSecteur(
            nom: c,
            nombre: prospects.where((p) => p.cs == c).length,
            actif: chefsRetenus.contains(c),
            onChanged: (_) => chefsNotifier.basculer(c),
          ),
        const TitreFiltre('Statut'),
        OptionRadio(
          label: 'Tous les statuts',
          selectionne: filtre == null,
          onTap: () => filtreNotifier.definir(null),
        ),
        for (final g in GroupeProspect.values)
          OptionRadio(
            label: g.libelle,
            selectionne: filtre == g,
            onTap: () => filtreNotifier.definir(g),
          ),
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Réinitialiser',
              petit: true,
              onPressed: () {
                chefsNotifier.vider();
                filtreNotifier.definir(null);
              },
            ),
            AppBouton(
              'Voir $nb prospect${nb > 1 ? 's' : ''}',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Une ligne « chef de secteur (nombre) + interrupteur » (`.qrow`).
class _LigneChefSecteur extends StatelessWidget {
  const _LigneChefSecteur({
    required this.nom,
    required this.nombre,
    required this.actif,
    required this.onChanged,
  });

  final String nom;
  final int nombre;
  final bool actif;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$nom ',
                children: [
                  TextSpan(
                    text: '($nombre)',
                    style: AppText.t(12.5, c: AppColors.muted),
                  ),
                ],
              ),
              style: AppText.t(14),
            ),
          ),
          const SizedBox(width: 12),
          Interrupteur(valeur: actif, onChanged: onChanged),
        ],
      ),
    );
  }
}
