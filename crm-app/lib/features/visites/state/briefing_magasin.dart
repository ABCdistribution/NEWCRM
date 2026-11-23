import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/logic.dart';
import '../../../core/state/state.dart';
import '../../../core/sync/fiche_client_provider.dart';
import '../../../core/sync/referentiels_visite_provider.dart';

/// Briefing d'un magasin pour la visite : objectif du mois, opérations à proposer, alertes.
///
/// Magasin du CRM : fiche du client (copie locale puis version fraîche) et promotions en cours ou à venir ; tant qu'elles
/// ne sont pas là, ou sans réseau ni copie, les rubriques concernées restent vides. Démonstration : données fictives.
final briefingMagasinProvider = Provider.family<BriefingMagasin, String>((
  ref,
  magasinId,
) {
  final m = ref.watch(magasinParIdProvider(magasinId));
  if (m == null) return const BriefingMagasin();
  final auj = DemoTemps.aujourdhui;
  final cloche = ref.watch(alertesProvider);
  if (!m.reel) {
    final o = objectifMagasin(m);
    return BriefingMagasin(
      objectif: ObjectifMois(ca: o.ca.toDouble(), objectif: o.obj.toDouble()),
      operations: operationsAVenir(o.ops),
      alertes: alertesBriefing(magasin: m, cloche: cloche, auj: auj),
    );
  }
  final fiche = ref.watch(ficheClientProvider(m.id)).value;
  final promos = ref.watch(promosBriefingProvider).value ?? const [];
  return BriefingMagasin(
    objectif: fiche == null
        ? null
        : objectifDuMois(
            caMois: fiche.caMois,
            objectifAnnuel: fiche.objectifAnnuel,
          ),
    operations: operationsBriefing(promos, auj),
    alertes: alertesBriefing(
      magasin: m,
      cloche: cloche,
      donnees: fiche?.donneesBriefing,
      auj: auj,
    ),
  );
});
