import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/ui/ui.dart';
import 'data/visites_data.dart';
import 'logic/visites_logique.dart';
import 'state/filtres_visites.dart';

/// Ouvre la feuille « Filtres ». Maquette : modale `vfiltres` l.1388-1396.
/// Appelée par `AppRoutes.filtresVisites(context)`.
Future<void> ouvrirFiltresVisites(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const FiltresVisitesSheet());

/// Feuille « Filtres » : afficher (mes visites / toutes), état (brouillon, à envoyer, envoyée), période, « Voir N visites ».
class FiltresVisitesSheet extends ConsumerWidget {
  const FiltresVisitesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    final f = ref.watch(filtresVisitesProvider);
    final nb = visitesFiltrees(ref.watch(crmProvider), f).length;
    final notifier = ref.read(filtresVisitesProvider.notifier);
    return FeuilleBase(
      titre: 'Filtres',
      children: [
        const TitreFiltre('Afficher'),
        OptionRadio(
          label: 'Mes visites',
          selectionne: f.portee == PorteeVisites.mes,
          onTap: () => notifier.maj((f) => f.avecPortee(PorteeVisites.mes)),
        ),
        OptionRadio(
          label: 'Toutes les visites',
          detail: '(${porteeVisites[role]})',
          selectionne: f.portee == PorteeVisites.toutes,
          onTap: () => notifier.maj((f) => f.avecPortee(PorteeVisites.toutes)),
        ),
        const TitreFiltre('État'),
        OptionRadio(
          label: 'Tous les états',
          selectionne: f.etat == null,
          onTap: () => notifier.maj((f) => f.avecEtat(null)),
        ),
        for (final e in EtatVisite.values)
          OptionRadio(
            label: e.libelle,
            selectionne: f.etat == e,
            onTap: () => notifier.maj((f) => f.avecEtat(e)),
          ),
        const TitreFiltre('Période'),
        for (final p in PeriodeVisites.values)
          OptionRadio(
            label: p.libelle,
            selectionne: f.periode == p,
            onTap: () => notifier.maj((f) => f.avecPeriode(p)),
          ),
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Réinitialiser',
              petit: true,
              onPressed: () => notifier.maj((f) => f.reinitialises()),
            ),
            AppBouton(
              'Voir $nb visite${sPluriel(nb)}',
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
