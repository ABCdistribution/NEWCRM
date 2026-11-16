import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/models/models.dart';
import '../../core/ui/ui.dart';
import 'state/filtres_catalogue_state.dart';

/// Ouvre la feuille « Filtres ». Maquette : modale `sfiltres` l.1401-1409.
/// Appelée par `AppRoutes.filtresCatalogue(context)`.
Future<void> ouvrirFiltresCatalogue(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const FiltresCatalogueSheet());

/// Feuille « Filtres » : marque, stock, interrupteurs En promotion / Mis en avant / Kits / Produits PEM, « Voir N produits ».
///
/// Chaque choix s'applique tout de suite à la liste du catalogue ; le bouton « Voir N produits » ferme la feuille.
class FiltresCatalogueSheet extends ConsumerWidget {
  const FiltresCatalogueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtresCatalogueProvider);
    final nb = ref.watch(produitsFiltresProvider).length;
    final store = ref.read(filtresCatalogueProvider.notifier);

    return FeuilleBase(
      titre: 'Filtres',
      children: [
        const TitreFiltre('Marque'),
        OptionRadio(
          label: 'Toutes les marques',
          selectionne: f.marque == null,
          onTap: () => store.choisirMarque(null),
        ),
        for (final m in marquesCatalogueActuelles())
          OptionRadio(
            label: m,
            selectionne: f.marque == m,
            onTap: () => store.choisirMarque(m),
          ),
        const TitreFiltre('Stock'),
        OptionRadio(
          label: 'Tous les stocks',
          selectionne: f.stock == null,
          onTap: () => store.choisirStock(null),
        ),
        for (final s in NiveauStock.values)
          OptionRadio(
            label: s.libelle,
            selectionne: f.stock == s,
            onTap: () => store.choisirStock(s),
          ),
        const TitreFiltre('Autres'),
        LigneSwitch(
          label: 'En promotion',
          valeur: f.promo,
          onChanged: (_) => store.basculerPromo(),
        ),
        LigneSwitch(
          label: 'Mis en avant',
          valeur: f.avant,
          onChanged: (_) => store.basculerAvant(),
        ),
        LigneSwitch(
          label: 'Kits',
          valeur: f.kit,
          onChanged: (_) => store.basculerKit(),
        ),
        LigneSwitch(
          label: 'Produits PEM',
          valeur: f.pem,
          onChanged: (_) => store.basculerPem(),
        ),
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Réinitialiser',
              petit: true,
              onPressed: store.reinitialiser,
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
