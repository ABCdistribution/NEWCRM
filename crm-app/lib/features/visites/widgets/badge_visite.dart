import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/ui/ui.dart';

/// Badge d'état d'une visite à côté du titre d'un écran : « En cours », « À envoyer », « Envoyée » (`badgeV`).
class BadgeVisite extends StatelessWidget {
  const BadgeVisite(this.etat, {super.key});

  final EtatVisite etat;

  @override
  Widget build(BuildContext context) {
    final couleur = switch (etat) {
      EtatVisite.brouillon => const Color(0xFF059669),
      EtatVisite.terminee => const Color(0xFF2563EB),
      EtatVisite.envoyee => const Color(0xFF059669),
    };
    return BadgeEtat(etat.libelleBadge, couleur: couleur);
  }
}
