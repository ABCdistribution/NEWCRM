import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../envoi/corps_visite.dart' show estUuid;
import '../logic/logic.dart';
import '../sync/catalogue_provider.dart';
import '../sync/domaines_provider.dart';
import '../models/models.dart';
import 'crm_etat.dart';
import 'profil_state.dart';

/// Store Riverpod des entités partagées (magasins, prospects, planning, visites, commandes).
///
/// Lecture : `ref.watch(crmProvider)` (ou un sélecteur de `selecteurs.dart`).
/// Écriture : `ref.read(crmProvider.notifier).mutate((e) => e.copyWith(...))` ou une des mutations nommées.
/// L'état est reconstruit à neuf à chaque changement de profil.
class CrmNotifier extends Notifier<CrmEtat> {
  @override
  CrmEtat build() {
    // Reconstruit l'état quand les clients réels sont (re)chargés ; les phases de progression ne comptent pas.
    ref.watch(clientsProvider.select((e) => (e.nb, e.majLe)));
    ref.watch(commandesProvider.select((e) => (e.nb, e.majLe)));
    ref.watch(visitesSynchroProvider.select((e) => (e.nb, e.majLe)));
    ref.watch(prospectsSynchroProvider.select((e) => (e.nb, e.majLe)));
    ref.watch(equipeProvider.select((e) => (e.nb, e.majLe)));
    ref.watch(performanceProvider.select((e) => (e.nb, e.majLe)));
    ref.watch(planningSynchroProvider.select((e) => (e.nb, e.majLe)));
    return CrmEtat.initial(
      ref.watch(roleActifProvider),
      nomUtilisateur: ref.watch(sessionProvider.select((u) => u?.nomAffiche)),
    );
  }

  /// Mutation générique : `mutate((etat) => etat.copyWith(prospects: [...]))`.
  void mutate(CrmEtat Function(CrmEtat etat) transformer) =>
      state = transformer(state);

  // ---- Prospects ---------------------------------------------------------

  /// Ajoute un prospect à la fin de la liste (maquette : création de prospect, « En attente d'envoi »).
  void ajouterProspect(Prospect p) =>
      mutate((e) => e.copyWith(prospects: [...e.prospects, p]));

  void majProspect(String id, Prospect Function(Prospect p) f) => mutate(
    (e) => e.copyWith(
      prospects: [for (final p in e.prospects) p.id == id ? f(p) : p],
    ),
  );

  /// Change l'étape d'un prospect : met à jour statut et probabilité, ajoute « Étape → … » à la timeline
  /// (maquette : `etape-vers`).
  void changerEtapeProspect(String id, StatutProspect statut) => majProspect(
    id,
    (p) {
      if (p.statut == statut) return p;
      final evenement = EvenementProspect(
        icone: IconeEvenement.doc,
        couleur: 0xFFD97706,
        titre: 'Étape → ${statut.libelle}',
        date: 'auj.',
        detail: 'Passé de « ${p.statut.libelle} » à « ${statut.libelle} »',
      );
      return p.copyWith(
        statut: statut,
        proba: statut == StatutProspect.gagne ? p.proba : statut.probaParDefaut,
        timeline: [evenement, ...p.timeline],
      );
    },
  );

  /// Ajoute un événement en tête de la timeline d'un prospect (note, appel…).
  void ajouterEvenementProspect(String id, EvenementProspect ev) =>
      majProspect(id, (p) => p.copyWith(timeline: [ev, ...p.timeline]));

  // ---- Planning ----------------------------------------------------------

  /// Ajoute une ligne au planning du profil, ou à celui composé pour `nom` si fourni.
  void ajouterEtape(EtapePlanning e, {String? pour}) =>
      _majPlan(pour, (l) => [...l, e]);

  void majEtape(
    String id,
    EtapePlanning Function(EtapePlanning e) f, {
    String? pour,
  }) => _majPlan(pour, (l) => [for (final e in l) e.id == id ? f(e) : e]);

  void supprimerEtape(String id, {String? pour}) =>
      _majPlan(pour, (l) => l.where((e) => e.id != id).toList());

  void _majPlan(
    String? nom,
    List<EtapePlanning> Function(List<EtapePlanning>) f,
  ) {
    mutate((e) {
      if (nom == null || nom == profilsDemo[Role.cs]!.nom) {
        return e.copyWith(etapes: f(e.etapes));
      }
      return e.copyWith(
        plansEquipe: {...e.plansEquipe, nom: f(e.plansEquipe[nom] ?? const [])},
      );
    });
  }

  // ---- Visites -----------------------------------------------------------

  /// Démarre une visite chez un client : renvoie l'id du brouillon existant, ou crée un brouillon
  /// (maquette : `startVisite`). N'ouvre aucun écran : voir `AppRoutes.demarrerVisite`.
  ///
  /// `planningId` : identifiant de la visite planifiée (ligne de planning du CRM) d'où part la visite, quand elle part
  /// de « Ma tournée du jour » ; ignoré s'il n'a pas la forme d'un UUID du CRM (démonstration). Sans lui, la visite est
  /// rattachée à l'étape prévue du jour chez ce magasin quand elle existe et n'est pas faite (la première s'il y en a
  /// plusieurs : voir `planningIdDuJour`), d'où qu'elle soit lancée. Un brouillon déjà ouvert garde son lien, ou
  /// l'acquiert s'il n'en avait pas.
  String demarrerVisite(String magasinId, {String? planningId}) {
    final lien = estUuid(planningId)
        ? planningId
        : planningIdDuJour(
            tournee: state.tournee,
            lignes: [...state.planningFenetre, ...state.etapes],
            magasinId: magasinId,
          );
    for (final v in state.visites) {
      if (v.magasinId == magasinId &&
          v.etat == EtatVisite.brouillon &&
          !v.estPem) {
        if (lien != null && v.planningId == null) {
          majVisite(v.id, (x) => x.copyWith(planningId: lien));
        }
        return v.id;
      }
    }
    return _creerBrouillon(magasinId, planningId: lien);
  }

  /// Démarre la visite PEM qui répond à une proposition du CRM : renvoie l'id du brouillon déjà lié à cette
  /// proposition, ou crée un brouillon de type PEM. N'ouvre aucun écran : voir `AppRoutes.demarrerVisitePem`.
  String demarrerVisitePem(String magasinId, String propositionPemId) {
    for (final v in state.visites) {
      if (v.estPem &&
          v.propositionPemId == propositionPemId &&
          v.etat == EtatVisite.brouillon) {
        return v.id;
      }
    }
    return _creerBrouillon(magasinId, propositionPemId: propositionPemId);
  }

  String _creerBrouillon(
    String magasinId, {
    String? propositionPemId,
    String? planningId,
  }) {
    final num = state.prochainNumVisite;
    final visite = Visite(
      id: 'v$num',
      num: num,
      magasinId: magasinId,
      par: state.nomProfil,
      etat: EtatVisite.brouillon,
      date: DemoTemps.maintenantCourt,
      age: 0,
      chrono: {EtapeDph.debut: DemoTemps.horodatageMaintenant()},
      photos: const {
        EtapeDph.arrivee: 0,
        EtapeDph.rayonArrivee: 0,
        EtapeDph.rayonFin: 0,
      },
      typeVisite: propositionPemId == null
          ? TypeVisite.commerciale
          : TypeVisite.pem,
      propositionPemId: propositionPemId,
      planningId: planningId,
    );
    mutate(
      (e) => e.copyWith(
        visites: [visite, ...e.visites],
        prochainNumVisite: num + 1,
      ),
    );
    return visite.id;
  }

  void majVisite(String id, Visite Function(Visite v) f) => mutate(
    (e) =>
        e.copyWith(visites: [for (final v in e.visites) v.id == id ? f(v) : v]),
  );

  // ---- Commandes ---------------------------------------------------------

  /// Ajoute une commande saisie dans l'appli en tête de liste.
  void ajouterCommande(Commande c) =>
      mutate((e) => e.copyWith(commandes: [c, ...e.commandes]));

  /// Identifiant de la prochaine commande saisie dans l'appli (maquette : `2042 + COMMANDES.length - 8`).
  String get prochainIdCommande => 'CDE-${2042 + state.commandes.length - 8}';
}

final crmProvider = NotifierProvider<CrmNotifier, CrmEtat>(CrmNotifier.new);
