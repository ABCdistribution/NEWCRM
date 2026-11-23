/// Calculs de la page « Prospects » : prospects de la vue, compteurs des tuiles, tri, prochaine action.
///
/// Maquette : `pageProspects` (l.697-715) et `prochaineAction` (l.716-719), en fonctions pures.
library;

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';

/// Vue de la page Prospects : « Mes prospects », « Tout le secteur » / « Tous les prospects », ou la timeline par étape
/// (`S.vue` : `liste`, `tous`, `pipeline`).
enum VueProspects { liste, tous, pipeline }

/// Un prospect est « à moi » quand un événement de sa timeline porte « par {nom} » (`mes`) ; avec le CRM
/// (`responsableCrm`), quand il m'est confié (le CRM ne donne pas l'historique dans la liste).
bool estMonProspect(
  Prospect p,
  String nomProfil, {
  bool responsableCrm = false,
}) =>
    (responsableCrm && p.cs == nomProfil) ||
    p.timeline.any((e) => e.detail.contains('par $nomProfil'));

/// Prospects de la vue (`baseVue`) : l'encadrement voit les siens dans « Mes prospects » et tous ceux de son périmètre
/// ailleurs ; le directeur peut en plus se limiter à certains chefs de secteur dans « Tous les prospects ».
List<Prospect> prospectsDeLaVue({
  required List<Prospect> prospects,
  required Role role,
  required String nomProfil,
  required VueProspects vue,
  required List<String> chefsSecteur,
  bool responsableCrm = false,
}) {
  final encadrement = role.peutPilot;
  final directeur = role == Role.dir;
  return prospects
      .where(
        (p) =>
            (!encadrement ||
                vue != VueProspects.liste ||
                estMonProspect(p, nomProfil, responsableCrm: responsableCrm)) &&
            (!directeur ||
                vue != VueProspects.tous ||
                chefsSecteur.isEmpty ||
                chefsSecteur.contains(p.cs)),
      )
      .toList();
}

/// Nombre de prospects d'un groupe du pipeline (compteur d'une tuile).
int compterGroupe(List<Prospect> prospects, GroupeProspect groupe) =>
    prospects.where((p) => p.groupe == groupe).length;

/// Potentiel total en k€/an, arrondi au dixième (`Math.round(total * 10) / 10`, qui arrondit les moitiés vers le haut).
double potentielTotal(List<Prospect> prospects) {
  final total = prospects.fold<double>(0, (somme, p) => somme + p.pot);
  return (total * 10 + 0.5).floorToDouble() / 10;
}

/// Prospects du groupe choisi (tous si aucun), les plus gros potentiels d'abord.
List<Prospect> listeAffichee(List<Prospect> base, GroupeProspect? filtre) =>
    triStable(
      base.where((p) => filtre == null || p.groupe == filtre),
      (a, b) => b.pot.compareTo(a.pot),
    );

/// Prochaine ligne de planning non faite sur ce prospect (`prochaineAction`), ou nul.
EtapePlanning? prochaineEtape(List<EtapePlanning> etapes, String prospectId) {
  for (final e in etapes) {
    if (e.cible == CiblePlanning.prospect && e.ref == prospectId && !e.fait) {
      return e;
    }
  }
  return null;
}

/// Libellé du groupe du pipeline d'un prospect, ou de son étape quand il n'en a pas (« Perdu »).
String libelleGroupeProspect(Prospect p) =>
    p.groupe?.libelle ?? p.statut.libelle;
