import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/nav/nav.dart';
import '../../../core/state/state.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../accueil_logique.dart';

/// Variante de pastille d'un groupe du pipeline (maquette : `classePast`).
VariantePastille variantePastilleGroupe(GroupeProspect? g) => switch (g) {
  GroupeProspect.aContacter || null => VariantePastille.gris,
  GroupeProspect.rdvPris => VariantePastille.bleu,
  GroupeProspect.enNego => VariantePastille.jaune,
  GroupeProspect.reference => VariantePastille.vert,
};

/// Ouvre la fiche d'un prospect ; un prospect créé sur le téléphone et pas encore envoyé n'a pas de fiche
/// (maquette : action `fiche-prospect`).
void ouvrirFicheProspect(BuildContext context, Prospect p) {
  if (p.attente) {
    AppToast.show(
      context,
      "Ce prospect n'est pas encore envoyé : sa fiche s'ouvrira dès son envoi.",
    );
    return;
  }
  AppRoutes.ficheProspect(context, p.id);
}

/// « Prospects à suivre » : l'essentiel des prospects du chef de secteur sur son accueil (`blocProspectsCS`).
class BlocProspectsASuivre extends ConsumerWidget {
  const BlocProspectsASuivre({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(crmProvider);
    final u = context.univers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TitreLigne(
          'Prospects à suivre',
          lien: 'Voir tous',
          onLien: () => AppRoutes.allerOnglet(context, OngletApp.prospects),
        ),
        for (final p in prospectsASuivre(etat.prospects))
          AppCarte(
            onTap: () => ouvrirFicheProspect(context, p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppLigne(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nom, style: AppText.titreCarte),
                          const SizedBox(height: 3),
                          Text(
                            'Classe ${p.classe} · probabilité ${p.proba} %',
                            style: AppText.sousCarte,
                          ),
                        ],
                      ),
                    ),
                    Pastille(
                      p.groupe?.libelle ?? '',
                      variante: variantePastilleGroupe(p.groupe),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Potentiel ',
                                style: TextStyle(color: AppColors.muted),
                              ),
                              TextSpan(
                                text: '${kf(p.pot)} k€/an',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          style: AppText.t(13),
                        ),
                      ),
                      ..._action(etat.etapes, p, u),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Prochaine action prévue pour le prospect, en violet à droite de la ligne (`prochaineAction`).
  List<Widget> _action(
    List<EtapePlanning> etapes,
    Prospect p,
    UniversPalette u,
  ) {
    final texte = prochaineAction(p, etapes);
    if (texte == null) return const [];
    return [
      Flexible(
        child: Text(
          texte,
          style: AppText.t(12.5, w: FontWeight.w700, c: u.violet),
        ),
      ),
    ];
  }
}
