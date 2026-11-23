/// Données propres au lot « visites », portées de la maquette : kits du rayon (`KITS`), composition des kits
/// (`KIT_PRODUITS`), raisons d'absence de visite PEM (`RAISONS_PEM`), libellés de portée (`PORTEE_TXT`).
library;

import '../../../core/data/produits_demo.dart';
import '../../../core/logic/dates.dart';
import '../../../core/models/models.dart';

/// Un kit constaté en rayon pour la distribution numérique (`KITS`).
class Kit {
  const Kit({
    required this.code,
    required this.nom,
    required this.marque,
    required this.refs,
  });

  final String code;
  final String nom;

  /// Vide quand le kit n'a pas de marque.
  final String marque;

  /// Nombre de références du kit.
  final int refs;
}

/// Un produit de la composition d'un kit : code article et quantité (« ×6 »).
class ComposantKit {
  const ComposantKit(this.code, this.qte);
  final String code;
  final int qte;
}

/// Kits proposés dans la feuille « Kits du rayon » (`KITS`, l.354-359).
const List<Kit> kitsDemo = [
  Kit(
    code: 'COSMIA-01',
    nom: 'COSMIA ZIPPED PLANE KIT',
    marque: 'Cosmia',
    refs: 5,
  ),
  Kit(code: 'KIT91265', nom: 'HP-KIT 0,50M GH', marque: '', refs: 5),
  Kit(code: 'KIT91267', nom: 'FP-KIT 0,66M GB', marque: '', refs: 5),
  Kit(
    code: '900024',
    nom: 'Kit racines brun',
    marque: 'Jean Louis David',
    refs: 6,
  ),
];

/// Composition des kits, par code de kit (`KIT_PRODUITS`, l.361-366) : exemples tirés du catalogue.
const Map<String, List<ComposantKit>> compositionKitsDemo = {
  'COSMIA-01': [
    ComposantKit('900021', 6),
    ComposantKit('900022', 6),
    ComposantKit('900023', 6),
    ComposantKit('900025', 6),
    ComposantKit('900024', 6),
  ],
  'KIT91265': [
    ComposantKit('900016', 12),
    ComposantKit('900017', 6),
    ComposantKit('900018', 6),
    ComposantKit('900020', 6),
    ComposantKit('900019', 6),
  ],
  'KIT91267': [
    ComposantKit('900026', 6),
    ComposantKit('900027', 6),
    ComposantKit('900028', 6),
    ComposantKit('900029', 6),
    ComposantKit('900030', 6),
  ],
  '900024': [
    ComposantKit('900021', 3),
    ComposantKit('900022', 3),
    ComposantKit('900023', 3),
    ComposantKit('900025', 3),
  ],
};

/// Kit par code ; un code inconnu devient un kit sans marque dont le nom est le code (`kitDe`). Session réelle : le kit
/// est un produit du catalogue du CRM (les kits de la démonstration n'existent pas).
Kit kitDe(String code) {
  if (DemoTemps.reel) {
    for (final p in tousProduits()) {
      if (p.code == code) {
        return Kit(code: code, nom: p.nom, marque: p.marque, refs: 0);
      }
    }
    return Kit(code: code, nom: code, marque: '', refs: 0);
  }
  for (final k in kitsDemo) {
    if (k.code == code) return k;
  }
  return Kit(code: code, nom: code, marque: '', refs: 0);
}

/// Raisons proposées quand la visite PEM n'a pas eu lieu (`RAISONS_PEM`, l.380).
const List<String> raisonsPem = [
  'Pas de rayon PEM',
  'Rayon fermé ou en travaux',
  'Autre',
];

/// Libellé de portée des visites « de tous » selon le rôle (`PORTEE_TXT`, l.1171).
const Map<Role, String> porteeVisites = {
  Role.promoteur: 'sur vos clients',
  Role.cs: 'de votre secteur',
  Role.dir: 'de votre région',
};
