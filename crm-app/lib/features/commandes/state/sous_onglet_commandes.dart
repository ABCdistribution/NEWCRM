import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/state.dart';

/// Sous-onglets de l'écran Commandes du promoteur connecté : le suivi de livraison et les commandes en attente.
enum SousOngletCommandes { suivi, attente }

class SousOngletCommandesNotifier extends Notifier<SousOngletCommandes> {
  @override
  SousOngletCommandes build() {
    ref.watch(roleActifProvider);
    return SousOngletCommandes.suivi;
  }

  void choisir(SousOngletCommandes s) => state = s;
}

final sousOngletCommandesProvider =
    NotifierProvider<SousOngletCommandesNotifier, SousOngletCommandes>(
      SousOngletCommandesNotifier.new,
    );
