/// Commande en attente de la démo : maquette `S.attente` l.513.
library;

import '../state/commande_en_cours.dart';

/// Commande mise de côté par le profil (client `m8`, 2 lignes, consigne « Inventaire » jusqu'au 16 novembre).
const List<CommandeEnAttente> attenteDemo = [
  CommandeEnAttente(
    magasinId: 'm8',
    lignes: [LigneCommande('a2', 12), LigneCommande('a9', 24)],
    pas: true,
    dateMin: '2026-11-16',
    motifPas: 'Inventaire',
    note: 'En attente de la validation du chef de rayon',
    date: '3 nov. 17:40',
  ),
];
