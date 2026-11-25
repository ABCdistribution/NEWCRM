/// Corps de `POST /visites` à partir d'une visite terminée (fonction pure, conforme au `CreateVisiteDto` de l'API).
library;

import 'dart:math' as math;

import '../models/models.dart';

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Vrai pour un identifiant du CRM (UUID) ; les identifiants de la démonstration n'en sont pas.
bool estUuid(String? valeur) => valeur != null && _uuid.hasMatch(valeur);

final RegExp _horodatage = RegExp(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2})h(\d{2})$');

/// « 04/11/2026 08h30 » (heure locale du téléphone, comme les étapes de la visite) en date UTC ISO 8601, ou null si le
/// texte est illisible.
String? horodatageIso(String texte) {
  final m = _horodatage.firstMatch(texte.trim());
  if (m == null) return null;
  final jour = int.parse(m.group(1)!);
  final mois = int.parse(m.group(2)!);
  final an = int.parse(m.group(3)!);
  final heure = int.parse(m.group(4)!);
  final minute = int.parse(m.group(5)!);
  final d = DateTime(an, mois, jour, heure, minute);
  // `DateTime` déborde sans erreur (31/02 devient mars) : on refuse ces dates.
  if (d.day != jour || d.month != mois || d.hour != heure) return null;
  return d.toUtc().toIso8601String();
}

const String _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// Identifiant d'une visite saisie sur le mobile (`idApk`, 64 caractères au plus) : « V » et 20 caractères
/// alphanumériques. Il n'est pas tiré du numéro de la visite, qui peut se répéter d'un lancement à l'autre.
String genererIdVisite([math.Random? hasard]) {
  final r = hasard ?? math.Random.secure();
  return 'V${List.generate(20, (_) => _alphabet[r.nextInt(_alphabet.length)]).join()}';
}

/// Corps de la création d'une visite.
///
/// - `etapes` : l'horodatage de chaque étape faite (`chrono`) en ISO 8601 ;
/// - `commandeEnRayon` seulement une fois répondu ;
/// - `idCommandeApk` si une commande est liée, sinon `raisonAbsenceCommandeId` (l'API refuse les deux ensemble) ;
/// - `planningId` : la visite planifiée du CRM que la visite solde (l'API la marque faite), seulement si la visite
///   est partie d'une étape de « Ma tournée du jour » venue du CRM (UUID) ;
/// - `kits` : code et nombre de références constatées (`dn`), 0 tant que non relevé ;
/// - `reponses` : les réponses non vides aux questions du CRM ;
/// - visite commerciale : `indispensables` ; visite PEM : `typeVisite`, `propositionPemId` et `articlesPem` (l'API les
///   refuse sur une visite commerciale).
Map<String, Object?> corpsVisite(Visite v, {required String idApk}) {
  final etapes = <Map<String, Object?>>[
    for (final e in v.chrono.entries)
      if (horodatageIso(e.value) case final iso?)
        {'etape': e.key.cle, 'horodatage': iso},
  ];
  final idCommande = v.cmd?.idApk;
  final commandeLiee = idCommande != null && idCommande.isNotEmpty;
  final raison = v.raisonAbsenceId;
  final reponses = [
    for (final r in v.reponses.entries)
      if (r.value.trim().isNotEmpty && estUuid(r.key))
        {'questionId': r.key, 'valeur': r.value},
  ];
  final kits = [
    for (final code in v.kits) {'code': code, 'references': v.dn[code] ?? 0},
  ];
  return {
    'idApk': idApk,
    'clientId': v.magasinId,
    'typeVisite': v.estPem ? 'PEM' : 'COMMERCIALE',
    if (v.estPem && v.propositionPemId != null)
      'propositionPemId': v.propositionPemId,
    if (estUuid(v.planningId)) 'planningId': v.planningId,
    'commandeEnRayon': ?v.commandeEnRayon,
    if (commandeLiee) 'idCommandeApk': idCommande,
    if (!commandeLiee && raison != null && estUuid(raison))
      'raisonAbsenceCommandeId': raison,
    if (reponses.isNotEmpty) 'reponses': reponses,
    if (kits.isNotEmpty) 'kits': kits,
    if (!v.estPem && v.indispensables.isNotEmpty)
      'indispensables': [
        for (final i in v.indispensables.entries)
          if (estUuid(i.key)) {'articleId': i.key, 'present': i.value},
      ],
    if (v.estPem && v.articlesPem.isNotEmpty)
      'articlesPem': [
        for (final a in v.articlesPem.entries)
          if (estUuid(a.key))
            {
              'articleId': a.key,
              'present': a.value.present,
              'misEnAvant': a.value.present && a.value.misEnAvant,
            },
      ],
    if (etapes.isNotEmpty) 'etapes': etapes,
  };
}
