import '../../core/data/equipe_serveur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/ui/ui.dart';
import 'choix_client_secteur_sheet.dart';
import 'state/equipe_state.dart';
import 'state/filtres.dart';

/// Ouvre la feuille « Filtres ». Maquette : modale `sec-filtres` l.1845-1853.
/// Appelée par `AppRoutes.filtresSecteur(context, genre)`.
Future<void> ouvrirFiltresSecteur(BuildContext context, GenreSecteur genre) =>
    showAppSheet<void>(
      context,
      builder: (_) => FiltresSecteurSheet(genre: genre),
    );

/// Feuille « Filtres » des visites ou des commandes du secteur : afficher tout le secteur ou « mes » éléments, un
/// promoteur, le type de commande (commandes seulement) et un client (feuille `ChoixClientSecteurSheet`).
/// Chaque choix s'applique aussitôt à la liste ; « Réinitialiser » ne touche qu'à la liste du genre.
class FiltresSecteurSheet extends ConsumerWidget {
  const FiltresSecteurSheet({super.key, required this.genre});

  /// Visites ou commandes du secteur.
  final GenreSecteur genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(filtresSecteurProvider.select((s) => s.de(genre)));
    final notifier = ref.read(filtresSecteurProvider.notifier);
    final vis = genre == GenreSecteur.visites;
    void maj(FiltreSecteur Function(FiltreSecteur) change) =>
        notifier.maj(genre, change);
    return FeuilleBase(
      titre: 'Filtres',
      children: [
        const TitreFiltre('Afficher'),
        OptionRadio(
          label: vis
              ? 'Toutes les visites de mon secteur'
              : 'Toutes les commandes de mon secteur',
          selectionne: f.portee == PorteeSecteur.secteur,
          onTap: () => maj((x) => x.copyWith(portee: PorteeSecteur.secteur)),
        ),
        OptionRadio(
          label: vis ? 'Mes visites' : 'Mes commandes',
          selectionne: f.portee == PorteeSecteur.moi,
          onTap: () => maj((x) => x.copyWith(portee: PorteeSecteur.moi)),
        ),
        const TitreFiltre('Promoteur'),
        OptionRadio(
          label: 'Tous les promoteurs',
          selectionne: f.promo == filtreTous,
          onTap: () => maj((x) => x.copyWith(promo: filtreTous)),
        ),
        for (final p in promoteursDeMonEquipe())
          OptionRadio(
            label: p.nom,
            selectionne: f.promo == p.nom,
            onTap: () => maj((x) => x.copyWith(promo: p.nom)),
          ),
        if (!vis) ...[
          const TitreFiltre('Type de commande'),
          for (final s in SourceCommande.values)
            OptionRadio(
              label: s.libelle,
              selectionne: f.src == s,
              onTap: () => maj((x) => x.copyWith(src: s)),
            ),
        ],
        const TitreFiltre('Client'),
        Selecteur(
          f.client == filtreTous ? 'Tous les clients' : f.client,
          ombre: false,
          onTap: () {
            // Une seule feuille à la fois, comme la modale de la maquette : celle-ci cède la place au choix du client.
            final nav = Navigator.of(context, rootNavigator: true)..pop();
            ouvrirChoixClientSecteur(nav.context, genre);
          },
        ),
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Réinitialiser',
              petit: true,
              onPressed: () => notifier.reinitialiser(genre),
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
