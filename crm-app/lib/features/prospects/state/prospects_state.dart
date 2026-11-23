/// État de la page « Prospects » : vue, tuile choisie, chefs de secteur retenus (maquette : `S.vue`, `S.filtre`, `S.pvCs`).
///
/// Tout se réinitialise quand on change de profil, comme `etatInitial()`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/dates.dart';
import '../../../core/models/models.dart';
import '../../../core/state/state.dart';
import '../logic/vue_prospects.dart';

/// Vue affichée : « Mes prospects » au départ.
class VueProspectsNotifier extends Notifier<VueProspects> {
  @override
  VueProspects build() {
    ref.watch(roleActifProvider);
    return VueProspects.liste;
  }

  void choisir(VueProspects vue) => state = vue;
}

final vueProspectsProvider =
    NotifierProvider<VueProspectsNotifier, VueProspects>(
      VueProspectsNotifier.new,
    );

/// Groupe du pipeline retenu par une tuile ou par la feuille de filtres (`S.filtre`) ; nul = tous.
class FiltreGroupeNotifier extends Notifier<GroupeProspect?> {
  @override
  GroupeProspect? build() {
    ref.watch(roleActifProvider);
    return null;
  }

  /// Toucher la tuile du groupe déjà retenu l'enlève (`filtre`).
  void basculer(GroupeProspect groupe) =>
      state = state == groupe ? null : groupe;

  void definir(GroupeProspect? groupe) => state = groupe;
}

final filtreGroupeProvider =
    NotifierProvider<FiltreGroupeNotifier, GroupeProspect?>(
      FiltreGroupeNotifier.new,
    );

/// Chefs de secteur retenus dans « Tous les prospects » du directeur (`S.pvCs`) ; vide = tous.
class ChefsSecteurRetenusNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref.watch(roleActifProvider);
    return const [];
  }

  /// Ajoute le chef de secteur s'il n'est pas retenu, le retire sinon (`pv-cs`).
  void basculer(String nom) => state = state.contains(nom)
      ? state.where((x) => x != nom).toList()
      : [...state, nom];

  void vider() => state = const [];
}

final chefsSecteurRetenusProvider =
    NotifierProvider<ChefsSecteurRetenusNotifier, List<String>>(
      ChefsSecteurRetenusNotifier.new,
    );

/// Dernière valeur affichée de chaque compteur de tuile (`CNT_PREC`) : un compteur part de là et rejoint la nouvelle
/// valeur. Mémoire partagée par toute l'application, comme dans la maquette, qui ne la réinitialise jamais.
final compteursPrecProvider = Provider<Map<String, int>>((ref) => {});

/// Prospects de la vue courante (`baseVue`), pour la page et pour la feuille de filtres.
final prospectsDeLaVueProvider = Provider<List<Prospect>>((ref) {
  final role = ref.watch(roleActifProvider);
  return prospectsDeLaVue(
    prospects: ref.watch(prospectsProvider),
    role: role,
    nomProfil: ref.watch(crmProvider.select((e) => e.nomProfil)),
    responsableCrm: DemoTemps.reel,
    vue: ref.watch(vueProspectsProvider),
    chefsSecteur: ref.watch(chefsSecteurRetenusProvider),
  );
});
