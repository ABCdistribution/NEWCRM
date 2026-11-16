import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/nav/nav.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../accueil_state.dart';

/// « Suivi des livraisons » de l'accueil du promoteur (`blocLivraisons`) : un lien souligné au-dessus de la tournée ;
/// un appui déroule les trois premières commandes pas encore livrées. Rien n'est affiché sans commande en cours.
class BlocLivraisons extends ConsumerWidget {
  const BlocLivraisons({super.key, required this.livraisons});

  final List<Commande> livraisons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (livraisons.isEmpty) return const SizedBox.shrink();
    final ouvert = ref.watch(livraisonsOuvertesProvider);
    final u = context.univers;
    final style = AppText.t(14.5, w: FontWeight.w700, c: u.acc);
    // `.liv-lien` : soulignement de 1,5 px décalé de 4 px sous la ligne de base (`TexteSouligne`).
    Widget souligne(String texte) => TexteSouligne(texte, style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: ref.read(livraisonsOuvertesProvider.notifier).basculer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 12.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: souligne(
                    '🚚 Suivi des livraisons · ${livraisons.length} en cours',
                  ),
                ),
                souligne(ouvert ? '▲' : '▼'),
              ],
            ),
          ),
        ),
        if (ouvert)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in livraisons.take(3)) CarteLivraison(c),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 2.4, 2, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LienTexte(
                      "Voir l'historique des commandes ›",
                      onTap: () =>
                          AppRoutes.allerOnglet(context, OngletApp.commandes),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
