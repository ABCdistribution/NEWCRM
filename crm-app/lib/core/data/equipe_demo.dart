/// Équipe de démonstration : maquette `PROMOS`, `OBJ_EUR`, `EQUIPE_CS` (identité), `activitePromo()`, `planOf()`.
library;

import '../logic/dates.dart';
import '../models/models.dart';

/// Chefs de secteur de la région du directeur (`EQUIPE_CS`, identité seulement).
const List<ChefSecteur> chefsSecteurDemo = [
  ChefSecteur(
    id: 'n',
    nom: 'Nadia H.',
    ini: 'NH',
    region: 'Île-de-France',
    secteur: 'Île-de-France',
  ),
  ChefSecteur(
    id: 'k',
    nom: 'Karim B.',
    ini: 'KB',
    region: 'Nord',
    secteur: 'Normandie / Hauts-de-France',
  ),
  ChefSecteur(
    id: 's',
    nom: 'Sophie L.',
    ini: 'SL',
    region: 'Sud-Est',
    secteur: 'Sud-Est',
  ),
];

/// CA réalisé et objectif du mois par promoteur, en euros (`OBJ_EUR`).
const Map<String, List<int>> _objEur = {
  'Julien M.': [4200, 4900],
  'Léa P.': [3100, 4350],
  'Amine K.': [5800, 5700],
  'Camille D.': [2900, 4150],
  'Yanis R.': [4600, 4850],
  'Inès G.': [1700, 2950],
  'Hugo T.': [5100, 5100],
  'Maëlle S.': [2400, 3650],
};

Promoteur _promo(
  String nom,
  String ini,
  int mag,
  int v,
  int p,
  List<VisiteJourPromo> jour,
) => Promoteur(
  nom: nom,
  ini: ini,
  mag: mag,
  v: v,
  p: p,
  real: _objEur[nom]![0].toDouble(),
  cible: _objEur[nom]![1].toDouble(),
  jour: jour,
);

/// Promoteurs de chaque chef de secteur, par id de chef (`PROMOS`).
final Map<String, List<Promoteur>> promoteursParChef = {
  'n': [
    _promo('Julien M.', 'JM', 3, 8, 10, const [
      VisiteJourPromo(
        '09:30',
        'Carrefour – Ivry-sur-Seine',
        EtatTourneePromo.realisee,
      ),
      VisiteJourPromo(
        '11:00',
        'Carrefour Market – Versailles',
        EtatTourneePromo.aFaire,
      ),
    ]),
    _promo('Léa P.', 'LP', 4, 6, 9, const [
      VisiteJourPromo(
        '10:00',
        'Carrefour Market – Rouen',
        EtatTourneePromo.realisee,
      ),
      VisiteJourPromo('15:00', 'Carrefour – Rouen', EtatTourneePromo.aFaire),
    ]),
    _promo('Amine K.', 'AK', 3, 9, 9, const [
      VisiteJourPromo('09:00', 'U Express – Paris', EtatTourneePromo.realisee),
      VisiteJourPromo('14:00', 'Auchan – Rouen', EtatTourneePromo.enCours),
    ]),
  ],
  'k': [
    _promo('Camille D.', 'CD', 4, 7, 10, const [
      VisiteJourPromo('09:30', 'Super U – Amiens', EtatTourneePromo.realisee),
    ]),
    _promo('Yanis R.', 'YR', 3, 10, 10, const [
      VisiteJourPromo('10:30', 'Monoprix – Caen', EtatTourneePromo.realisee),
      VisiteJourPromo('14:30', 'Carrefour – Rouen', EtatTourneePromo.aFaire),
    ]),
    _promo('Inès G.', 'IG', 3, 5, 9, const [
      VisiteJourPromo(
        '11:00',
        'Carrefour – Versailles',
        EtatTourneePromo.aFaire,
      ),
    ]),
  ],
  's': [
    _promo('Hugo T.', 'HT', 4, 8, 8, const [
      VisiteJourPromo('09:00', 'Monoprix – Lyon', EtatTourneePromo.realisee),
    ]),
    _promo('Maëlle S.', 'MS', 3, 6, 9, const [
      VisiteJourPromo('13:30', 'Intermarché – Lyon', EtatTourneePromo.aFaire),
    ]),
  ],
};

/// Tous les promoteurs, tous chefs confondus.
List<Promoteur> tousPromoteurs() =>
    promoteursParChef.values.expand((l) => l).toList();

/// Promoteur par nom court, nul s'il n'existe pas.
Promoteur? promoteurParNom(String nom) {
  for (final p in tousPromoteurs()) {
    if (p.nom == nom) return p;
  }
  return null;
}

/// Visite résumée de l'activité d'un promoteur (lecture seule).
class VisiteResumee {
  const VisiteResumee({
    required this.client,
    required this.date,
    required this.enCours,
  });
  final String client;

  /// « 4 nov. 09:00 ».
  final String date;
  final bool enCours;
}

/// Commande résumée de l'activité d'un promoteur (lecture seule).
class CommandeResumee {
  const CommandeResumee({
    required this.id,
    required this.client,
    required this.ht,
    required this.statut,
    required this.date,
  });
  final String id;
  final String client;
  final String ht;
  final StatutLivraison statut;
  final String date;
}

class ActivitePromoteur {
  const ActivitePromoteur(this.visites, this.commandes);
  final List<VisiteResumee> visites;
  final List<CommandeResumee> commandes;
}

const Map<String, List<String>> _clientsParPromoteur = {
  'Julien M.': [
    'Carrefour Market – Versailles',
    'Carrefour – Ivry-sur-Seine',
    'U Express – Boulogne-Billancourt',
    'E.Leclerc – Paris',
  ],
  'Léa P.': [
    'Carrefour – Rouen',
    'Carrefour Market – Rouen',
    'U Express – Paris',
  ],
  'Amine K.': [
    'E.Leclerc – Paris',
    'Carrefour – Versailles',
    'U Express – Paris',
  ],
};

const List<String> _clientsParDefaut = [
  'Auchan – Avignon',
  'Intermarché – Lyon',
  'Monoprix – Nice',
];

/// Visites et commandes fictives d'un promoteur (ou d'un chef de secteur) : maquette `activitePromo`.
///
/// `nom` : nom court ; `visitesPrevues` (`p.v`) et `mag` (`p.mag`) : valeurs de la fiche ;
/// `jour` : sa tournée du jour (pour l'état « En cours ») ; `clientsPerso` : liste de clients imposée.
ActivitePromoteur activitePromoteur({
  required String nom,
  int visitesPrevues = 6,
  int mag = 3,
  List<VisiteJourPromo> jour = const [],
  List<String>? clientsPerso,
}) {
  final clients =
      clientsPerso ?? _clientsParPromoteur[nom] ?? _clientsParDefaut;
  const dates = ['4 nov.', '3 nov.', '3 nov.', '2 nov.', '30 oct.', '29 oct.'];
  final nbVisites = visitesPrevues < 6 ? visitesPrevues : 6;
  final enCours = jour.any((j) => j.etat == EtatTourneePromo.enCours);
  final visites = List.generate(
    nbVisites,
    (i) => VisiteResumee(
      client: clients[i % clients.length],
      date: '${dates[i]} ${deuxChiffres(9 + i)}:${i.isOdd ? '30' : '00'}',
      enCours: i == 0 && enCours,
    ),
  );
  const cmds = [
    ['CDE-2041', '1 540,00 €', 'PAS_LIVREE'],
    ['CDE-2039', '1 980,00 €', 'LIVREE'],
    ['CDE-2027', '958,70 €', 'PAS_LIVREE'],
    ['CDE-2018', '2 340,00 €', 'LIVREE'],
  ];
  final nbCmds = mag < 2 ? 2 : mag;
  final commandes = <CommandeResumee>[
    for (var i = 0; i < cmds.length && i < nbCmds; i++)
      CommandeResumee(
        id: cmds[i][0],
        client: clients[(i + 1) % clients.length],
        ht: cmds[i][1],
        statut: cmds[i][2] == 'LIVREE'
            ? StatutLivraison.livree
            : StatutLivraison.pasLivree,
        date: dates[i + 1],
      ),
  ];
  return ActivitePromoteur(visites, commandes);
}

/// Planning initial d'un promoteur ou d'un chef de secteur ouvert par son encadrement (`planOf`).
///
/// `magasins` : clients visibles du profil (une ligne devient « client » si son titre est un de leurs noms).
List<EtapePlanning> planningInitialDe(String nom, List<Magasin> magasins) {
  final p = promoteurParNom(nom);
  final activite = activitePourPlan(nom, p);
  final cl = activite.visites.map((v) => v.client).toList();
  var n = 0;
  // Index par nom (premier client de ce nom) : la liste réelle compte des milliers de clients.
  final parNom = <String, Magasin>{};
  for (final x in magasins) {
    parNom.putIfAbsent(x.nom, () => x);
  }
  EtapePlanning ligne(
    int jour,
    String heure,
    String titre, {
    bool fait = false,
  }) {
    final m = parNom[titre];
    n++;
    return EtapePlanning(
      id: 'pp-${nom.replaceAll(' ', '').replaceAll('.', '')}-$n',
      jour: jour,
      heure: heure,
      cible: m != null ? CiblePlanning.client : CiblePlanning.libre,
      ref: m?.id,
      titre: titre,
      fait: fait,
    );
  }

  return [
    ligne(0, '09:00', cl[0], fait: true),
    ligne(1, '10:00', cl[1], fait: true),
    for (final j in p?.jour ?? const <VisiteJourPromo>[])
      ligne(2, j.heure, j.client, fait: j.etat == EtatTourneePromo.realisee),
    ligne(3, '09:30', cl.length > 2 ? cl[2] : cl[0]),
    ligne(4, '14:00', cl[0]),
  ];
}

/// Activité utilisée pour composer un planning (`activitePromo(p)` de `planOf`).
ActivitePromoteur activitePourPlan(String nom, Promoteur? p) =>
    activitePromoteur(
      nom: nom,
      visitesPrevues: p?.v ?? 6,
      mag: p?.mag ?? 3,
      jour: p?.jour ?? const [],
    );

/// Noms dont le planning est composé par l'encadrement : tous les promoteurs et les chefs de secteur autres que Nadia H.
List<String> nomsAvecPlanningEquipe() => [
  ...tousPromoteurs().map((p) => p.nom),
  for (final c in chefsSecteurDemo)
    if (c.nom != profilsDemo[Role.cs]!.nom) c.nom,
];
