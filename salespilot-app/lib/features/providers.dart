import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../core/db/cache_repository.dart';
import '../core/providers.dart';
import 'magasins/magasin_repository.dart';
import 'produits/produit_repository.dart';
import 'tournee/tournee_repository.dart';
import 'visite/visite_models.dart';

final tourneeRepositoryProvider =
    Provider<TourneeRepository>((ref) => TourneeRepository(ref.watch(dioProvider), ref.watch(cacheRepositoryProvider)));

/// Tournée du jour (réseau, sinon copie locale).
final tourneeProvider = FutureProvider.autoDispose<TourneeJour>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Aucune session');
  return ref.watch(tourneeRepositoryProvider).load(userId, DateTime.now());
});

/// Visites de l'utilisateur (brouillons, terminées, synchronisées).
final draftsProvider = StreamProvider.autoDispose<List<VisiteDraft>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(draftRepositoryProvider).watchForUser(userId);
});

/// Chiffres du mois affichés sur l'accueil (`GET /dashboard/me`) : CA du mois et taux d'atteinte de l'objectif.
class ObjectifMois {
  const ObjectifMois({required this.realise, this.tauxPct});

  final double realise;
  final int? tauxPct;

  factory ObjectifMois.fromJson(Map<String, dynamic> j) {
    final o = (j['objectif'] as Map<String, dynamic>?) ?? const {};
    return ObjectifMois(
      realise: double.tryParse('${o['realise'] ?? 0}') ?? 0,
      tauxPct: (o['tauxPct'] as num?)?.toInt(),
    );
  }
}

/// Null quand le serveur est injoignable et qu'aucune copie n'existe : l'accueil affiche alors « — ».
final objectifMoisProvider = FutureProvider.autoDispose<ObjectifMois?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final cache = ref.watch(cacheRepositoryProvider);
  try {
    final res = await ref.watch(dioProvider).get<Map<String, dynamic>>('/dashboard/me');
    final raw = res.data ?? const <String, dynamic>{};
    await cache.put(userId, 'dashboard-me', raw);
    return ObjectifMois.fromJson(raw);
  } on Object {
    final cached = await cache.get(userId, 'dashboard-me');
    if (cached == null) return null;
    return ObjectifMois.fromJson(Map<String, dynamic>.from(cached.value as Map));
  }
});

final magasinRepositoryProvider =
    Provider<MagasinRepository>((ref) => MagasinRepository(ref.watch(dioProvider), ref.watch(cacheRepositoryProvider)));

final magasinsProvider = FutureProvider.autoDispose<Cached<List<Magasin>>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Aucune session');
  return ref.watch(magasinRepositoryProvider).loadAll(userId);
});

final produitRepositoryProvider =
    Provider<ProduitRepository>((ref) => ProduitRepository(ref.watch(dioProvider), ref.watch(cacheRepositoryProvider)));

/// Référentiel produits (réseau, sinon copie locale).
final produitsProvider = FutureProvider.autoDispose<Cached<List<Produit>>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Aucune session');
  return ref.watch(produitRepositoryProvider).loadAll(userId);
});

/// Questionnaire de visite (réseau, sinon copie locale).
final questionnaireProvider = FutureProvider.autoDispose<List<Question>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final cache = ref.watch(cacheRepositoryProvider);
  try {
    final res = await ref.watch(dioProvider).get<List<dynamic>>('/questionnaire');
    final raw = res.data ?? const [];
    await cache.put(userId, 'questionnaire', raw);
    return raw.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
  } on Object {
    final cached = await cache.get(userId, 'questionnaire');
    if (cached == null) return const [];
    return (cached.value as List<dynamic>).map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
  }
});
