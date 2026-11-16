import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/ui/ui.dart';

/// Liste des écarts prévu / réalisé (`ecartsListe`) : un rond de couleur avec son symbole, le titre de la ligne et
/// « Libellé · détail » dessous. Triée : retirés, non réalisés, déplacés, ajoutés, à faire, faits.
class EcartsListe extends StatelessWidget {
  const EcartsListe(this.ecarts, {super.key});

  final List<EcartPlanning> ecarts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final e in ecartsTries(ecarts))
          LigneEcart(
            titre: e.titre,
            detail: e.sousTitre,
            symbole: stylesEcart[e.genre]!.symbole,
            fond: Color(stylesEcart[e.genre]!.fond),
            texte: Color(stylesEcart[e.genre]!.texte),
          ),
      ],
    );
  }
}
