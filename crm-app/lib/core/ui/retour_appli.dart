import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Délai de sécurité : passé ce temps sans retour dans l'application, l'attente est abandonnée.
const Duration delaiRetourAppli = Duration(minutes: 30);

/// Attente du retour de l'utilisateur dans l'application après le lancement d'une application externe (téléphone).
abstract interface class AttenteRetour {
  /// Vrai quand l'application repasse au premier plan après l'avoir quitté ; faux si le délai de sécurité est écoulé
  /// ou si l'attente est annulée.
  Future<bool> get retour;

  /// Abandonne l'attente (lancement en échec, écran quitté) : rien n'est plus observé.
  void annuler();
}

/// Fabrique d'attentes de retour, remplaçable en test (`surveillantRetourProvider.overrideWithValue(...)`).
abstract interface class SurveillantRetour {
  /// Commence à observer le cycle de vie de l'application ; à appeler AVANT de lancer l'application externe, pour ne
  /// manquer aucun passage en arrière-plan. Nul si le retour n'est pas détectable (plateforme ou test sans cycle de
  /// vie) : l'appelant garde alors son comportement immédiat.
  AttenteRetour? surveiller();
}

/// Surveillant réel : un `WidgetsBindingObserver` éphémère, retiré après usage ou à l'échéance du délai.
class SurveillantCycleDeVie implements SurveillantRetour {
  const SurveillantCycleDeVie({this.delai = delaiRetourAppli});

  final Duration delai;

  @override
  AttenteRetour? surveiller() {
    final binding = WidgetsBinding.instance;
    // Sans état de cycle de vie connu (tests, plateforme sans cycle de vie), le retour n'est pas observable.
    if (binding.lifecycleState == null) return null;
    return ObservateurRetour(binding, delai: delai);
  }
}

/// Observateur éphémère : « parti » dès que l'application quitte le premier plan (inactive, hidden, paused), puis
/// l'attente aboutit au premier `resumed`. `didChangeAppLifecycleState` est public : un test peut le simuler.
class ObservateurRetour with WidgetsBindingObserver implements AttenteRetour {
  ObservateurRetour(this._binding, {this.delai = delaiRetourAppli}) {
    _binding.addObserver(this);
    _minuteur = Timer(delai, () => _finir(false));
  }

  final WidgetsBinding _binding;
  final Duration delai;
  final Completer<bool> _fin = Completer<bool>();
  Timer? _minuteur;
  bool _parti = false;

  @override
  Future<bool> get retour => _fin.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_parti) _finir(true);
    } else {
      _parti = true;
    }
  }

  @override
  void annuler() => _finir(false);

  void _finir(bool revenu) {
    if (_fin.isCompleted) return;
    _minuteur?.cancel();
    _binding.removeObserver(this);
    _fin.complete(revenu);
  }
}

final surveillantRetourProvider = Provider<SurveillantRetour>(
  (ref) => const SurveillantCycleDeVie(),
);
