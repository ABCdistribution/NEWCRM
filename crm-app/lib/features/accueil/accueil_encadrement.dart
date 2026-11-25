import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/equipe_serveur.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/ui/ui.dart';
import 'widgets/bloc_envoi.dart';
import 'widgets/bloc_prospects_a_suivre.dart';
import 'widgets/carte_etape_accueil.dart';

/// Accueil du chef de secteur et du directeur (maquette : `pageAccueil` l.671-687 et `blocProspectsCS` l.665-670) :
/// tuiles « RDV du jour », « Prospects » (chef de secteur) et « CA / objectif », bloc « Prospects à suivre »
/// (chef de secteur) puis « Ma tournée du jour ».
class AccueilEncadrement extends ConsumerWidget {
  const AccueilEncadrement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    final etat = ref.watch(crmProvider);
    final jour = ref.watch(jourPlanningProvider);
    final cs = role == Role.cs;
    final lignes = lignesDuJour(etat.etapes, jour);
    final faites = lignes.where((e) => e.fait).length;
    final prochain = lignes.where((e) => !e.fait).firstOrNull;
    final total = totalEquipe(chefSecteur: cs);
    return PageUnivers(
      entete: AppEntete.libre(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BandeauBonjour(),
            TuilesRangee([
              Tuile(libelle: 'RDV du jour', valeur: '$faites/${lignes.length}'),
              if (cs)
                Tuile(
                  libelle: 'Prospects',
                  valeur: '${etat.prospects.length}',
                  onTap: () =>
                      AppRoutes.allerOnglet(context, OngletApp.prospects),
                ),
              Tuile(
                flex: 2,
                libelle: 'CA / objectif${cs ? ' du mois' : ' · région'}',
                valeur: eur(total.real),
                complement: '/ ${eur(total.cible)}',
                nowrap: true,
                tailleValeur: cs ? 16 : 19,
                tailleComplement: cs ? 11 : 13,
                poidsComplement: FontWeight.w600,
                opaciteComplement: 0.7,
                child: BarreObjectif(real: total.real, cible: total.cible),
              ),
            ]),
          ],
        ),
      ),
      enfants: [
        const BlocEnvoi(),
        if (cs) const BlocProspectsASuivre(),
        TitreLigne(
          'Ma tournée du jour',
          lien: 'Voir mon planning',
          onLien: () => AppRoutes.allerOnglet(context, OngletApp.planning),
        ),
        if (lignes.isEmpty)
          const Vide("Aucune étape aujourd'hui. Ajoutez un RDV ci-dessous.")
        else
          for (final e in lignes)
            CarteEtapeAccueil(etape: e, prochain: e.id == prochain?.id),
      ],
    );
  }
}
