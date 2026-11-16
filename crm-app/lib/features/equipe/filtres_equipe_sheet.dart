import '../../core/data/equipe_serveur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import 'state/equipe_state.dart';
import 'state/filtres.dart';

/// Ouvre la feuille « Filtres ». Maquette : modale `eq-filtres` l.1869-1876.
/// Appelée par `AppRoutes.filtresEquipe(context)`.
Future<void> ouvrirFiltresEquipe(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const FiltresEquipeSheet());

/// Feuille « Filtres » du directeur : afficher les chefs de secteur ou les promoteurs, choisir une région.
/// Chaque choix s'applique aussitôt à la liste ; « Réinitialiser » revient aux chefs de secteur de toutes les régions.
class FiltresEquipeSheet extends ConsumerWidget {
  const FiltresEquipeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtresEquipeProvider);
    final notifier = ref.read(filtresEquipeProvider.notifier);
    final regions = <String>{for (final c in chefsActuels()) c.region};
    return FeuilleBase(
      titre: 'Filtres',
      children: [
        const TitreFiltre('Afficher'),
        for (final t in TypeEquipe.values)
          OptionRadio(
            label: t.libelle,
            selectionne: f.type == t,
            onTap: () => notifier.maj((x) => x.copyWith(type: t)),
          ),
        const TitreFiltre('Région'),
        OptionRadio(
          label: 'Toutes les régions',
          selectionne: f.region == regionToutes,
          onTap: () => notifier.maj((x) => x.copyWith(region: regionToutes)),
        ),
        for (final r in regions)
          OptionRadio(
            label: r,
            selectionne: f.region == r,
            onTap: () => notifier.maj((x) => x.copyWith(region: r)),
          ),
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Réinitialiser',
              petit: true,
              onPressed: notifier.reinitialiser,
            ),
            AppBouton(
              'Appliquer',
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
