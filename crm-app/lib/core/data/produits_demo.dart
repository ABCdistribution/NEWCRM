/// Catalogue de démonstration : maquette `PRODUITS`, `PRODUITS_KIT`, `PRODUITS_PEM`, `CATS`.
library;

import '../models/models.dart';

/// Marques proposées en filtre du catalogue et de la prise de commande (`CATS`).
const List<String> marquesCatalogue = [
  'Franck Provost',
  'Jean Louis David',
  'MB Milano',
];

Produit _a(
  String id,
  String nom,
  String marque,
  String famille,
  String code,
  double prix,
  NiveauStock stock,
  int pcb,
  int qte, {
  bool kit = false,
}) => Produit(
  id: id,
  nom: nom,
  marque: marque,
  cat: marque,
  famille: famille,
  code: code,
  ean: '3761234500${code.substring(code.length - 2)}',
  prix: prix,
  stock: stock,
  pcb: pcb,
  qte: qte,
  kit: kit,
  reappro: stock == NiveauStock.rupture ? '12 nov.' : null,
);

/// Produits du catalogue (`PRODUITS`). Un kit est un produit dont le code ou le libellé commence par « KIT ».
final List<Produit> produitsCatalogue = [
  _a(
    'a1',
    'Shampooing doux usage fréquent',
    'Franck Provost',
    'Shampooings',
    '900016',
    3.46,
    NiveauStock.enStock,
    6,
    98,
  ),
  _a(
    'a2',
    'Shampooing antipelliculaire',
    'Franck Provost',
    'Shampooings',
    '900017',
    22.62,
    NiveauStock.stockBas,
    6,
    45,
  ),
  _a(
    'a3',
    'Coloration châtain 4.0',
    'Franck Provost',
    'Colorations',
    '900021',
    8.77,
    NiveauStock.enStock,
    6,
    369,
  ),
  _a(
    'a4',
    'Coloration blond 7.3',
    'Franck Provost',
    'Colorations',
    '900022',
    14.61,
    NiveauStock.stockBas,
    6,
    8,
  ),
  _a(
    'a5',
    'Kit racines brun',
    'Jean Louis David',
    'Colorations',
    '900024',
    20.81,
    NiveauStock.enStock,
    12,
    410,
    kit: true,
  ),
  _a(
    'a6',
    'Shampooing cheveux colorés',
    'Jean Louis David',
    'Shampooings',
    '900018',
    11,
    NiveauStock.enStock,
    6,
    451,
  ),
  _a(
    'a7',
    'Après-shampooing démêlant',
    'Jean Louis David',
    'Shampooings',
    '900020',
    4.13,
    NiveauStock.stockBas,
    12,
    13,
  ),
  _a(
    'a8',
    'Coloration acajou 5.5',
    'Jean Louis David',
    'Colorations',
    '900023',
    4.87,
    NiveauStock.enStock,
    12,
    330,
  ),
  _a(
    'a9',
    'Rouge mat 101',
    'MB Milano',
    'Rouges à lèvres',
    '900026',
    16.28,
    NiveauStock.enStock,
    12,
    53,
  ),
  _a(
    'a10',
    'Rouge satin 205',
    'MB Milano',
    'Rouges à lèvres',
    '900027',
    4.05,
    NiveauStock.enStock,
    24,
    116,
  ),
  _a(
    'a11',
    'Gloss nude 310',
    'MB Milano',
    'Rouges à lèvres',
    '900028',
    11.14,
    NiveauStock.enStock,
    6,
    389,
  ),
  _a(
    'a12',
    'Baume teinté 520',
    'MB Milano',
    'Rouges à lèvres',
    '900030',
    11.04,
    NiveauStock.stockBas,
    24,
    6,
  ),
  _a(
    'a13',
    'Stick lèvres SPF 30',
    'MB Milano',
    'Protections SPF',
    '900040',
    20.05,
    NiveauStock.rupture,
    6,
    3,
  ),
  _a(
    'a14',
    'Rouge longue tenue 412',
    'MB Milano',
    'Rouges à lèvres',
    '900029',
    20.89,
    NiveauStock.enStock,
    12,
    126,
  ),
];

/// Kits du catalogue, sans prix ni stock dans la démo (`PRODUITS_KIT`).
const List<Produit> produitsKit = [
  Produit(
    id: 'kitKIT91265',
    nom: 'HP-KIT 0,50M GH',
    marque: '',
    famille: 'Kit',
    code: 'KIT91265',
    kit: true,
  ),
  Produit(
    id: 'kitKIT91267',
    nom: 'FP-KIT 0,66M GB',
    marque: '',
    famille: 'Kit',
    code: 'KIT91267',
    kit: true,
  ),
];

Produit _pem(String code, String nom, bool? actif) => Produit(
  id: 'pem$code',
  nom: nom,
  marque: '',
  famille: 'Produit PEM',
  code: code,
  pem: true,
  actif: actif,
);

/// Produits disponibles dans les visites PEM (liste fournie ; le dernier n'a pas de statut).
final List<Produit> produitsPem = [
  _pem('20000', 'SA-CREME LISSANTE NATURE 150ML', false),
  _pem('20001', 'SA-SPRAY WAVY NATUREL 150ML', false),
  _pem('20002', 'SA-SERUM LISSANT NATURE 150ML', false),
  _pem('20003', 'Titanium Natural Care', false),
  _pem('20007', 'Salon Series', true),
  _pem('20015', 'Titanium 2', true),
  _pem('20020', 'SA-ELIXIR DE BRILLANCE V2', true),
  _pem('20021', 'DEMELISS AIRBRUSH WONDER WOMAN', null),
];

/// Catalogue réel téléchargé depuis le CRM (nul en mode démonstration : les produits de la maquette servent alors).
List<Produit>? _catalogueServeur;

/// Remplace (ou, avec null, retire) le catalogue réel ; appelé par le chargement depuis la base locale.
void definirCatalogueServeur(List<Produit>? produits) =>
    _catalogueServeur = produits;

/// Tout le référentiel : catalogue réel s'il est chargé, sinon catalogue, kits et produits PEM de la démo.
List<Produit> tousProduits() =>
    _catalogueServeur ?? [...produitsCatalogue, ...produitsKit, ...produitsPem];

/// Marques proposées en filtre : celles de la démo, ou, avec le catalogue réel, les 12 marques les plus fournies.
List<String> marquesCatalogueActuelles() {
  final reel = _catalogueServeur;
  if (reel == null) return marquesCatalogue;
  final nb = <String, int>{};
  for (final p in reel) {
    final m = p.cat;
    if (m != null && m.isNotEmpty) nb[m] = (nb[m] ?? 0) + 1;
  }
  final marques = nb.keys.toList()
    ..sort((x, y) {
      final c = nb[y]!.compareTo(nb[x]!);
      return c != 0 ? c : x.compareTo(y);
    });
  return marques.take(12).toList();
}

/// Retrouve un produit par id dans tout le référentiel.
Produit? produitParId(String id) {
  for (final p in tousProduits()) {
    if (p.id == id) return p;
  }
  return null;
}
