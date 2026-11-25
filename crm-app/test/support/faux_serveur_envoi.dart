import 'dart:convert';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Erreur renvoyée par l'API (message en français, comme `ErreurApi.depuisReponse`).
ErreurApi erreurHttp(int statut, String message) =>
    ErreurApi.depuisReponse(statut, jsonEncode({'message': message}));

/// Clés acceptées par `CreateVisiteDto` (`crm-api/src/visites/visites.controller.ts`).
const _clesVisite = {
  'idApk',
  'clientId',
  'prospectId',
  'planningId',
  'motif',
  'dnAbc',
  'dnConcurrence',
  'dnGondoleHaute',
  'dnGondoleBasse',
  'commentaire',
  'idCommandeApk',
  'raisonAbsenceCommandeId',
  'reponses',
  'commandeEnRayon',
  'colis',
  'kits',
  'promosOp',
  'indispensables',
  'typeVisite',
  'propositionPemId',
  'articlesPem',
  'etapes',
};

/// `ETAPES_VISITE` et `ETAPES_PHOTO` de `visites.service.ts`.
const etapesVisiteApi = [
  'debut',
  'arrivee',
  'rayonArrivee',
  'colis',
  'dn',
  'indispensables',
  'articlesPem',
  'commande',
  'questionnaire',
  'op',
  'rayonFin',
];
const etapesPhotoApi = ['arrivee', 'rayonArrivee', 'rayonFin'];

/// Clés acceptées par `CreateCommandeApkDto`.
const _clesCommande = {
  'idCommandeApk',
  'clientId',
  'dateCommande',
  'commentaire',
  'statut',
  'emailValidation',
  'nePasLivrerAvant',
  'motifNePasLivrerAvant',
  'lignes',
};

ErreurApi _invalide(String message) => erreurHttp(400, message);

bool _liste(Object? v) => v is List && v.every((e) => e is Map);

/// Contrôles du `CreateVisiteDto` et de `VisitesService.create` (noms de champs, énumérations, UUID, exclusions).
List<String> erreursCorpsVisite(Map<String, Object?> c) {
  final e = <String>[];
  for (final k in c.keys) {
    if (!_clesVisite.contains(k)) e.add('propriété $k inconnue');
  }
  final idApk = c['idApk'];
  if (idApk is! String || idApk.isEmpty || idApk.length > 64) e.add('idApk');
  if (c['clientId'] is! String || !_uuid.hasMatch(c['clientId']! as String)) {
    e.add('clientId doit être un UUID');
  }
  if (c.containsKey('typeVisite') &&
      !const ['COMMERCIALE', 'PEM'].contains(c['typeVisite'])) {
    e.add('typeVisite');
  }
  final pem = c['typeVisite'] == 'PEM';
  if (c.containsKey('propositionPemId')) {
    if (!pem) e.add("propositionPemId n'est accepté que pour une visite PEM");
    if (!_uuid.hasMatch('${c['propositionPemId']}')) e.add('propositionPemId');
  }
  if (c.containsKey('planningId') && !_uuid.hasMatch('${c['planningId']}')) {
    e.add('planningId doit être un UUID');
  }
  if (!pem && c.containsKey('articlesPem')) {
    e.add("articlesPem n'est accepté que pour une visite PEM");
  }
  if (c.containsKey('commandeEnRayon') && c['commandeEnRayon'] is! bool) {
    e.add('commandeEnRayon');
  }
  if (c.containsKey('idCommandeApk') &&
      !RegExp(r'^[A-Za-z0-9]{4,10}$').hasMatch('${c['idCommandeApk']}')) {
    e.add('idCommandeApk');
  }
  if (c.containsKey('raisonAbsenceCommandeId') &&
      !_uuid.hasMatch('${c['raisonAbsenceCommandeId']}')) {
    e.add('raisonAbsenceCommandeId');
  }
  if (c.containsKey('idCommandeApk') &&
      c.containsKey('raisonAbsenceCommandeId')) {
    e.add('Fournir au plus un des deux : idCommandeApk ou raisonAbsence');
  }
  void liste(String cle, void Function(Map m) verif) {
    final v = c[cle];
    if (v == null) return;
    if (!_liste(v)) {
      e.add('$cle doit être une liste');
      return;
    }
    for (final m in v as List) {
      verif(m as Map);
    }
  }

  liste('reponses', (m) {
    if (!_uuid.hasMatch('${m['questionId']}')) e.add('reponses.questionId');
    if (m['valeur'] is! String) e.add('reponses.valeur');
  });
  liste('kits', (m) {
    if (m['code'] is! String || (m['code'] as String).isEmpty) {
      e.add('kits.code');
    }
    final r = m['references'];
    if (r is! int || r < 0 || r > 1000) e.add('kits.references');
  });
  liste('indispensables', (m) {
    if (!_uuid.hasMatch('${m['articleId']}')) e.add('indispensables.articleId');
    if (m['present'] is! bool) e.add('indispensables.present');
  });
  liste('articlesPem', (m) {
    if (!_uuid.hasMatch('${m['articleId']}')) e.add('articlesPem.articleId');
    if (m['present'] is! bool) e.add('articlesPem.present');
    if (m['misEnAvant'] is! bool) e.add('articlesPem.misEnAvant');
  });
  liste('etapes', (m) {
    if (!etapesVisiteApi.contains(m['etape'])) e.add('etape ${m['etape']}');
    final h = m['horodatage'];
    if (h is! String ||
        DateTime.tryParse(h) == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(h)) {
      e.add('horodatage');
    }
  });
  return e;
}

/// Contrôles du `CreateCommandeApkDto`.
List<String> erreursCorpsCommande(Map<String, Object?> c) {
  final e = <String>[];
  for (final k in c.keys) {
    if (!_clesCommande.contains(k)) e.add('propriété $k inconnue');
  }
  if (!RegExp(r'^[A-Za-z0-9]{4,10}$').hasMatch('${c['idCommandeApk']}')) {
    e.add('idCommandeApk : 4 à 10 caractères alphanumériques');
  }
  if (!_uuid.hasMatch('${c['clientId']}')) e.add('clientId doit être un UUID');
  if (DateTime.tryParse('${c['dateCommande']}') == null) e.add('dateCommande');
  if (c.containsKey('statut') &&
      !const ['EN_ATTENTE', 'VALIDEE'].contains(c['statut'])) {
    e.add('statut');
  }
  final lignes = c['lignes'];
  if (lignes is! List || lignes.isEmpty) {
    e.add('lignes');
  } else {
    for (final l in lignes) {
      if (l is! Map) {
        e.add('ligne');
        continue;
      }
      for (final k in l.keys) {
        if (!const {'articleId', 'quantite', 'prixIndicatif'}.contains(k)) {
          e.add('ligne.$k inconnue');
        }
      }
      if (!_uuid.hasMatch('${l['articleId']}')) e.add('ligne.articleId');
      final q = l['quantite'];
      if (q is! int || q < 1) e.add('ligne.quantite');
      final p = l['prixIndicatif'];
      if (p != null && (p is! num || p < 0)) e.add('ligne.prixIndicatif');
    }
  }
  return e;
}

/// Contrôles des DTO de note, d'appel et d'e-mail d'un client ou d'un prospect (noms de champs, longueurs).
List<String> erreursCorpsActivite(String nature, Map<String, Object?> c) {
  final cles = switch (nature) {
    'notes' => {'remarque', 'idApk'},
    'appels' => {'dateAppel', 'resultat', 'dureeSec', 'commentaire', 'idApk'},
    _ => {'dateEmail', 'destinataire', 'sujet', 'commentaire', 'idApk'},
  };
  final e = <String>[];
  for (final k in c.keys) {
    if (!cles.contains(k)) e.add('propriété $k inconnue');
  }
  final idApk = c['idApk'];
  if (idApk != null &&
      (idApk is! String || idApk.isEmpty || idApk.length > 64)) {
    e.add('idApk');
  }
  if (nature == 'notes') {
    final r = c['remarque'];
    if (r is! String || r.isEmpty || r.length > 2000) e.add('remarque');
  }
  final date = c[nature == 'appels' ? 'dateAppel' : 'dateEmail'];
  if (date != null && (date is! String || DateTime.tryParse(date) == null)) {
    e.add('date');
  }
  return e;
}

/// Serveur simulé pour la file d'envoi : `POST /visites`, `POST /visites/:id/photos`, `POST /commandes/apk` et
/// `POST /commandes/apk/:id/valider`, idempotents comme ceux de l'API, avec ses contrôles de DTO et ses erreurs.
class FauxServeurEnvoi implements ApiLecture, ApiEcriture, ApiFichiers {
  /// Appels reçus, `METHODE chemin` (les appels refusés avant d'être traités y figurent aussi).
  final List<String> appels = [];

  /// Visites créées, par `idApk`.
  final Map<String, Map<String, Object?>> visites = {};

  /// Photos reçues, par `idApk`.
  final Map<String, Map<String, Object?>> photos = {};

  /// Commandes reçues, par `idCommandeApk`.
  final Map<String, Map<String, Object?>> commandes = {};

  /// Notes, appels et e-mails reçus (`POST /clients|prospects/:id/notes|appels|emails`), par `idApk`.
  final Map<String, Map<String, Object?>> activites = {};

  /// Vrai : tout appel échoue comme une coupure réseau.
  bool horsLigne = false;

  /// Erreurs renvoyées par les prochains appels d'écriture, dans l'ordre (une par appel, null : l'appel passe).
  final List<ErreurApi?> pannes = [];

  /// Erreur renvoyée à chaque appel dont `METHODE chemin` commence par la clé.
  final Map<String, ErreurApi> refus = {};

  /// Exécuté à chaque appel avant traitement (pour couper le réseau en plein envoi).
  void Function(String appel)? surAppel;

  /// Temps de réponse de chaque écriture ; le plus grand nombre d'écritures en même temps y est relevé.
  Duration latence = Duration.zero;
  int maxSimultanes = 0;
  int _actifs = 0;

  int _suivant = 1;

  Future<T> _suivre<T>(Future<T> Function() appel) async {
    _actifs++;
    if (_actifs > maxSimultanes) maxSimultanes = _actifs;
    try {
      if (latence > Duration.zero) await Future<void>.delayed(latence);
      return await appel();
    } finally {
      _actifs--;
    }
  }

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    if (horsLigne) throw const ErreurApi(TypeErreurApi.reseau);
    return {'data': <Object?>[], 'total': 0, 'page': 1, 'limit': 100};
  }

  void _preparer(String appel) {
    appels.add(appel);
    surAppel?.call(appel);
    if (horsLigne) throw const ErreurApi(TypeErreurApi.reseau);
    for (final e in refus.entries) {
      if (appel.startsWith(e.key)) throw e.value;
    }
    if (pannes.isNotEmpty) {
      final p = pannes.removeAt(0);
      if (p != null) throw p;
    }
  }

  @override
  Future<Object?> envoyer(String methode, String chemin, {Object? corps}) =>
      _suivre(() => _envoyer(methode, chemin, corps));

  @override
  Future<Object?> televerser(
    String chemin, {
    required String champ,
    required String nomFichier,
    required String typeMime,
    required List<int> octets,
    Map<String, String> champs = const {},
  }) => _suivre(() => _televerser(chemin, champ, typeMime, octets, champs));

  Future<Object?> _envoyer(String methode, String chemin, Object? corps) async {
    _preparer('$methode $chemin');
    if (methode == 'POST' && chemin == '/visites') {
      final c = Map<String, Object?>.from(corps! as Map);
      final fautes = erreursCorpsVisite(c);
      if (fautes.isNotEmpty) throw _invalide(fautes.join(' '));
      final idApk = c['idApk']! as String;
      final existante = visites[idApk];
      if (existante != null) {
        return {
          'id': existante['id'],
          'idApk': idApk,
          'dejaSynchronisee': true,
        };
      }
      final id = _uuidDe(_suivant++);
      visites[idApk] = {'id': id, 'corps': c};
      return {'id': id, 'idApk': idApk, 'dejaSynchronisee': false};
    }
    if (methode == 'POST' && chemin == '/commandes/apk') {
      final c = Map<String, Object?>.from(corps! as Map);
      final fautes = erreursCorpsCommande(c);
      if (fautes.isNotEmpty) throw _invalide(fautes.join(' '));
      final cle = c['idCommandeApk']! as String;
      final existante = commandes[cle];
      if (existante != null) {
        return {
          'id': existante['id'],
          'idCommandeApk': cle,
          'statut': existante['statut'],
          'dejaSynchronisee': true,
        };
      }
      final id = _uuidDe(_suivant++);
      final statut = (c['statut'] as String?) ?? 'VALIDEE';
      commandes[cle] = {'id': id, 'statut': statut, 'corps': c};
      return {
        'id': id,
        'idCommandeApk': cle,
        'statut': statut,
        'dejaSynchronisee': false,
      };
    }
    final activite = RegExp(
      r'^/(clients|prospects)/([^/]+)/(notes|appels|emails)$',
    ).firstMatch(chemin);
    if (methode == 'POST' && activite != null) {
      final c = Map<String, Object?>.from(corps! as Map);
      final fautes = erreursCorpsActivite(activite.group(3)!, c);
      if (!_uuid.hasMatch(activite.group(2)!)) {
        fautes.add('id doit être un UUID');
      }
      if (fautes.isNotEmpty) throw _invalide(fautes.join(' '));
      final idApk = c['idApk'] as String?;
      final existante = idApk == null ? null : activites[idApk];
      if (existante != null) {
        return {'id': existante['id'], 'dejaSynchronise': true};
      }
      final id = _uuidDe(_suivant++);
      activites[idApk ?? id] = {'id': id, 'chemin': chemin, 'corps': c};
      return {'id': id, 'dejaSynchronise': false};
    }
    final valider = RegExp(
      r'^/commandes/apk/([^/]+)/valider$',
    ).firstMatch(chemin);
    if (methode == 'POST' && valider != null) {
      final c = commandes.values
          .where((x) => x['id'] == valider.group(1))
          .firstOrNull;
      if (c == null) throw erreurHttp(404, 'Commande mobile introuvable');
      c['statut'] = 'VALIDEE';
      return {'id': c['id'], 'statut': 'VALIDEE'};
    }
    throw erreurHttp(404, 'Route inconnue $methode $chemin');
  }

  Future<Object?> _televerser(
    String chemin,
    String champ,
    String typeMime,
    List<int> octets,
    Map<String, String> champs,
  ) async {
    _preparer('POST $chemin');
    final m = RegExp(r'^/visites/([^/]+)/photos$').firstMatch(chemin);
    if (m == null) throw erreurHttp(404, 'Route inconnue $chemin');
    final visite = visites.values
        .where((v) => v['id'] == m.group(1))
        .firstOrNull;
    if (visite == null) throw erreurHttp(404, 'Visite introuvable');
    if (champ != 'photo') {
      throw erreurHttp(400, 'Aucune photo reçue (champ « photo »).');
    }
    if (!typeMime.startsWith('image/')) {
      throw erreurHttp(400, 'Le fichier doit être une image.');
    }
    for (final k in champs.keys) {
      if (k != 'idApk' && k != 'etape') {
        throw erreurHttp(400, 'propriété $k inconnue');
      }
    }
    final etape = champs['etape'];
    if (etape != null && !etapesPhotoApi.contains(etape)) {
      throw erreurHttp(
        400,
        'etape doit être l\'une des valeurs : ${etapesPhotoApi.join(', ')}',
      );
    }
    final idApk = champs['idApk'];
    if (idApk != null) {
      final existante = photos[idApk];
      if (existante != null) {
        if (existante['visiteId'] != m.group(1)) {
          throw erreurHttp(400, 'idApk déjà utilisé pour une autre visite');
        }
        return {'id': existante['id'], 'dejaSynchronise': true};
      }
    }
    final id = _uuidDe(_suivant++);
    photos[idApk ?? id] = {
      'id': id,
      'visiteId': m.group(1),
      'etape': etape,
      'taille': octets.length,
      'mime': typeMime,
    };
    return {'id': id, 'dejaSynchronise': false};
  }

  String _uuidDe(int n) =>
      '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

  /// Nombre d'appels `METHODE chemin` commençant par `debut`.
  int nbAppels(String debut) => appels.where((a) => a.startsWith(debut)).length;
}
