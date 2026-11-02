import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_transport.dart';

/// Étape de MA tournée d'encadrement (visite d'un magasin ou d'un prospect, ou tâche administrative), telle que le
/// web la planifie (`/tournees`). Vient du serveur, ou de la file d'envoi tant qu'elle n'est pas partie ([enAttente]).
class EtapeTournee {
  const EtapeTournee({
    required this.id,
    required this.jour,
    required this.titre,
    required this.type,
    this.cibleId,
    this.adresse,
    this.latitude,
    this.longitude,
    this.heure,
    this.ville,
    this.statutProspect,
    this.visiteSimple = true,
    this.accompagnement = false,
    this.rdv = false,
    this.soireeEtape = false,
    this.soireeLieu,
    this.note,
    this.fait = false,
    this.enAttente = false,
  });

  final String id;

  /// Jour de passage (minuit, heure locale).
  final DateTime jour;

  /// « HH:mm », ou null quand aucune heure précise n'est fixée.
  final String? heure;
  final String titre;
  final String? ville;

  /// `CLIENT`, `PROSPECT` ou `ADM`.
  final String type;

  /// Identifiant du magasin ou du prospect visité (null pour une étape ADM).
  final String? cibleId;

  /// Adresse postale et coordonnées du magasin ou du prospect, quand elles sont renseignées (itinéraire).
  final String? adresse;
  final double? latitude;
  final double? longitude;

  /// Un itinéraire est possible : des coordonnées, ou au moins une adresse.
  bool get aUneAdresse => (latitude != null && longitude != null) || (adresse ?? '').isNotEmpty;

  /// Étape du pipeline du prospect visité (NOUVEAU, CONTACTE, PROPOSITION, VISITE, NEGOCIATION, GAGNE…).
  final String? statutProspect;
  final bool visiteSimple;
  final bool accompagnement;
  final bool rdv;
  final bool soireeEtape;
  final String? soireeLieu;
  final String? note;
  final bool fait;
  final bool enAttente;

  /// « 2026-11-02T09:30:00.000Z » → jour 2026-11-02, heure 09:30 (minuit = pas d'heure), lus tels quels comme sur le web.
  static (DateTime, String?) _quand(String iso) {
    final jour = DateTime.parse(iso.substring(0, 10));
    final hhmm = iso.length >= 16 ? iso.substring(11, 16) : null;
    return (jour, hhmm == null || hhmm == '00:00' ? null : hhmm);
  }

  /// « 12 rue X, 93360 Noisy » à partir des champs d'adresse de la cible ; null si rien n'est renseigné.
  static String? _adresseDe(Map<String, dynamic>? cible) {
    if (cible == null) return null;
    String? champ(String k) => (cible[k] as String?)?.trim().isEmpty ?? true ? null : (cible[k] as String).trim();
    final ligne = champ('adresse1');
    final ville = [champ('codePostal'), champ('ville')].whereType<String>().join(' ');
    final adresse = [?ligne, if (ville.isNotEmpty) ville].join(', ');
    return adresse.isEmpty ? null : adresse;
  }

  factory EtapeTournee.fromApi(Map<String, dynamic> j) {
    final (jour, heure) = _quand(j['datePassage'] as String);
    final client = j['client'] as Map<String, dynamic>?;
    final prospect = j['prospect'] as Map<String, dynamic>?;
    final cible = prospect ?? client;
    return EtapeTournee(
      id: j['id'] as String,
      jour: jour,
      heure: heure,
      cibleId: cible?['id'] as String?,
      adresse: _adresseDe(cible),
      latitude: (cible?['latitude'] as num?)?.toDouble(),
      longitude: (cible?['longitude'] as num?)?.toDouble(),
      titre: cible == null ? 'Administratif' : ((cible['enseigne'] as String?)?.trim().isNotEmpty ?? false) ? cible['enseigne'] as String : 'Sans nom',
      ville: cible?['ville'] as String?,
      statutProspect: prospect?['statut'] as String?,
      type: j['adm'] == true ? 'ADM' : (prospect != null ? 'PROSPECT' : 'CLIENT'),
      visiteSimple: j['visiteSimple'] as bool? ?? true,
      accompagnement: j['accompagnement'] as bool? ?? false,
      rdv: j['rdv'] as bool? ?? false,
      soireeEtape: j['soireeEtape'] as bool? ?? false,
      soireeLieu: j['soireeLieu'] as String?,
      note: j['note'] as String?,
      fait: j['fait'] as bool? ?? false,
    );
  }

  /// Étape saisie sur le téléphone, pas encore envoyée : la charge utile de la file porte aussi le titre à afficher.
  factory EtapeTournee.fromOutbox(OutboxItem item) {
    final p = jsonDecode(item.payload) as Map<String, dynamic>;
    final (jour, heure) = _quand(p['datePassage'] as String);
    return EtapeTournee(
      id: item.idApk,
      jour: jour,
      heure: heure,
      cibleId: (p['prospectId'] ?? p['clientId']) as String?,
      titre: p['_titre'] as String? ?? 'Rendez-vous',
      ville: p['_ville'] as String?,
      type: p['adm'] == true ? 'ADM' : (p['prospectId'] != null ? 'PROSPECT' : 'CLIENT'),
      visiteSimple: p['visiteSimple'] as bool? ?? true,
      accompagnement: p['accompagnement'] as bool? ?? false,
      rdv: p['rdv'] as bool? ?? false,
      soireeEtape: p['soireeEtape'] as bool? ?? false,
      soireeLieu: p['soireeLieu'] as String?,
      note: p['note'] as String?,
      enAttente: true,
    );
  }
}

String jourIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _cleSemaine(DateTime lundi) => 'tournee-etapes-${jourIso(lundi)}';

List<EtapeTournee> _lire(Object? brut) => [
      for (final e in (brut as List).cast<Map<String, dynamic>>()) EtapeTournee.fromApi(e),
    ];

/// Lit les étapes de la semaine sur le serveur et met la copie locale à jour. Lève une erreur sans réseau.
Future<List<EtapeTournee>> chargerEtapesSemaineReseau(Ref ref, String userId, DateTime lundi) async {
  final fin = lundi.add(const Duration(days: 7));
  final res = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/tournees/me', queryParameters: {'debut': jourIso(lundi), 'fin': jourIso(fin)});
  final brut = (res.data ?? const []).cast<Map<String, dynamic>>();
  await ref.read(cacheRepositoryProvider).put(userId, _cleSemaine(lundi), brut);
  return _lire(brut);
}

/// Étapes d'une semaine (lundi en paramètre) : copie locale d'abord, réseau seulement si la semaine n'a jamais été lue.
final etapesSemaineProvider = FutureProvider.autoDispose.family<List<EtapeTournee>, DateTime>((ref, lundi) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final cached = await ref.read(cacheRepositoryProvider).get(userId, _cleSemaine(lundi));
  if (cached != null) return _lire(cached.value);
  try {
    return await chargerEtapesSemaineReseau(ref, userId, lundi);
  } on Object {
    return const [];
  }
});

/// Étapes des 90 prochains jours, lues sur le serveur et gardées sur le téléphone (prochaine action de chaque prospect).
Future<List<EtapeTournee>> chargerProchainesEtapesReseau(Ref ref, String userId) async {
  final n = DateTime.now();
  final debut = DateTime(n.year, n.month, n.day);
  final res = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/tournees/me', queryParameters: {'debut': jourIso(debut), 'fin': jourIso(debut.add(const Duration(days: 90)))});
  final brut = (res.data ?? const []).cast<Map<String, dynamic>>();
  await ref.read(cacheRepositoryProvider).put(userId, 'tournee-prochaines', brut);
  return _lire(brut);
}

/// Prochaine étape (non faite, à partir d'aujourd'hui) de chaque prospect, par identifiant de prospect : sert de
/// « prochaine action » dans la liste des prospects. Les étapes saisies et pas encore envoyées comptent aussi.
final prochainesEtapesProvider = FutureProvider.autoDispose<Map<String, EtapeTournee>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  final enAttente = ref.watch(etapesEnAttenteProvider).value ?? const <EtapeTournee>[];
  List<EtapeTournee> serveur = const [];
  final cached = await ref.read(cacheRepositoryProvider).get(userId, 'tournee-prochaines');
  if (cached != null) {
    serveur = _lire(cached.value);
  } else {
    try {
      serveur = await chargerProchainesEtapesReseau(ref, userId);
    } on Object {
      serveur = const [];
    }
  }
  final n = DateTime.now();
  final aujourdhui = DateTime(n.year, n.month, n.day);
  final parProspect = <String, EtapeTournee>{};
  for (final e in [...serveur, ...enAttente]) {
    if (e.type != 'PROSPECT' || e.cibleId == null || e.fait || e.jour.isBefore(aujourdhui)) continue;
    final actuelle = parProspect[e.cibleId];
    final cle = '${jourIso(e.jour)} ${e.heure ?? '00:00'}';
    if (actuelle == null || cle.compareTo('${jourIso(actuelle.jour)} ${actuelle.heure ?? '00:00'}') < 0) parProspect[e.cibleId!] = e;
  }
  return parProspect;
});

/// Étapes saisies sur le téléphone et pas encore confirmées par le serveur (se met à jour avec la file d'envoi).
final etapesEnAttenteProvider = StreamProvider.autoDispose<List<EtapeTournee>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(outboxRepositoryProvider).watchUnsent(userId).map(
        (items) => [for (final i in items) if (i.kind == OutboxKind.etapeTournee) EtapeTournee.fromOutbox(i)],
      );
});
