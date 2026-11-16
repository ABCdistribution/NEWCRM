import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../models/models.dart';

/// Profil de démonstration choisi au lancement. Nul tant que l'écran de choix est affiché.
///
/// Dans un test : `roleProvider.overrideWith(() => RoleNotifier(Role.promoteur))`.
class RoleNotifier extends Notifier<Role?> {
  RoleNotifier([this._initial]);
  final Role? _initial;

  @override
  Role? build() => _initial;

  /// Choisit un profil (réinitialise tout l'état partagé : le store dépend de ce provider).
  void choisir(Role role) => state = role;

  /// Revient à l'écran de choix du profil.
  void reinitialiser() => state = null;
}

final roleProvider = NotifierProvider<RoleNotifier, Role?>(RoleNotifier.new);

/// Rôle courant, jamais nul (directeur si aucun choix, comme la maquette : `ROLE = 'dir'`).
final roleActifProvider = Provider<Role>(
  (ref) => ref.watch(roleProvider) ?? Role.dir,
);

/// Identité du profil courant (prénom, nom court, initiales, libellé).
final profilActifProvider = Provider<Profil>(
  (ref) => ref.watch(roleActifProvider).profil,
);

/// Univers visuel du profil : « sales » (promoteur) ou « pilot » (chef de secteur, directeur).
final universProvider = Provider<Univers>(
  (ref) => ref.watch(roleActifProvider).univers,
);

/// Jour affiché dans le planning et dans « Ma tournée du jour » de l'accueil (0 = lundi, 2 = mercredi).
/// Comme dans la maquette, choisir un jour dans le planning change aussi celui de l'accueil.
class JourPlanningNotifier extends Notifier<int> {
  @override
  int build() {
    ref.watch(
      roleActifProvider,
    ); // retour au mercredi à chaque changement de profil
    return DemoTemps.jourPlanning;
  }

  void choisir(int jour) => state = jour;
}

final jourPlanningProvider = NotifierProvider<JourPlanningNotifier, int>(
  JourPlanningNotifier.new,
);
