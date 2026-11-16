import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/nav/nav.dart';
import '../../../core/ui/ui.dart';

/// Ouvre la fiche d'un prospect ; un prospect créé sur le téléphone et pas encore envoyé n'a pas de fiche
/// (maquette : action `fiche-prospect`, l.1989).
void ouvrirFicheProspect(BuildContext context, Prospect p) {
  if (p.attente) {
    AppToast.show(
      context,
      "Ce prospect n'est pas encore envoyé : sa fiche s'ouvrira dès son envoi.",
    );
    return;
  }
  AppRoutes.ficheProspect(context, p.id);
}
