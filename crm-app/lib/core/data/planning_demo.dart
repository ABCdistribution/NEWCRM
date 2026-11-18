/// Planning de démonstration : maquette `etatInitial().etapes` et `tourneeSales`.
library;

import '../models/models.dart';

/// Planning de la semaine 45 du profil (avant filtrage par périmètre).
const List<EtapePlanning> etapesDemo = [
  EtapePlanning(
    id: 'e1',
    jour: 0,
    heure: '09:30',
    cible: CiblePlanning.client,
    ref: 'm4',
    titre: 'Carrefour – Ivry-sur-Seine',
    rdv: true,
    note: 'Point linéaire soin',
    fait: true,
  ),
  EtapePlanning(
    id: 'e2',
    jour: 0,
    heure: '14:00',
    cible: CiblePlanning.prospect,
    ref: 'p3',
    titre: 'Auchan – Rouen',
    rdv: true,
    fait: true,
  ),
  EtapePlanning(
    id: 'e3',
    jour: 1,
    heure: '10:00',
    cible: CiblePlanning.client,
    ref: 'm2',
    titre: 'Carrefour Market – Rouen',
    fait: true,
  ),
  EtapePlanning(
    id: 'e4',
    jour: 1,
    heure: '15:10',
    cible: CiblePlanning.client,
    ref: 'm1',
    titre: 'Carrefour Market – Versailles',
    rdv: true,
    note: 'Relance baisse de CA',
  ),
  EtapePlanning(
    id: 'e5',
    jour: 2,
    heure: '09:00',
    cible: CiblePlanning.client,
    ref: 'm3',
    titre: 'Carrefour – Rouen',
  ),
  EtapePlanning(
    id: 'e6',
    jour: 2,
    heure: '11:30',
    cible: CiblePlanning.prospect,
    ref: 'p2',
    titre: 'Carrefour – Paris',
    rdv: true,
  ),
  EtapePlanning(
    id: 'e7',
    jour: 2,
    heure: '16:00',
    cible: CiblePlanning.adm,
    titre: 'Administratif',
    visite: false,
    note: 'Compte rendu',
  ),
  EtapePlanning(
    id: 'e8',
    jour: 3,
    heure: '10:00',
    cible: CiblePlanning.prospect,
    ref: 'p1',
    titre: 'Super U – Versailles',
    acc: true,
    rdv: true,
    soiree: true,
    soireeLieu: 'Versailles',
    soireeAdr: '3 rue Haute',
    note: 'Négociation',
  ),
];

/// Tournée du jour du promoteur (`tourneeSales`), avant filtrage par portefeuille.
const List<TourneeVisite> tourneeDemo = [
  TourneeVisite(id: 'v0', magasinId: 'm10', heure: '08:30', type: 'Planifiée'),
  TourneeVisite(id: 'v1', magasinId: 'm4', heure: '09:30', type: 'Planifiée'),
  TourneeVisite(id: 'v2', magasinId: 'm1', heure: '11:00', type: 'Planifiée'),
  TourneeVisite(
    id: 'v5',
    magasinId: 'm8',
    heure: '12:30',
    type: 'Passage opportunité',
  ),
  TourneeVisite(id: 'v3', magasinId: 'm2', heure: '14:30', type: 'Planifiée'),
  TourneeVisite(
    id: 'v6',
    magasinId: 'm7',
    heure: '15:30',
    type: 'Appel client',
  ),
  TourneeVisite(id: 'v4', magasinId: 'm3', heure: '16:30', type: 'Planifiée'),
  TourneeVisite(id: 'v7', magasinId: 'm9', heure: '17:15', type: 'Urgence'),
  TourneeVisite(id: 'v8', magasinId: 'm6', heure: '18:00', type: 'Planifiée'),
];

/// Motifs de visite proposés (`MOTIFS`).
const List<String> motifsVisite = [
  'Planifiée',
  'Appel client',
  'Passage opportunité',
  'Urgence',
  'Prospection',
];

/// Prévision enregistrée lundi pour la semaine 45 (`demoPrevu`), construite à partir du planning du profil.
///
/// L'ADM (`e7`) n'y figurait pas, Carrefour Market – Versailles était prévu à 14:00 et Carrefour Market – Rouen jeudi
/// 14:00 n'a pas eu lieu (`e9`) ; aucune ligne n'est faite. Comme la maquette (`.filter(okE)`), les lignes dont le
/// client ou le prospect n'est pas visible du profil sont écartées : `magasins` et `prospects` sont ceux du store.
List<EtapePlanning> previsionDemo(
  List<EtapePlanning> etapes, {
  required List<Magasin> magasins,
  required List<Prospect> prospects,
}) {
  final prevu = <EtapePlanning>[
    for (final e in etapes)
      if (e.id != 'e7')
        (e.id == 'e4' ? e.copyWith(heure: '14:00') : e).copyWith(fait: false),
    const EtapePlanning(
      id: 'e9',
      jour: 3,
      heure: '14:00',
      cible: CiblePlanning.client,
      ref: 'm2',
      titre: 'Carrefour Market – Rouen',
    ),
  ];
  bool visible(EtapePlanning e) => switch (e.cible) {
    CiblePlanning.client => magasins.any((m) => m.id == e.ref),
    CiblePlanning.prospect => prospects.any((p) => p.id == e.ref),
    _ => true,
  };
  return prevu.where(visible).toList();
}
