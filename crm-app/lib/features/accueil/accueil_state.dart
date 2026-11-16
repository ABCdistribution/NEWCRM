import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/state.dart';

/// Bloc « Suivi des livraisons » de l'accueil du promoteur déroulé ou replié (maquette : `S.livOuvert`).
///
/// Replié au lancement et à chaque changement de profil ; l'état survit au changement d'onglet.
class LivraisonsOuvertesNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(roleActifProvider);
    return false;
  }

  /// Action `liv-toggle`.
  void basculer() => state = !state;
}

final livraisonsOuvertesProvider =
    NotifierProvider<LivraisonsOuvertesNotifier, bool>(
      LivraisonsOuvertesNotifier.new,
    );
