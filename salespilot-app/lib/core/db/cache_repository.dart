import 'dart:convert';

import 'app_database.dart';

/// Un référentiel lu depuis le cache local, avec sa date de dernière mise à jour.
class Cached<T> {
  const Cached(this.value, this.fetchedAt, {this.fromCache = false});

  final T value;
  final DateTime fetchedAt;

  /// Vrai si le réseau était indisponible et que ces données viennent du téléphone.
  final bool fromCache;
}

/// Cache des référentiels (tournée, magasins, catalogue…), cloisonné par utilisateur.
class CacheRepository {
  CacheRepository(this._db, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  String _k(String userId, String key) => '$userId:$key';

  Future<void> put(String userId, String key, Object? json) async {
    await _db.into(_db.cacheEntries).insertOnConflictUpdate(
          CacheEntriesCompanion.insert(key: _k(userId, key), json: jsonEncode(json), fetchedAt: _now()),
        );
  }

  Future<Cached<Object?>?> get(String userId, String key) async {
    final row = await (_db.select(_db.cacheEntries)..where((r) => r.key.equals(_k(userId, key)))).getSingleOrNull();
    if (row == null) return null;
    return Cached(jsonDecode(row.json), row.fetchedAt, fromCache: true);
  }
}
