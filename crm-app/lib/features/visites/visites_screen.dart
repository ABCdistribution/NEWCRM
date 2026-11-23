import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/visites_data.dart';
import 'logic/visites_logique.dart';
import 'state/filtres_visites.dart';
import 'widgets/badge_visite.dart';

/// Onglet « Visites » (promoteur) : visites du profil et des autres promoteurs, avec recherche et filtres.
/// Maquette : salesVisites l.1180-1186, visitesListe l.1172-1179.
class VisitesScreen extends ConsumerWidget {
  const VisitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    final f = ref.watch(filtresVisitesProvider);
    final etat = ref.watch(crmProvider);
    final liste = visitesFiltrees(etat, f);
    final nb = liste.length;
    final portee = f.portee == PorteeVisites.mes
        ? 'Mes visites'
        : 'Toutes les visites ${porteeVisites[role]}';
    return PageUnivers(
      entete: AppEntete(
        titre: 'Visites',
        sous: '$portee · $nb résultat${nb > 1 ? 's' : ''}',
        extra: BarreRecherche(
          hint: 'Client${role == Role.promoteur ? '' : ' ou promoteur'}…',
          valeurInitiale: f.q,
          onChanged: (q) => ref
              .read(filtresVisitesProvider.notifier)
              .maj((f) => f.avecRecherche(q)),
          nbFiltres: f.nbActifs,
          onFiltres: () => AppRoutes.filtresVisites(context),
        ),
      ),
      enfants: [
        if (liste.isEmpty)
          const Vide('Aucune visite pour ces filtres.')
        else
          for (final v in liste)
            _CarteVisite(
              ligne: v,
              nomClient: etat.magasinParId(v.magasinId)?.nom ?? '',
            ),
      ],
    );
  }
}

/// Carte d'une visite : client, date (et auteur si ce n'est pas la mienne), pastille d'état. Une visite du profil
/// s'ouvre comme un brouillon ou un compte rendu, celle d'un autre en lecture seule.
class _CarteVisite extends StatelessWidget {
  const _CarteVisite({required this.ligne, required this.nomClient});

  final LigneVisite ligne;
  final String nomClient;

  @override
  Widget build(BuildContext context) {
    final variante = switch (ligne.etat) {
      EtatVisite.brouillon => VariantePastille.gris,
      EtatVisite.terminee => VariantePastille.jaune,
      EtatVisite.envoyee => VariantePastille.vert,
    };
    return AppCarte(
      onTap: () => ligne.propre
          ? AppRoutes.visite(context, ligne.id)
          : AppRoutes.compteRendu(context, ligne.id),
      child: AppLigne(
        alignement: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nomClient, style: AppText.titreCarte),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: ligne.date),
                        if (!ligne.propre) ...[
                          const TextSpan(text: ' · par '),
                          TextSpan(
                            text: ligne.par,
                            style: AppText.t(
                              12.5,
                              w: FontWeight.w700,
                              c: AppColors.texte,
                            ),
                          ),
                        ],
                      ],
                    ),
                    style: AppText.sousCarte,
                  ),
                ),
              ],
            ),
          ),
          if (ligne.pem) ...[const BadgePem(), const SizedBox(width: 6)],
          Pastille(ligne.etat.libelle, variante: variante),
        ],
      ),
    );
  }
}
