import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/activite_serveur.dart';
import '../logic/logic.dart';
import '../sync/domaines_provider.dart';
import '../models/models.dart';
import 'crm_state.dart';
import 'profil_state.dart';

/// Alertes de la cloche du profil courant, les plus urgentes d'abord (maquette : `alertes()`).
/// Le jour courant est celui de `jourPlanningProvider`, comme la maquette (`S.jour`).
final alertesProvider = Provider<List<Alerte>>((ref) {
  final e = ref.watch(crmProvider);
  final jour = ref.watch(jourPlanningProvider);
  ref.watch(notificationsSynchroProvider.select((e) => (e.nb, e.majLe)));
  final calculees = calculerAlertes(
    role: e.role,
    magasins: e.magasins,
    prospects: e.prospects,
    etapes: e.etapes,
    visites: e.visites,
    visitesAutres: e.visitesAutres,
    commandes: e.commandes,
    jour: jour,
  );
  // Les notifications du CRM (relances de l'encadrement) passent avant les alertes calculées.
  return [...notificationsServeur(), ...calculees];
});

/// Clients visibles du profil (portefeuille, secteur ou région selon le rôle).
final magasinsProvider = Provider<List<Magasin>>(
  (ref) => ref.watch(crmProvider).magasins,
);

/// Prospects visibles du profil (vide pour le promoteur).
final prospectsProvider = Provider<List<Prospect>>(
  (ref) => ref.watch(crmProvider).prospects,
);

/// Planning du profil.
final etapesProvider = Provider<List<EtapePlanning>>(
  (ref) => ref.watch(crmProvider).etapes,
);

/// Visites du profil.
final visitesProvider = Provider<List<Visite>>(
  (ref) => ref.watch(crmProvider).visites,
);

/// Commandes des clients visibles.
final commandesVisiblesProvider = Provider<List<Commande>>(
  (ref) => ref.watch(crmProvider).commandesVisibles,
);

/// Un client par id (portefeuille, secteur ou hors région), nul s'il n'existe pas.
final magasinParIdProvider = Provider.family<Magasin?, String>(
  (ref, id) => ref.watch(crmProvider.select((e) => e.magasinParId(id))),
);

/// Un prospect par id.
final prospectParIdProvider = Provider.family<Prospect?, String>(
  (ref, id) => ref.watch(crmProvider.select((e) => e.prospectParId(id))),
);

/// Une visite par id (du profil ou d'un autre promoteur).
final visiteParIdProvider = Provider.family<Visite?, String>(
  (ref, id) => ref.watch(crmProvider.select((e) => e.visiteParId(id))),
);

/// Une commande par id.
final commandeParIdProvider = Provider.family<Commande?, String>(
  (ref, id) => ref.watch(crmProvider.select((e) => e.commandeParId(id))),
);
