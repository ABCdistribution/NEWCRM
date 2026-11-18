import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/planning_equipe_provider.dart';
import 'planning_equipe.dart';

/// Planning en lecture seule d'un membre de l'équipe venu du CRM, semaine par semaine.
///
/// - `promoteur` vrai : ses visites planifiées (`GET /plannings?promoteurId=…`) ;
/// - sinon (chef de secteur, directeur régional) : sa tournée (`GET /tournees/user/:id`).
///
/// Le planning est chargé à l'ouverture (copie locale d'abord, puis réponse fraîche) sur quelques semaines autour de
/// la semaine courante ; le périmètre est celui que renvoie l'API. `semaine` est le décalage par rapport à la semaine
/// courante, `onSemaine` reçoit -1 ou +1. `apres` s'affiche sous les lignes (carte du rapport d'activité).
class PlanningEquipeReel extends ConsumerWidget {
  const PlanningEquipeReel({
    super.key,
    required this.userId,
    required this.promoteur,
    required this.semaine,
    required this.onSemaine,
    this.apres,
  });

  /// Identifiant (UUID) de l'utilisateur dans le CRM.
  final String userId;
  final bool promoteur;
  final int semaine;
  final ValueChanged<int> onSemaine;
  final Widget? apres;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = ref.watch(
      planningUtilisateurProvider((userId: userId, promoteur: promoteur)),
    );
    final plan = charge.value;
    return VuePlanningEquipe(
      plan: plan ?? const [],
      semaine: semaine,
      onSemaine: onSemaine,
      lecture: true,
      apres: apres,
      message: plan != null
          ? null
          : charge.isLoading
          ? 'Chargement du planning…'
          : 'Planning indisponible : réseau coupé et aucune copie locale.',
    );
  }
}
