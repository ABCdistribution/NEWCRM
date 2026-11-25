import 'dart:async';

import 'package:crm_app/core/ui/ui.dart';

/// Lanceur d'applications externes pour les tests : garde les adresses demandées au lieu de les ouvrir.
/// `reussit` faux simule un téléphone sans application pour gérer l'adresse.
class LanceurFactice implements LanceurExterne {
  LanceurFactice({this.reussit = true});

  final bool reussit;
  final List<Uri> ouverts = [];

  @override
  Future<bool> ouvrir(Uri uri) async {
    ouverts.add(uri);
    return reussit;
  }
}

/// Surveillant de retour commandé par le test : `reviens()` simule le retour de l'utilisateur dans l'application,
/// `delaiEcoule()` la fin du délai de sécurité sans retour.
class SurveillantFactice implements SurveillantRetour {
  final List<AttenteFactice> attentes = [];

  @override
  AttenteRetour? surveiller() {
    final a = AttenteFactice();
    attentes.add(a);
    return a;
  }

  void reviens() => attentes.last.terminer(true);

  void delaiEcoule() => attentes.last.terminer(false);
}

class AttenteFactice implements AttenteRetour {
  final Completer<bool> _fin = Completer<bool>();
  bool annulee = false;

  @override
  Future<bool> get retour => _fin.future;

  @override
  void annuler() {
    annulee = true;
    terminer(false);
  }

  void terminer(bool revenu) {
    if (!_fin.isCompleted) _fin.complete(revenu);
  }
}
