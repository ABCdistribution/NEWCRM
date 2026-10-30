import 'package:dio/dio.dart';

import '../../core/db/cache_repository.dart';

/// Magasin d'une visite planifiée.
class MagasinRef {
  const MagasinRef({required this.id, required this.codeAs400, required this.enseigne, this.ville, this.niveauClass});

  final String id;
  final String codeAs400;
  final String enseigne;
  final String? ville;
  final String? niveauClass;

  factory MagasinRef.fromJson(Map<String, dynamic> j) => MagasinRef(
        id: j['id'] as String,
        codeAs400: (j['codeAs400'] as String?) ?? '',
        enseigne: (j['enseigne'] as String?) ?? '',
        ville: j['ville'] as String?,
        niveauClass: j['niveauClass'] as String?,
      );
}

/// Visite planifiée (ligne de planning renvoyée par `GET /plannings`).
class PlanningItem {
  const PlanningItem({required this.id, required this.datePassage, required this.fait, required this.client, this.raison});

  final String id;
  final DateTime datePassage;
  final bool fait;
  final String? raison;
  final MagasinRef client;

  factory PlanningItem.fromJson(Map<String, dynamic> j) => PlanningItem(
        id: j['id'] as String,
        datePassage: DateTime.parse(j['datePassage'] as String).toLocal(),
        fait: (j['fait'] as bool?) ?? false,
        raison: j['raison'] as String?,
        client: MagasinRef.fromJson(j['client'] as Map<String, dynamic>),
      );
}

/// Tournée d'une journée, avec l'indication de sa fraîcheur.
class TourneeJour {
  const TourneeJour({required this.items, required this.fetchedAt, required this.fromCache});

  final List<PlanningItem> items;
  final DateTime fetchedAt;
  final bool fromCache;
}

/// Charge la tournée du jour : réseau d'abord, copie locale si le réseau est indisponible (CDC §3.2).
class TourneeRepository {
  TourneeRepository(this._dio, this._cache);

  final Dio _dio;
  final CacheRepository _cache;

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Copie locale de la tournée du jour (null si jamais chargée) : affichée tout de suite, sans attendre le réseau.
  Future<TourneeJour?> local(String userId, DateTime day) async {
    final cached = await _cache.get(userId, 'tournee:${_day(day)}');
    if (cached == null) return null;
    return TourneeJour(items: _parse(cached.value as List<dynamic>), fetchedAt: cached.fetchedAt, fromCache: Cached.perime(cached.fetchedAt));
  }

  Future<TourneeJour> load(String userId, DateTime day) async {
    final key = 'tournee:${_day(day)}';
    final debut = DateTime(day.year, day.month, day.day);
    final fin = debut.add(const Duration(days: 1));
    try {
      final res = await _dio.get<List<dynamic>>(
        '/plannings',
        queryParameters: {
          'promoteurId': userId,
          'debut': debut.toUtc().toIso8601String(),
          'fin': fin.toUtc().toIso8601String(),
        },
      );
      final raw = res.data ?? const [];
      await _cache.put(userId, key, raw);
      return TourneeJour(items: _parse(raw), fetchedAt: DateTime.now(), fromCache: false);
    } on DioException {
      final cached = await _cache.get(userId, key);
      if (cached == null) rethrow; // rien en mémoire : l'écran affichera l'erreur
      return TourneeJour(items: _parse(cached.value as List<dynamic>), fetchedAt: cached.fetchedAt, fromCache: true);
    }
  }

  static List<PlanningItem> _parse(List<dynamic> raw) {
    final items = raw.map((e) => PlanningItem.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.datePassage.compareTo(b.datePassage));
    return items;
  }
}
