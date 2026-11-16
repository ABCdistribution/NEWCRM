/// Calculs propres au lot planning : signature des lignes, détail d'une carte, rapport de la semaine 45,
/// clients proposés pour le planning d'un promoteur. Fonctions pures.
library;

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../data/rapports_demo.dart';

/// Signature d'une ligne (`sigLigne`) : ce qui compte pour savoir si la prévision enregistrée est à jour.
String signatureLigne(EtapePlanning e) => [
  e.id,
  e.jour,
  e.heure,
  e.titre,
  e.visite,
  e.acc,
  e.rdv,
  e.soiree,
].join('|');

/// Vrai si les lignes du planning ont changé depuis l'enregistrement de la prévision (`prevuSale`).
bool previsionModifiee(
  List<EtapePlanning>? prevision,
  List<EtapePlanning> etapes,
) {
  if (prevision == null) return false;
  final a = prevision.map(signatureLigne).toList()..sort();
  final b = etapes.map(signatureLigne).toList()..sort();
  return a.join(';') != b.join(';');
}

/// Deuxième ligne d'une carte du planning : « Accompagnement · RDV · Soirée étape (Versailles) · Négociation ».
///
/// `lectureSeule` : planning du promoteur, où « Visite simple » n'est jamais affiché (`roMode === true`).
String detailLigne(EtapePlanning e, {required bool lectureSeule}) => [
  if (e.acc)
    'Accompagnement'
  else if (e.visite && !lectureSeule)
    'Visite simple',
  if (e.rdv) 'RDV',
  if (e.appel) 'Appel téléphonique',
  if (e.remp) 'Visite de remplacement',
  if (e.soiree) 'Soirée étape (${e.soireeLieu ?? ''})',
  if (e.note.isNotEmpty) e.note,
].join(' · ');

/// « 3 lignes », « 1 ligne ».
String nbLignes(int n) => '$n ligne${n > 1 ? 's' : ''}';

/// Rapport de la semaine 45 une fois validée : ligne ajoutée en tête des rapports précédents (`pageRapportsMes`).
///
/// `ecarts` : comparaison prévision / planning ; nulle sans prévision (aucun pourcentage, aucun écart).
RapportSemaine rapportSemaineEnCours({
  required List<EtapePlanning> etapes,
  required List<EtapePlanning>? prevision,
  required ResultatEcarts? ecarts,
}) {
  return RapportSemaine(
    numero: DemoTemps.semaineCourante,
    periode: DemoTemps.semaineLibelle,
    visites: etapes.where((e) => e.cible != CiblePlanning.adm).length,
    pct: ecarts?.pct,
    rdv: etapes.where((e) => e.rdv).length,
    prevues: prevision?.length,
    pied: 'Validé automatiquement le ${DemoTemps.lundiSuivantLibelle} à 04:00',
    ecarts: [
      if (ecarts != null)
        for (final l in ecarts.lignes)
          if (l.genre != GenreEcart.fait)
            EcartPlanning.resume(l.genre, l.titre, null),
    ],
  );
}

/// Clients proposés dans le planning d'un promoteur (`clientsDe`) : ceux de ses visites, à défaut tous ceux du profil.
List<Magasin> clientsDe(String nom, List<Magasin> magasins) {
  final activite = activitePourPlan(nom, promoteurParNom(nom));
  final noms = activite.visites.map((v) => v.client).toSet();
  final l = magasins.where((m) => noms.contains(m.nom)).toList();
  return l.length >= 2 ? l : magasins;
}
