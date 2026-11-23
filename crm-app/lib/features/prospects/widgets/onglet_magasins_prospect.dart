import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/nav/nav.dart';
import '../../../core/state/state.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../logic/magasins_enseigne.dart';
import 'ouvrir_fiche_prospect.dart';

/// Onglet « Magasins » de la fiche d'un prospect : les points de vente de la même enseigne (clients, prospects, magasins
/// à prospecter) avec leur nombre. Maquette : `ongletMagasinsProspect` l.1768-1775.
///
/// Un client ouvre sa fiche, un prospect la sienne ; un magasin « À prospecter » n'a pas d'action.
class OngletMagasinsProspect extends ConsumerWidget {
  const OngletMagasinsProspect({super.key, required this.prospect});

  final Prospect prospect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(crmProvider);
    final lignes = magasinsDeLEnseigne(
      prospect,
      prospects: etat.prospects,
      clients: [...etat.tousMagasins, ...autresClientsActuels()],
    );
    int compter(TypeMagasinEnseigne t) =>
        lignes.where((x) => x.type == t).length;
    final base = AppText.t(13);
    final gras = AppText.t(13, w: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TitreLigne(
          "Magasins de l'enseigne",
          margeHaut: 20,
          droite: Text(
            '${lignes.length} points de vente',
            style: AppText.t(12.5, c: AppColors.muted),
          ),
        ),
        AppCarte(
          margeBas: 8,
          child: Text.rich(
            TextSpan(
              style: base,
              children: [
                TextSpan(
                  text: '${compter(TypeMagasinEnseigne.client)}',
                  style: gras,
                ),
                const TextSpan(text: ' clients · '),
                TextSpan(
                  text: '${compter(TypeMagasinEnseigne.prospect)}',
                  style: gras,
                ),
                const TextSpan(text: ' prospects · '),
                TextSpan(
                  text: '${compter(TypeMagasinEnseigne.aProspecter)}',
                  style: gras,
                ),
                const TextSpan(text: ' à prospecter'),
              ],
            ),
          ),
        ),
        for (final x in lignes) _CarteMagasin(ligne: x),
        const Pied(
          "Liste fournie par l'API · aucune action possible sur les magasins pour l'instant.",
          centre: true,
          margeHaut: 0,
        ),
      ],
    );
  }
}

class _CarteMagasin extends ConsumerWidget {
  const _CarteMagasin({required this.ligne});

  final MagasinEnseigne ligne;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final x = ligne;
    final pastille = switch (x.type) {
      TypeMagasinEnseigne.client => const Pastille(
        'Client',
        variante: VariantePastille.vert,
      ),
      TypeMagasinEnseigne.prospect => Pastille(
        x.detail,
        variante: VariantePastille.violet,
      ),
      TypeMagasinEnseigne.aProspecter => const Pastille(
        'À prospecter',
        variante: VariantePastille.bleu,
      ),
    };
    return AppCarte(
      onTap: switch (x.type) {
        TypeMagasinEnseigne.prospect => () {
          final p = ref.read(prospectParIdProvider(x.prospectId!));
          if (p != null) ouvrirFicheProspect(context, p);
        },
        TypeMagasinEnseigne.client => () => AppRoutes.ficheMagasin(
          context,
          x.magasinId!,
        ),
        TypeMagasinEnseigne.aProspecter => null,
      },
      child: AppLigne(
        alignement: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(x.nom, style: AppText.titreCarte),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    x.type == TypeMagasinEnseigne.client
                        ? '${x.ville} · ${x.detail}'
                        : x.ville,
                    style: AppText.sousCarte,
                  ),
                ),
              ],
            ),
          ),
          pastille,
        ],
      ),
    );
  }
}
