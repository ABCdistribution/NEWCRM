import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/state.dart';

/// Relevés de kilométrage de la journée et dialogues déjà proposés (maquette : `S.km`).
class Kilometrage {
  const Kilometrage({
    this.depart,
    this.arrivee,
    this.departPropose = false,
    this.arriveePropose = false,
  });

  /// Relevé de départ, nul tant qu'il n'est pas enregistré.
  final int? depart;
  final int? arrivee;

  /// Le dialogue de départ a déjà été montré (`vu.depart`) : il ne l'est qu'une fois.
  final bool departPropose;
  final bool arriveePropose;

  Kilometrage copyWith({
    int? depart,
    int? arrivee,
    bool? departPropose,
    bool? arriveePropose,
  }) => Kilometrage(
    depart: depart ?? this.depart,
    arrivee: arrivee ?? this.arrivee,
    departPropose: departPropose ?? this.departPropose,
    arriveePropose: arriveePropose ?? this.arriveePropose,
  );
}

/// Kilométrage de la journée ; il repart de zéro quand le profil change.
class KilometrageNotifier extends Notifier<Kilometrage> {
  @override
  Kilometrage build() {
    ref.watch(roleActifProvider);
    return const Kilometrage();
  }

  void maj(Kilometrage Function(Kilometrage k) transformer) =>
      state = transformer(state);
}

final kilometrageProvider = NotifierProvider<KilometrageNotifier, Kilometrage>(
  KilometrageNotifier.new,
);
