import 'package:dio/dio.dart';

import '../../core/db/cache_repository.dart';

/// Niveau de stock affiché. Le serveur ne donne qu'une quantité : les seuils sont une proposition (à valider).
enum NiveauStock { enStock, bas, rupture }

/// Article du référentiel (`GET /articles`).
class Produit {
  const Produit({
    required this.id,
    required this.code,
    required this.libelle,
    this.ean,
    this.marque,
    this.gamme,
    this.famille,
    this.pcb,
    this.stock = 0,
    this.prix,
    this.enPromo = false,
    this.promoLibelle,
    this.misEnAvant = false,
  });

  final String id;
  final String code;
  final String libelle;
  final String? ean;
  final String? marque;
  final String? gamme;
  final String? famille;

  /// Colisage : nombre d'unités par colis.
  final int? pcb;
  final int stock;

  /// Prix indicatif HT (premier tarif actif).
  final double? prix;
  final bool enPromo;
  final String? promoLibelle;
  final bool misEnAvant;

  /// En dessous de ce stock (ou de deux colis s'il est connu et plus grand), l'article est signalé « stock bas ».
  static const seuilStockBas = 20;

  NiveauStock get niveauStock {
    if (stock <= 0) return NiveauStock.rupture;
    final seuil = (pcb ?? 0) * 2 > seuilStockBas ? (pcb! * 2) : seuilStockBas;
    return stock < seuil ? NiveauStock.bas : NiveauStock.enStock;
  }

  factory Produit.fromJson(Map<String, dynamic> j) {
    String? nom(Object? v) => (v is Map ? v['nom'] : null) as String?;
    return Produit(
      id: j['id'] as String,
      code: (j['codeAs400'] as String?) ?? '',
      libelle: ((j['libelle'] as String?) ?? '').trim(),
      ean: (j['gencode'] as String?)?.trim(),
      marque: nom(j['marque']),
      gamme: nom(j['gamme']),
      famille: nom(j['famille']),
      pcb: (j['pcb'] as num?)?.toInt(),
      stock: (j['stock'] as num?)?.toInt() ?? 0,
      prix: (j['prixIndicatif'] as num?)?.toDouble(),
      enPromo: (j['enPromo'] as bool?) ?? false,
      promoLibelle: j['promoLibelle'] as String?,
      misEnAvant: (j['misEnAvant'] as bool?) ?? false,
    );
  }
}

/// Référentiel produits : réseau d'abord, copie locale si le réseau est indisponible (CDC §3.5 : recherche locale
/// par libellé, code, EAN et marque).
class ProduitRepository {
  ProduitRepository(this._dio, this._cache);

  final Dio _dio;
  final CacheRepository _cache;

  static const _pageSize = 100;
  static const _maxPages = 60; // garde-fou : 6 000 articles au plus

  Future<Cached<List<Produit>>> loadAll(String userId) async {
    try {
      final rows = <dynamic>[];
      for (var page = 1; page <= _maxPages; page++) {
        final res = await _dio.get<Map<String, dynamic>>('/articles', queryParameters: {'actif': 'true', 'limit': _pageSize, 'page': page});
        final data = (res.data?['data'] as List?) ?? const [];
        rows.addAll(data);
        final total = (res.data?['total'] as num?)?.toInt() ?? rows.length;
        if (rows.length >= total || data.isEmpty) break;
      }
      await _cache.put(userId, 'produits', rows);
      return Cached(_parse(rows), DateTime.now());
    } on DioException {
      final cached = await _cache.get(userId, 'produits');
      if (cached == null) rethrow;
      return Cached(_parse(cached.value as List<dynamic>), cached.fetchedAt, fromCache: true);
    }
  }

  static List<Produit> _parse(List<dynamic> rows) =>
      rows.map((e) => Produit.fromJson(Map<String, dynamic>.from(e as Map))).toList()..sort((a, b) => a.libelle.toLowerCase().compareTo(b.libelle.toLowerCase()));
}
