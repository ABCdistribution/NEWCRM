import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/state/state.dart';
import 'accueil_encadrement.dart';
import 'accueil_promoteur.dart';

/// Onglet « Accueil » de tous les rôles. Maquette : pageAccueil l.671-687 (encadrement),
/// salesAccueil l.1138-1156 (promoteur).
///
/// Le promoteur voit sa tournée de visites, son objectif du mois et le suivi de ses livraisons ; le chef de secteur et le
/// directeur voient leurs RDV du jour, l'objectif de leur secteur ou de leur région et, pour le chef de secteur, les
/// prospects à suivre. Le bandeau « Bonjour » (avatar = changer de profil, cloche = alertes) vient du socle.
class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    return role == Role.promoteur
        ? const AccueilPromoteur()
        : const AccueilEncadrement();
  }
}
