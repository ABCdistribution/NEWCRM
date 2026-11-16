import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/ui/ui.dart';
import 'data/secteur_demo.dart';
import 'filtres_secteur_sheet.dart';
import 'state/equipe_state.dart';
import 'state/filtres.dart';

/// Ouvre la feuille « Choisir un client ». Maquette : modale `sec-client` l.1865-1868.
/// Appelée par `AppRoutes.choixClientSecteur(context, genre)`.
Future<void> ouvrirChoixClientSecteur(
  BuildContext context,
  GenreSecteur genre,
) => showAppSheet<void>(
  context,
  builder: (_) => ChoixClientSecteurSheet(genre: genre),
);

/// Feuille « Choisir un client » : « Tous les clients » puis les clients de la liste du genre, par ordre alphabétique,
/// avec un bouton radio ; hauteur maximale 80 %. Choisir un client l'applique puis revient à la feuille « Filtres ».
class ChoixClientSecteurSheet extends ConsumerWidget {
  const ChoixClientSecteurSheet({super.key, required this.genre});

  /// Visites ou commandes du secteur.
  final GenreSecteur genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choisi = ref.watch(
      filtresSecteurProvider.select((s) => s.de(genre).client),
    );
    void choisir(String client) {
      ref
          .read(filtresSecteurProvider.notifier)
          .maj(genre, (f) => f.copyWith(client: client));
      final nav = Navigator.of(context, rootNavigator: true)..pop();
      ouvrirFiltresSecteur(nav.context, genre);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: FeuilleBase(
        titre: 'Choisir un client',
        children: [
          OptionRadio(
            label: 'Tous les clients',
            selectionne: choisi == filtreTous,
            onTap: () => choisir(filtreTous),
          ),
          for (final c in clientsSecteur(genre))
            OptionRadio(
              label: c,
              selectionne: choisi == c,
              onTap: () => choisir(c),
            ),
        ],
      ),
    );
  }
}
