import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;

import 'app_database.dart';

/// Un référentiel lu depuis le cache local, avec sa date de dernière mise à jour.
class Cached<T> {
  const Cached(this.value, this.fetchedAt, {this.fromCache = false});

  final T value;
  final DateTime fetchedAt;

  /// Vrai si le réseau était indisponible et que ces données viennent du téléphone.
  final bool fromCache;

  /// Au-delà, une copie locale est signalée comme ancienne (la mise à jour n'a pas pu se faire, souvent hors ligne).
  static const delaiFrais = Duration(minutes: 30);

  static bool perime(DateTime fetchedAt, [DateTime? now]) => (now ?? DateTime.now()).difference(fetchedAt) > delaiFrais;
}

/// Au-delà de cette taille (en caractères), le JSON est lu et écrit hors du fil principal : une liste de milliers de
/// magasins figerait l'écran (ANR) si elle était décodée à l'endroit où l'interface se dessine.
const _seuilGros = 40000;

Object? _decoder(String json) => jsonDecode(json);
String _encoder(Object? json) => jsonEncode(json);

/// Cache des référentiels (tournée, magasins, catalogue…), cloisonné par utilisateur.
class CacheRepository {
  CacheRepository(this._db, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  String _k(String userId, String key) => '$userId:$key';

  Future<void> put(String userId, String key, Object? json) async {
    // Une longue liste (magasins…) est sérialisée hors du fil principal.
    final texte = json is List && json.length > 150 ? await compute(_encoder, json) : jsonEncode(json);
    await _db.into(_db.cacheEntries).insertOnConflictUpdate(
          CacheEntriesCompanion.insert(key: _k(userId, key), json: texte, fetchedAt: _now()),
        );
  }

  Future<Cached<Object?>?> get(String userId, String key) async {
    final row = await (_db.select(_db.cacheEntries)..where((r) => r.key.equals(_k(userId, key)))).getSingleOrNull();
    if (row == null) return null;
    final decode = row.json.length > _seuilGros ? await compute(_decoder, row.json) : jsonDecode(row.json);
    return Cached(decode, row.fetchedAt, fromCache: true);
  }
}
