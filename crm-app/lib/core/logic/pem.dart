/// Règles des visites PEM, en fonctions pures : fenêtres de dates, libellés, simulation locale d'une acceptation ou d'un
/// report (démonstration), lien entre une proposition et la visite faite sur le téléphone.
library;

import '../models/models.dart';
import 'dates.dart';

/// Nombre de jours, à partir d'aujourd'hui, dans lesquels une visite PEM peut être planifiée.
const int joursFenetrePem = 14;

/// Report proposé par défaut : une semaine plus tard.
const int joursReportParDefaut = 7;

/// Message du CRM (409) quand on reporte une visite devenue obligatoire.
const String messageObligatoire =
    'Cette visite PEM est obligatoire : elle ne peut plus être reportée';

/// Bornes (jours, à minuit) d'un choix de date.
typedef FenetreDates = ({DateTime min, DateTime max});

/// `aaaa-mm-jj` d'une date.
String jourIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${deuxChiffres(d.month)}-${deuxChiffres(d.day)}';

/// Jour (à minuit) d'une date `aaaa-mm-jj` (avec ou sans heure) ; nul si elle est illisible.
DateTime? lireJourIso(String? iso) {
  final m = iso == null
      ? null
      : RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

DateTime _plusJours(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Acceptation : d'aujourd'hui à 14 jours.
FenetreDates fenetreAcceptation(DateTime aujourdhui) => (
  min: _plusJours(aujourdhui, 0),
  max: _plusJours(aujourdhui, joursFenetrePem),
);

/// Report : de demain à 14 jours.
FenetreDates fenetreReport(DateTime aujourdhui) => (
  min: _plusJours(aujourdhui, 1),
  max: _plusJours(aujourdhui, joursFenetrePem),
);

/// Date proposée par défaut à un report : aujourd'hui + 7 jours.
DateTime dateReportParDefaut(DateTime aujourdhui) =>
    _plusJours(aujourdhui, joursReportParDefaut);

/// Le jour est-il dans la fenêtre (bornes comprises) ?
bool dansFenetre(DateTime jour, FenetreDates f) =>
    !jour.isBefore(f.min) && !jour.isAfter(f.max);

/// Date proposée acceptable telle quelle : dans la fenêtre d'acceptation. Sinon (date passée, trop lointaine), le
/// promoteur doit choisir une date.
bool dateProposeeAcceptable(PropositionPem p, DateTime aujourdhui) {
  final d = lireJourIso(p.dateProposee);
  return d != null && dansFenetre(d, fenetreAcceptation(aujourdhui));
}

/// Propositions à traiter, par date proposée croissante puis identifiant.
List<PropositionPem> propositionsOuvertes(Iterable<PropositionPem> liste) {
  final l = [
    for (final p in liste)
      if (p.ouverte) p,
  ];
  l.sort((a, b) {
    final c = a.dateProposee.compareTo(b.dateProposee);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return l;
}

/// Pastille de la carte : « Obligatoire », sinon « 2 reports restants » (« 1 report restant »).
String libelleReports(PropositionPem p) {
  if (p.obligatoire) return 'Obligatoire';
  final n = p.reportsRestants;
  return n <= 0
      ? 'Plus de report possible'
      : '$n report${n > 1 ? 's' : ''} restant${n > 1 ? 's' : ''}';
}

/// « lun. 9 nov. » pour `2026-11-09` ; la date brute si elle est illisible.
String libelleDatePem(String iso) {
  final d = lireJourIso(iso);
  return d == null ? iso : DemoTemps.libelleJour(d);
}

/// Proposition après une acceptation (simulation locale) : acceptée, à la date choisie quand il y en a une.
PropositionPem accepterLocalement(PropositionPem p, {String? date}) =>
    p.copyWith(statut: StatutPem.acceptee, dateProposee: date);

/// Proposition après un report (simulation locale) : un report de plus ; au troisième, la visite est acceptée et
/// obligatoire. Une proposition qui ne peut plus être reportée est rendue telle quelle (l'appelant refuse avant).
PropositionPem reporterLocalement(
  PropositionPem p, {
  String? motif,
  String? date,
}) {
  if (!p.reportable) return p;
  final n = p.nbReports + 1;
  final obligatoire = n >= nbReportsAvantObligation;
  return p.copyWith(
    nbReports: n,
    reportsRestants: obligatoire ? 0 : nbReportsAvantObligation - n,
    obligatoire: obligatoire,
    statut: obligatoire ? StatutPem.acceptee : StatutPem.proposee,
    dateProposee: date,
    motifDernierReport: motif,
  );
}

/// Visite du téléphone qui répond à une proposition : la plus récente en tête de liste (le store place la nouvelle en
/// premier), ou nulle quand elle n'est pas encore démarrée.
Visite? visitePemDe(Iterable<Visite> visites, String propositionId) {
  for (final v in visites) {
    if (v.estPem && v.propositionPemId == propositionId) return v;
  }
  return null;
}
