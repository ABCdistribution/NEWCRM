import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/ui/ui.dart';
import 'logic/regles_commande.dart';
import 'state/commande_provider.dart';

/// Ouvre la feuille « Filtres ». Maquette : modale `cmd-filtres` l.1416-1423.
/// Appelée par `AppRoutes.filtresPriseCommande(context)`.
Future<void> ouvrirFiltresPriseCommande(BuildContext context) =>
    showAppSheet<void>(
      context,
      builder: (_) => const FiltresPriseCommandeSheet(),
    );

/// Feuille « Filtres » : marque, interrupteur « Masquer les produits en rupture », « Voir N produits ».
class FiltresPriseCommandeSheet extends ConsumerWidget {
  const FiltresPriseCommandeSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cmd = ref.watch(commandeEnCoursProvider);
    final notifier = ref.read(commandeEnCoursProvider.notifier);
    final cat = cmd?.cat;
    final masquer = cmd?.masquer ?? false;
    final nb = nbProduitsFiltres(cat: cat, masquer: masquer);
    return FeuilleBase(
      titre: 'Filtres',
      children: [
        const TitreFiltre('Marque'),
        for (final marque in <String?>[null, ...marquesCatalogueActuelles()])
          OptionRadio(
            label: marque ?? 'Toutes les marques',
            selectionne: cat == marque,
            onTap: () => notifier.choisirMarque(marque),
          ),
        const TitreFiltre('Autres'),
        LigneSwitch(
          label: 'Masquer les produits en rupture',
          valeur: masquer,
          onChanged: (_) => notifier.basculerMasquer(),
        ),
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Réinitialiser',
              petit: true,
              onPressed: notifier.reinitialiserFiltres,
            ),
            AppBouton(
              'Voir $nb produit${nb > 1 ? 's' : ''}',
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
