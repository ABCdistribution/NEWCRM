import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/state.dart';
import '../../core/ui/ui.dart';
import 'logic/liste_commandes.dart';
import 'state/filtres_commandes.dart';

/// Ouvre la feuille « Filtres ». Maquette : modale `cfiltres` l.1378-1387.
/// Appelée par `AppRoutes.filtresCommandes(context)`.
Future<void> ouvrirFiltresCommandes(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const FiltresCommandesSheet());

/// Feuille « Filtres » : afficher, type de commande (toutes / EDI / appli), état (pas livrée / livrée), période,
/// « Voir N commandes ». Chaque choix s'applique tout de suite à la liste.
class FiltresCommandesSheet extends ConsumerWidget {
  const FiltresCommandesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    final etat = ref.watch(crmProvider);
    final f = ref.watch(filtresCommandesProvider);
    final notifier = ref.read(filtresCommandesProvider.notifier);
    final nb = commandesListe(etat, f).length;
    return FeuilleBase(
      titre: 'Filtres',
      children: [
        const TitreFiltre('Afficher'),
        OptionRadio(
          label: 'Mes commandes',
          selectionne: f.portee == PorteeCommandes.mes,
          onTap: () =>
              notifier.maj((x) => x.copyWith(portee: PorteeCommandes.mes)),
        ),
        OptionRadio(
          label: 'Toutes les commandes',
          detail: '(${porteeTexte(role)})',
          selectionne: f.portee == PorteeCommandes.toutes,
          onTap: () =>
              notifier.maj((x) => x.copyWith(portee: PorteeCommandes.toutes)),
        ),
        const TitreFiltre('Type de commande'),
        for (final (valeur, libelle) in const [
          (TypeCommande.tous, 'Toutes les commandes'),
          (TypeCommande.edi, 'Commandes EDI'),
          (TypeCommande.appli, "Commandes saisies dans l'appli"),
        ])
          OptionRadio(
            label: libelle,
            selectionne: f.type == valeur,
            onTap: () => notifier.maj((x) => x.copyWith(type: valeur)),
          ),
        const TitreFiltre('État'),
        for (final (valeur, libelle) in const [
          (EtatCommande.tous, 'Tous les états'),
          (EtatCommande.pasLivree, 'Pas livrée'),
          (EtatCommande.livree, 'Livrée'),
        ])
          OptionRadio(
            label: libelle,
            selectionne: f.etat == valeur,
            onTap: () => notifier.maj((x) => x.copyWith(etat: valeur)),
          ),
        const TitreFiltre('Période'),
        for (final (valeur, libelle) in const [
          (PeriodeCommandes.toutes, 'Toutes les dates'),
          (PeriodeCommandes.jour, "Aujourd'hui"),
          (PeriodeCommandes.semaine, '7 derniers jours'),
        ])
          OptionRadio(
            label: libelle,
            selectionne: f.periode == valeur,
            onTap: () => notifier.maj((x) => x.copyWith(periode: valeur)),
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
              'Voir $nb commande${nb > 1 ? 's' : ''}',
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
