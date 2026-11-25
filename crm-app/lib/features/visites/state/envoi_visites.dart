import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/state/state.dart';
import '../../../core/ui/ui.dart';

/// Délai entre la validation d'une visite et son « envoi au serveur » simulé (`setTimeout(…, 3500)`).
const Duration delaiEnvoiVisite = Duration(milliseconds: 3500);

/// Simule l'envoi d'une visite validée, en démonstration seulement (connecté, la visite part par la file d'envoi
/// `core/envoi`) : au bout de 3,5 s elle passe de « À envoyer » à « Envoyée » et, pour le promoteur, un message le
/// confirme (maquette : `v-valider-ok`).
class EnvoiVisites {
  EnvoiVisites(this._ref);

  final Ref _ref;
  final List<Timer> _minuteries = [];

  /// Programme l'envoi de la visite `visiteId`. `racine` : contexte d'un écran qui reste affiché
  /// (la coquille), pour le message final.
  void programmer(String visiteId, BuildContext racine) {
    late final Timer minuterie;
    minuterie = Timer(delaiEnvoiVisite, () {
      _minuteries.remove(minuterie);
      final store = _ref.read(crmProvider.notifier);
      final visite = _ref.read(crmProvider).visiteParId(visiteId);
      if (visite == null || visite.etat != EtatVisite.terminee) return;
      store.majVisite(visiteId, (v) => v.copyWith(etat: EtatVisite.envoyee));
      if (_ref.read(roleActifProvider) == Role.promoteur && racine.mounted) {
        AppToast.show(racine, 'Visite envoyée au serveur.');
      }
    });
    _minuteries.add(minuterie);
  }

  void annuler() {
    for (final m in _minuteries) {
      m.cancel();
    }
    _minuteries.clear();
  }
}

/// Service d'envoi des visites ; il est réinitialisé (minuteries annulées) quand le profil change.
final envoiVisitesProvider = Provider<EnvoiVisites>((ref) {
  ref.watch(roleActifProvider);
  final service = EnvoiVisites(ref);
  ref.onDispose(service.annuler);
  return service;
});
