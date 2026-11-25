import 'package:flutter/material.dart';

import '../ui/boutons.dart';
import '../ui/feuilles.dart';
import 'corps_activite.dart';

/// Demande le résultat de l'appel qui vient d'être lancé : quatre choix et « Ignorer ». Rend le résultat choisi, ou
/// nul pour « Ignorer » comme pour une fermeture de la feuille (l'appel est journalisé dans les deux cas).
Future<ResultatAppel?> demanderResultatAppel(BuildContext context) =>
    showAppSheet<ResultatAppel>(
      context,
      builder: (_) => const ResultatAppelSheet(),
    );

/// Feuille « Résultat de l'appel ».
class ResultatAppelSheet extends StatelessWidget {
  const ResultatAppelSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return FeuilleBase(
      titre: "Résultat de l'appel",
      children: [
        for (final r in ResultatAppel.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppBouton(
              r.libelle,
              onPressed: () => Navigator.of(context).pop(r),
            ),
          ),
        AppBouton(
          'Ignorer',
          variante: VarianteBouton.tonal,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
