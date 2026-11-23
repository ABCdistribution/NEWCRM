/// Produits indispensables de démonstration : la liste d'une enseigne, ici attachée à un magasin de la démo.
library;

import 'produits_demo.dart';
import 'referentiels_visite.dart';

/// Magasin de démonstration → produits indispensables de son enseigne (articles du catalogue de démo).
final Map<String, List<ProduitIndispensable>> indispensablesDemo = {
  'm5': [
    for (final id in ['a1', 'a2', 'a6', 'a9', 'a10'])
      for (final p in produitsCatalogue)
        if (p.id == id)
          ProduitIndispensable(
            articleId: p.id,
            libelle: p.nom,
            code: p.code,
            marque: p.marque,
          ),
  ],
};
