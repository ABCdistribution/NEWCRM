import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/state.dart';
import '../data/attente_demo.dart';
import 'commande_en_cours.dart';

/// Commandes mises en attente, non envoyées (maquette : `S.attente`). Reconstruites à chaque changement de profil.
///
/// Les rangs servent de référence : « Reprendre » retient le rang de la commande reprise (`fromAttente`).
class AttenteNotifier extends Notifier<List<CommandeEnAttente>> {
  @override
  List<CommandeEnAttente> build() {
    ref.watch(roleActifProvider);
    return List.of(attenteDemo);
  }

  /// `cmd-attente` : remplace la commande reprise (`rang`) ou ajoute la nouvelle en tête.
  void mettreDeCote(CommandeEnAttente a, {int? rang}) {
    if (rang != null && rang >= 0 && rang < state.length) {
      state = [for (var i = 0; i < state.length; i++) i == rang ? a : state[i]];
    } else {
      state = [a, ...state];
    }
  }

  /// `att-suppr` et envoi d'une commande reprise : retire la commande de ce rang.
  void retirer(int rang) {
    if (rang < 0 || rang >= state.length) return;
    state = [
      for (var i = 0; i < state.length; i++)
        if (i != rang) state[i],
    ];
  }
}

final attenteProvider =
    NotifierProvider<AttenteNotifier, List<CommandeEnAttente>>(
      AttenteNotifier.new,
    );
