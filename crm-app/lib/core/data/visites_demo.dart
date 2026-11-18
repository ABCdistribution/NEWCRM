/// Visites de démonstration : maquette `visiteComplete()`, `etatInitial().visites`, `VISITES_AUTRES`.
library;

import '../logic/dates.dart';
import '../models/models.dart';

/// Décalage en minutes de chaque étape DPH par rapport au début de la visite (dans l'ordre de `EtapeDph`).
const List<int> _decalagesDph = [0, 57, 104, 104, 120, 122, 122, 126, 128];

/// Numéro de la première visite créée ensuite sur le téléphone (les 12 numéros précédents sont pris).
const int premierNumVisiteLibre = 218093;

/// Visite complète : toutes les étapes DPH horodatées à partir de l'heure de début (`visiteComplete`).
///
/// `mois` vaut « nov » ou « oct ».
Visite visiteDemo({
  required String id,
  required int num,
  required String magasinId,
  required String par,
  required int jour,
  required String mois,
  required int heure,
  required int minute,
  EtatVisite etat = EtatVisite.envoyee,
  List<String> kits = const ['COSMIA-01', '900024'],
  CommandeLiee? cmd,
}) {
  final chrono = <EtapeDph, String>{};
  for (var i = 0; i < EtapeDph.values.length; i++) {
    final t = heure * 60 + minute + _decalagesDph[i];
    chrono[EtapeDph.values[i]] = horodatage(jour, mois, (t ~/ 60) % 24, t % 60);
  }
  final date = '$jour $mois. ${deuxChiffres(heure)}:${deuxChiffres(minute)}';
  return Visite(
    id: id,
    num: num,
    magasinId: magasinId,
    par: par,
    etat: etat,
    date: date,
    age: ageDepuisTexte(date),
    chrono: chrono,
    recu: chrono[EtapeDph.rayonFin],
    photos: const {
      EtapeDph.arrivee: 2,
      EtapeDph.rayonArrivee: 3,
      EtapeDph.rayonFin: 3,
    },
    dn: const {'COSMIA-01': 5, '900024': 4},
    kits: kits,
    commandeEnRayon: false,
    cmd: cmd,
  );
}

/// Les deux visites du profil déjà faites ce matin (avant filtrage par portefeuille).
/// `par` est le nom du profil courant.
List<Visite> visitesDuProfilDemo(String par) => [
  visiteDemo(
    id: 'd00',
    num: 218081,
    magasinId: 'm10',
    par: par,
    jour: 4,
    mois: 'nov',
    heure: 8,
    minute: 30,
  ),
  visiteDemo(
    id: 'd0',
    num: 218082,
    magasinId: 'm4',
    par: par,
    jour: 4,
    mois: 'nov',
    heure: 9,
    minute: 30,
    cmd: const CommandeLiee(id: '2018', ht: '2 340,00 €', liv: '22/10/2026'),
  ),
];

/// Visites des autres promoteurs (`VISITES_AUTRES`), ids « x0 » à « x9 ».
final List<Visite> visitesAutresDemo = [
  visiteDemo(
    id: 'x0',
    num: 218083,
    magasinId: 'm4',
    par: 'Julien M.',
    jour: 3,
    mois: 'nov',
    heure: 10,
    minute: 0,
    cmd: const CommandeLiee(id: '2018', ht: '2 340,00 €', liv: '22/10/2026'),
  ),
  visiteDemo(
    id: 'x1',
    num: 218084,
    magasinId: 'm1',
    par: 'Julien M.',
    jour: 20,
    mois: 'oct',
    heure: 14,
    minute: 30,
  ),
  visiteDemo(
    id: 'x2',
    num: 218085,
    magasinId: 'm8',
    par: 'Julien M.',
    jour: 10,
    mois: 'oct',
    heure: 9,
    minute: 15,
  ),
  visiteDemo(
    id: 'x3',
    num: 218086,
    magasinId: 'm1',
    par: 'Amine K.',
    jour: 12,
    mois: 'oct',
    heure: 11,
    minute: 0,
  ),
  visiteDemo(
    id: 'x4',
    num: 218087,
    magasinId: 'm9',
    par: 'Amine K.',
    jour: 3,
    mois: 'nov',
    heure: 9,
    minute: 40,
    cmd: const CommandeLiee(id: '2039', ht: '1 980,00 €', liv: '05/11/2026'),
  ),
  visiteDemo(
    id: 'x5',
    num: 218088,
    magasinId: 'm10',
    par: 'Amine K.',
    jour: 29,
    mois: 'oct',
    heure: 15,
    minute: 0,
  ),
  visiteDemo(
    id: 'x6',
    num: 218089,
    magasinId: 'm2',
    par: 'Léa P.',
    jour: 3,
    mois: 'nov',
    heure: 11,
    minute: 20,
  ),
  visiteDemo(
    id: 'x7',
    num: 218090,
    magasinId: 'm3',
    par: 'Léa P.',
    jour: 2,
    mois: 'nov',
    heure: 16,
    minute: 0,
    etat: EtatVisite.terminee,
  ),
  visiteDemo(
    id: 'x8',
    num: 218091,
    magasinId: 'm7',
    par: 'Camille D.',
    jour: 3,
    mois: 'nov',
    heure: 14,
    minute: 0,
    cmd: const CommandeLiee(id: '2033', ht: '1 060,00 €', liv: '04/11/2026'),
  ),
  visiteDemo(
    id: 'x9',
    num: 218092,
    magasinId: 'm6',
    par: 'Camille D.',
    jour: 30,
    mois: 'oct',
    heure: 10,
    minute: 30,
  ),
];
