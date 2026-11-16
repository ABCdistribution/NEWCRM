import 'package:flutter/material.dart';

import '../../core/logic/logic.dart';
import '../../core/ui/ui.dart';
import 'widgets/lignes_equipe.dart';

/// Activité du mois d'un membre de l'équipe venue du CRM : visites, commandes, CA réalisé et objectif. Lecture seule ;
/// le planning, les visites et les commandes détaillés ne sont pas encore repris du CRM.
class ResumeActivite extends StatelessWidget {
  const ResumeActivite({
    super.key,
    required this.titre,
    required this.sous,
    required this.visites,
    required this.commandes,
    required this.ca,
    required this.objectif,
    this.enfants = const [],
  });

  final String titre;
  final String sous;
  final int visites;
  final int commandes;
  final double ca;
  final double objectif;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    final taux = objectif <= 0 ? 0 : (ca / objectif * 100).round();
    return PageUnivers(
      entete: TopbarEcran(titre: titre, sous: sous),
      paddingCorps: false,
      corps: CorpsSousTopbar(
        children: [
          KpiRangee([
            KpiItem('Visites du mois', '$visites'),
            KpiItem('Commandes du mois', '$commandes'),
          ]),
          KpiRangee([
            KpiItem(
              'Réalisé',
              eur(ca),
              couleurValeur: objectif <= 0 ? null : couleurObjectif(taux),
            ),
            KpiItem('Objectif', objectif <= 0 ? '—' : eur(objectif)),
          ]),
          ...enfants,
        ],
      ),
    );
  }
}
