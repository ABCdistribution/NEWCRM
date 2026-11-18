import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/nav/nav.dart';
import '../../core/ui/ui.dart';
import 'data/secteur_demo.dart';
import 'state/equipe_state.dart';
import 'widgets/lignes_equipe.dart';

/// Onglet « Visites » ou « Commandes » du secteur (chef de secteur, menu « + »). Maquette : pageSecteur l.922-932.
///
/// Lecture seule : les visites ou commandes de Nadia H. (« Moi ») et de ses promoteurs, les plus récentes d'abord,
/// filtrées par la feuille « Filtres » (`AppRoutes.filtresSecteur`).
class SecteurScreen extends ConsumerWidget {
  const SecteurScreen({super.key, required this.genre});

  final GenreSecteur genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visites = genre == GenreSecteur.visites;
    final f = ref.watch(filtresSecteurProvider.select((s) => s.de(genre)));
    final moi = ref.watch(sessionProvider)?.nomAffiche ?? '';
    final liste = listeSecteur(
      genre,
      f,
      etat: ref.watch(crmProvider),
      moiNom: moi,
    );
    final n = liste.length;
    return PageUnivers(
      entete: AppEntete(
        titre: visites ? 'Visites' : 'Commandes',
        tailleTitre: 24,
        sous:
            '$n ${visites ? 'visite' : 'commande'}${n > 1 ? 's' : ''} · les plus récentes en premier',
        extra: BarreFiltres(
          resume: f.resume(genre),
          nbFiltres: f.nb,
          onFiltres: () => AppRoutes.filtresSecteur(context, genre),
        ),
      ),
      enfants: [
        if (liste.isEmpty)
          const Vide('Aucun résultat avec ces filtres.')
        else
          for (final x in liste)
            switch (x) {
              VisiteSecteur() => CarteVisiteLecture(
                client: x.client,
                detail: '${x.date} · ${x.moi ? 'Moi' : x.qui}',
                enCours: x.enCours,
              ),
              CommandeSecteur() => CarteCommandeLecture(
                ht: x.ht,
                detail:
                    '${x.id} · ${x.client} · ${x.date} · ${x.moi ? 'Moi' : x.qui} · ${x.src}',
                statut: x.statut,
              ),
            },
        Pied('Lecture seule.', centre: true, margeHaut: liste.isEmpty ? 8 : 0),
      ],
    );
  }
}
