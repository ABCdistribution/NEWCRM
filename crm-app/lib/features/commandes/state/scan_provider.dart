import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rang du prochain produit « scanné » (maquette : `scanSuiv`). Comme dans la maquette, ce compteur n'est
/// remis à zéro ni par une nouvelle commande ni par un changement de profil.
class ScanSuivantNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Renvoie le rang courant et passe au suivant.
  int prochain() {
    final r = state;
    state = r + 1;
    return r;
  }
}

final scanSuivantProvider = NotifierProvider<ScanSuivantNotifier, int>(
  ScanSuivantNotifier.new,
);
