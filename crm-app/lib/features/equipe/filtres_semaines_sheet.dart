import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import 'data/equipe_demo.dart';
import 'state/equipe_state.dart';

/// Ouvre la feuille « Filtrer les semaines ». Maquette : modale `cs-filtres` l.1877-1882 et `FILTRES_SEM` l.836.
/// Appelée par `AppRoutes.filtresSemainesChefSecteur(context, csId)`.
Future<void> ouvrirFiltresSemaines(BuildContext context, String csId) =>
    showAppSheet<void>(
      context,
      builder: (_) => FiltresSemainesSheet(csId: csId),
    );

/// Feuille « Filtrer les semaines » d'un chef de secteur : toutes, en cours, validées, avec des écarts, sans prévision.
/// Chaque choix s'applique aussitôt ; le bouton du bas annonce le nombre de semaines retenues (« Voir 3 semaines »).
class FiltresSemainesSheet extends ConsumerWidget {
  const FiltresSemainesSheet({super.key, required this.csId});

  /// Chef de secteur : « n », « k » ou « s ».
  final String csId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choisi = ref.watch(filtreSemainesProvider);
    final notifier = ref.read(filtreSemainesProvider.notifier);
    final nb = semainesFiltrees(csId, choisi).length;
    return FeuilleBase(
      titre: 'Filtrer les semaines',
      children: [
        for (final f in FiltreSemaines.values)
          OptionRadio(
            label: f.libelle,
            selectionne: choisi == f,
            onTap: () => notifier.choisir(f),
          ),
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Réinitialiser',
              petit: true,
              onPressed: () => notifier.choisir(FiltreSemaines.toutes),
            ),
            AppBouton(
              'Voir $nb semaine${nb > 1 ? 's' : ''}',
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
