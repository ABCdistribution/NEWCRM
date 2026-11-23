/// Briefing d'un magasin à l'ouverture d'une visite : objectif du mois, opérations à proposer, alertes.
///
/// Fonctions pures : les données viennent du CRM (fiche du client, promotions) ou de la démonstration.
library;

import '../data/referentiels_visite.dart';
import '../models/models.dart';
import 'classes.dart';
import 'dates.dart';
import 'objectifs.dart';

/// CA du mois sur objectif mensuel d'un magasin.
class ObjectifMois {
  const ObjectifMois({required this.ca, required this.objectif});

  final double ca;
  final double objectif;

  /// Taux d'atteinte en pourcentage, arrondi (0 sans objectif).
  int get taux => tauxAtteinte(ca, objectif);
}

/// Taux d'atteinte arrondi en pourcentage ; 0 si l'objectif est nul ou négatif.
int tauxAtteinte(double ca, double objectif) =>
    objectif > 0 ? (ca / objectif * 100).round() : 0;

/// Objectif mensuel d'un magasin : le douzième de son objectif de CA annuel ; nul si aucun objectif n'est fixé.
double? objectifMensuel(double? objectifAnnuel) =>
    objectifAnnuel == null || objectifAnnuel <= 0 ? null : objectifAnnuel / 12;

/// CA du mois sur objectif mensuel ; nul quand le CA du mois ou l'objectif annuel est inconnu.
ObjectifMois? objectifDuMois({double? caMois, double? objectifAnnuel}) {
  final objectif = objectifMensuel(objectifAnnuel);
  if (caMois == null || objectif == null) return null;
  return ObjectifMois(ca: caMois, objectif: objectif);
}

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

String _libelleJour(DateTime d) => '${d.day} ${moisCourts[d.month - 1]}';

/// Promotions à proposer : celles en cours d'abord (fin la plus proche en tête), puis celles à venir (début le plus
/// proche en tête) ; les promotions terminées sont écartées.
List<OperationPromo> operationsBriefing(List<PromoOp> promos, DateTime auj) {
  final jour = _jour(auj);
  final enCours = <(PromoOp, DateTime?)>[];
  final aVenir = <(PromoOp, DateTime)>[];
  for (final p in promos) {
    if (p.fin != null && p.fin!.isBefore(jour)) continue;
    if (p.debut != null && p.debut!.isAfter(jour)) {
      aVenir.add((p, p.debut!));
    } else {
      enCours.add((p, p.fin));
    }
  }
  enCours.sort((a, b) {
    if (a.$2 == null || b.$2 == null) {
      return a.$2 == null ? (b.$2 == null ? 0 : 1) : -1;
    }
    return a.$2!.compareTo(b.$2!);
  });
  aVenir.sort((a, b) => a.$2.compareTo(b.$2));
  OperationPromo en(PromoOp p, EtatOp etat) => OperationPromo(
    p.libelle,
    p.debut == null ? '' : _libelleJour(p.debut!),
    p.fin == null ? '' : _libelleJour(p.fin!),
    etat,
  );
  return [
    for (final e in enCours) en(e.$1, EtatOp.enCours),
    for (final e in aVenir) en(e.$1, EtatOp.aVenir),
  ];
}

/// Opérations déjà mises en forme (démonstration) : les terminées sont écartées, les en cours passent avant les à venir.
List<OperationPromo> operationsAVenir(List<OperationPromo> ops) => [
  ...ops.where((o) => o.etat == EtatOp.enCours),
  ...ops.where((o) => o.etat == EtatOp.aVenir),
];

/// Période d'une opération, vide si aucune date : « 2 nov. → 15 nov. », « jusqu’au 15 nov. », « à partir du 2 nov. ».
String periodeOperation(OperationPromo op) {
  if (op.du.isNotEmpty && op.au.isNotEmpty) return '${op.du} → ${op.au}';
  if (op.au.isNotEmpty) return 'jusqu’au ${op.au}';
  if (op.du.isNotEmpty) return 'à partir du ${op.du}';
  return '';
}

/// Une commande pas encore livrée et sa date de livraison prévue (nulle si le CRM ne la donne pas).
class LivraisonAttendue {
  const LivraisonAttendue({required this.numero, this.prevue});

  final String numero;
  final DateTime? prevue;
}

/// Intervalle de visite en jours déduit du libellé de périodicité du CRM ; nul si le libellé n'est pas reconnu.
/// Même table que l'API (`joursPeriodicite`).
int? joursPeriodicite(String? libelle) {
  if (libelle == null || libelle.isEmpty) return null;
  final l = libelle
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('’', "'");
  if (l.contains('2 fois par semaine')) return 4;
  if (l.contains('fois par semaine')) return 7;
  if (l.contains('2 semaines')) return 14;
  if (l.contains('3 semaines')) return 21;
  if (l.contains("plus d'un mois")) return 45;
  if (l.contains('fois par mois') || l.contains('mensuel')) return 30;
  if (l.contains('hebdo')) return 7;
  if (l.contains('trimestriel')) return 90;
  if (l.contains('semestriel')) return 180;
  if (l.contains('annuel')) return 365;
  return null;
}

/// Alerte « pas visité depuis N jours » d'après la dernière visite et la périodicité (à défaut, la classe du client) ;
/// nulle si le client est à jour, jamais visité ou sans fréquence connue.
Alerte? alerteVisiteEnRetard(
  Magasin m, {
  required DateTime? derniereVisite,
  required String? periodicite,
  required DateTime auj,
}) {
  if (derniereVisite == null) return null;
  final seuil =
      joursPeriodicite(periodicite) ??
      (seuilVisite.containsKey(m.classe) ? seuilVisite[m.classe] : null);
  if (seuil == null) return null;
  final jours = _jour(auj).difference(_jour(derniereVisite)).inDays;
  if (jours <= seuil) return null;
  return Alerte(
    niveau: seuil <= 10 ? NiveauAlerte.haut : NiveauAlerte.moy,
    magasinId: m.id,
    icone: '📍',
    titre: m.nom,
    classe: m.classe,
    detail:
        'Pas visité depuis $jours jours · visite attendue tous les $seuil jours',
    rang: classeRang(m.classe),
  );
}

/// Alertes de livraison : commande pas livrée dont la date prévue est dépassée (en retard) ou tombe aujourd'hui.
List<Alerte> alertesLivraison(
  Magasin m,
  List<LivraisonAttendue> livraisons,
  DateTime auj,
) {
  final jour = _jour(auj);
  final liste = <Alerte>[];
  for (final l in livraisons) {
    final prevue = l.prevue;
    if (prevue == null) continue;
    final p = _jour(prevue);
    if (p.isAfter(jour)) continue;
    final enRetard = p.isBefore(jour);
    liste.add(
      Alerte(
        niveau: enRetard ? NiveauAlerte.haut : NiveauAlerte.moy,
        magasinId: m.id,
        icone: '🚚',
        titre: m.nom,
        classe: m.classe,
        detail: enRetard
            ? 'Livraison en retard : commande ${l.numero} prévue le ${_libelleJour(p)}'
            : "Livraison prévue aujourd'hui : commande ${l.numero}",
        rang: enRetard ? 40 : 50,
      ),
    );
  }
  return liste;
}

/// Variation du CA en pourcentage lue dans le libellé d'évolution d'un client de démonstration (« −14 % »).
int? variationDepuisLibelle(String evo) {
  final m = RegExp(r'([−+-]?)\s*(\d+)\s*%').firstMatch(evo);
  if (m == null) return null;
  final n = int.parse(m.group(2)!);
  return m.group(1) == '' || m.group(1) == '+' ? n : -n;
}

/// Variation en pourcentage du CA cumulé de l'année sur celui de l'an dernier à la même période ; nulle sans base.
int? variationCa(double? cumul, double? cumulAnneePrecedente) {
  if (cumul == null ||
      cumulAnneePrecedente == null ||
      cumulAnneePrecedente <= 0) {
    return null;
  }
  return ((cumul - cumulAnneePrecedente) / cumulAnneePrecedente * 100).round();
}

/// Alerte « client en baisse » quand la variation du CA est négative.
Alerte? alerteBaisse(Magasin m, int? variationPct) {
  if (variationPct == null || variationPct >= 0) return null;
  return Alerte(
    niveau: NiveauAlerte.moy,
    magasinId: m.id,
    icone: '📉',
    titre: m.nom,
    classe: m.classe,
    detail: 'Client en baisse : CA $variationPct % sur un an',
    rang: 70,
  );
}

String _normaliser(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Une notification (alerte sans client ni prospect) concerne un magasin quand son texte cite l'enseigne et la ville.
bool notificationConcerne(Alerte a, Magasin m) {
  if (a.magasinId != null || a.prospectId != null) return false;
  final parties = m.nom.split(' – ');
  final enseigne = _normaliser(parties.first);
  final ville = parties.length > 1 ? _normaliser(parties.last) : '';
  if (enseigne.isEmpty) return false;
  final texte = _normaliser('${a.titre} ${a.detail}');
  return texte.contains(enseigne) && (ville.isEmpty || texte.contains(ville));
}

/// Alertes du magasin parmi celles de la cloche : celles qui le visent, et les notifications qui le citent.
List<Alerte> alertesDuMagasin(List<Alerte> alertes, Magasin m) => [
  for (final a in alertes)
    if (a.magasinId == m.id || notificationConcerne(a, m)) a,
];

/// Données du CRM propres au magasin (fiche client) qui nourrissent les alertes du briefing.
class DonneesMagasin {
  const DonneesMagasin({
    this.derniereVisite,
    this.periodicite,
    this.livraisons = const [],
    this.variationCaPct,
  });

  final DateTime? derniereVisite;
  final String? periodicite;
  final List<LivraisonAttendue> livraisons;

  /// Variation du CA cumulé de l'année sur l'an dernier, en pourcentage.
  final int? variationCaPct;
}

/// Alertes du briefing : celles de la cloche pour ce magasin, visite en retard d'après la fiche du CRM, livraisons en
/// retard ou du jour, client en baisse. Les plus urgentes d'abord.
List<Alerte> alertesBriefing({
  required Magasin magasin,
  required List<Alerte> cloche,
  DonneesMagasin? donnees,
  required DateTime auj,
}) {
  final liste = alertesDuMagasin(cloche, magasin);
  if (donnees != null) {
    // La date de la dernière visite donnée par le CRM prime sur celle que la cloche déduit des visites de l'appli.
    if (donnees.derniereVisite != null) {
      liste.removeWhere((a) => a.icone == '📍');
      final retard = alerteVisiteEnRetard(
        magasin,
        derniereVisite: donnees.derniereVisite,
        periodicite: donnees.periodicite,
        auj: auj,
      );
      if (retard != null) liste.add(retard);
    }
    liste.addAll(alertesLivraison(magasin, donnees.livraisons, auj));
  }
  final baisse = alerteBaisse(
    magasin,
    donnees?.variationCaPct ?? variationDepuisLibelle(magasin.evo),
  );
  if (baisse != null) liste.add(baisse);
  final haut = [
    for (final a in liste)
      if (a.niveau == NiveauAlerte.haut) a,
  ];
  final reste = [
    for (final a in liste)
      if (a.niveau != NiveauAlerte.haut) a,
  ];
  return [...haut, ...reste];
}

/// Briefing complet d'un magasin ; vide si rien n'est à montrer.
class BriefingMagasin {
  const BriefingMagasin({
    this.objectif,
    this.operations = const [],
    this.alertes = const [],
  });

  final ObjectifMois? objectif;
  final List<OperationPromo> operations;
  final List<Alerte> alertes;

  bool get vide => objectif == null && operations.isEmpty && alertes.isEmpty;
}
