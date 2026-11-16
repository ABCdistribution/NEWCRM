/// Commandes d'un client pour la fiche (maquette : `cmdsClient`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/state/state.dart';

/// Commandes d'un client, les plus récentes d'abord (numéro décroissant), toutes origines confondues.
List<Commande> commandesDuClient(
  Iterable<Commande> commandes,
  String magasinId,
) {
  final liste = commandes.where((c) => c.magasinId == magasinId).toList();
  liste.sort((a, b) => b.id.compareTo(a.id));
  return liste;
}

/// Commandes d'un client lues dans le store : une commande saisie dans l'appli apparaît aussitôt sur sa fiche.
final commandesClientProvider = Provider.family<List<Commande>, String>(
  (ref, magasinId) => commandesDuClient(
    ref.watch(crmProvider.select((e) => e.commandes)),
    magasinId,
  ),
);
