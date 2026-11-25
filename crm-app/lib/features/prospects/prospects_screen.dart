import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/vue_prospects.dart';
import 'state/prospects_state.dart';
import 'widgets/carte_prospect.dart';
import 'widgets/ouvrir_fiche_prospect.dart';
import 'widgets/tuiles_pipeline.dart';

/// Onglet « Prospects » (chef de secteur et directeur). Maquette : pageProspects l.697-715.
///
/// Quatre tuiles de pipeline (À contacter, RDV pris, En négo, Référencé) qui filtrent la liste, un segment
/// « Mes prospects » / « Tout le secteur » (« Tous les prospects » pour le directeur, qui peut aussi filtrer par chef
/// de secteur), les cartes triées par potentiel et le bouton « ＋ Nouveau prospect ».
///
/// Le segment « Mes prospects » / « Timeline » (liste par étape) est celui de la maquette pour un profil qui n'est pas
/// de l'encadrement ; aucun onglet ne l'affiche pour le promoteur, qui n'a pas de prospects.
class ProspectsScreen extends ConsumerWidget {
  const ProspectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    final encadrement = role.peutPilot;
    final directeur = role == Role.dir;
    final vue = ref.watch(vueProspectsProvider);
    final filtre = ref.watch(filtreGroupeProvider);
    final chefs = ref.watch(chefsSecteurRetenusProvider);
    final base = ref.watch(prospectsDeLaVueProvider);
    final etapes = ref.watch(etapesProvider);
    final liste = listeAffichee(base, filtre);
    final tous = vue == VueProspects.tous;
    final nb = base.length;
    final peutCreer = ref.watch(peutCreerProspectProvider);

    final cartes = vue == VueProspects.pipeline
        ? _parEtape(context, liste, etapes)
        : [
            for (final p in liste)
              _carte(context, p, etapes, avecChef: encadrement && tous),
          ];

    return PageUnivers(
      entete: AppEntete(
        titre: directeur ? 'Prospects' : 'Mes prospects',
        sous:
            '$nb point${nb > 1 ? 's' : ''} de vente · potentiel ${kf(potentielTotal(base))} k€/an',
        extra: TuilesPipeline(
          compteurs: {
            for (final g in GroupeProspect.values) g: compterGroupe(base, g),
          },
          retenu: filtre,
          onTap: ref.read(filtreGroupeProvider.notifier).basculer,
        ),
      ),
      enfants: [
        if (encadrement)
          Segment(
            libelles: [
              '☰ Mes prospects',
              '👥 ${directeur ? 'Tous les prospects' : 'Tout le secteur'}',
            ],
            index: tous ? 1 : 0,
            onChanged: (i) => ref
                .read(vueProspectsProvider.notifier)
                .choisir(i == 0 ? VueProspects.liste : VueProspects.tous),
          )
        else
          Segment(
            libelles: const ['☰ Mes prospects', '▥ Timeline'],
            index: vue == VueProspects.pipeline ? 1 : 0,
            onChanged: (i) => ref
                .read(vueProspectsProvider.notifier)
                .choisir(i == 0 ? VueProspects.liste : VueProspects.pipeline),
          ),
        if (directeur && tous)
          _BarreFiltresDirecteur(chefs: chefs, filtre: filtre),
        TitreLigne(
          encadrement
              ? (tous
                    ? (directeur ? 'Tous les prospects' : 'Mon secteur')
                    : 'Mes prospects')
              : (vue == VueProspects.pipeline ? 'Timeline' : 'Mes prospects'),
          droite: Text(
            !encadrement && vue == VueProspects.pipeline
                ? 'Par étape'
                : 'Trié par potentiel',
            style: AppText.t(13, c: AppColors.muted),
          ),
        ),
        if (cartes.isEmpty)
          const Vide('Aucun prospect dans cette colonne.')
        else
          ...cartes,
      ],
      fab: peutCreer
          ? AppFab(
              label: '＋ Nouveau prospect',
              onPressed: () => AppRoutes.nouveauProspect(context),
            )
          : null,
      paddingBasFab: peutCreer,
    );
  }

  Widget _carte(
    BuildContext context,
    Prospect p,
    List<EtapePlanning> etapes, {
    bool avecChef = false,
  }) {
    return CarteProspect(
      prospect: p,
      etapes: etapes,
      avecChef: avecChef,
      onTap: () => ouvrirFicheProspect(context, p),
    );
  }

  /// Vue « Timeline » : les prospects regroupés par étape, avec le nombre de chaque groupe.
  List<Widget> _parEtape(
    BuildContext context,
    List<Prospect> liste,
    List<EtapePlanning> etapes,
  ) {
    final widgets = <Widget>[];
    for (final g in GroupeProspect.values) {
      final l = liste.where((p) => p.groupe == g).toList();
      if (l.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(g.libelle, style: AppText.t(14, w: FontWeight.w800)),
              Text(
                '${l.length}',
                style: AppText.t(14, w: FontWeight.w800, c: AppColors.muted),
              ),
            ],
          ),
        ),
      );
      widgets.addAll([for (final p in l) _carte(context, p, etapes)]);
    }
    return widgets;
  }
}

/// Sélecteur des chefs de secteur retenus et bouton de filtres, sous le segment « Tous les prospects » du directeur.
class _BarreFiltresDirecteur extends StatelessWidget {
  const _BarreFiltresDirecteur({required this.chefs, required this.filtre});

  final List<String> chefs;
  final GroupeProspect? filtre;

  @override
  Widget build(BuildContext context) {
    final libelle =
        '${chefs.isNotEmpty ? chefs.join(', ') : 'Tous les chefs de secteur'}'
        '${filtre != null ? ' · ${filtre!.libelle}' : ''}';
    return Row(
      children: [
        Expanded(
          child: Selecteur(
            libelle,
            ombre: false,
            onTap: () => AppRoutes.filtresProspects(context),
          ),
        ),
        const SizedBox(width: 10),
        BoutonFiltre(
          onTap: () => AppRoutes.filtresProspects(context),
          nbFiltres: (chefs.isNotEmpty ? 1 : 0) + (filtre != null ? 1 : 0),
        ),
      ],
    );
  }
}
