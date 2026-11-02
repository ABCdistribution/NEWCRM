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

/// Tournée du jour : la copie locale d'abord (instantané), le réseau seulement si elle n'a jamais été chargée.
/// Elle est mise à jour à l'ouverture de la session (voir `prechargement.dart`) et par « tirer pour actualiser ».
final tourneeProvider = FutureProvider.autoDispose<TourneeJour>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Aucune session');
  final repo = ref.watch(tourneeRepositoryProvider);
  return await repo.local(userId, DateTime.now()) ?? await repo.load(userId, DateTime.now());
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

/// Lit le serveur et met la copie locale à jour. Null si le serveur est injoignable et qu'aucune copie n'existe.
Future<ObjectifMois?> chargerObjectifReseau(Ref ref, String userId) async {
  final cache = ref.read(cacheRepositoryProvider);
  try {
    final res = await ref.read(dioProvider).get<Map<String, dynamic>>('/dashboard/me');
    final raw = res.data ?? const <String, dynamic>{};
    await cache.put(userId, 'dashboard-me', raw);
    return ObjectifMois.fromJson(raw);
  } on Object {
    return _objectifLocal(ref, userId);
  }
}

Future<ObjectifMois?> _objectifLocal(Ref ref, String userId) async {
  final cached = await ref.read(cacheRepositoryProvider).get(userId, 'dashboard-me');
  if (cached == null) return null;
  return ObjectifMois.fromJson(Map<String, dynamic>.from(cached.value as Map));
}

/// Copie locale d'abord ; null (« — » à l'écran) si le mois n'a jamais été chargé et que le réseau manque.
final objectifMoisProvider = FutureProvider.autoDispose<ObjectifMois?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return await _objectifLocal(ref, userId) ?? await chargerObjectifReseau(ref, userId);
});

final magasinRepositoryProvider =
    Provider<MagasinRepository>((ref) => MagasinRepository(ref.watch(dioProvider), ref.watch(cacheRepositoryProvider)));

/// Liste des magasins : copie locale d'abord, réseau seulement au tout premier chargement.
final magasinsProvider = FutureProvider.autoDispose<Cached<List<Magasin>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Aucune session');
  final repo = ref.watch(magasinRepositoryProvider);
  return await repo.local(userId) ?? await repo.loadAll(userId);
});

final produitRepositoryProvider =
    Provider<ProduitRepository>((ref) => ProduitRepository(ref.watch(dioProvider), ref.watch(cacheRepositoryProvider)));

/// Référentiel produits : copie locale d'abord, réseau seulement au tout premier chargement.
final produitsProvider = FutureProvider.autoDispose<Cached<List<Produit>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Aucune session');
  final repo = ref.watch(produitRepositoryProvider);
  return await repo.local(userId) ?? await repo.loadAll(userId);
});

List<Question> _questions(Object? raw) =>
    (raw as List<dynamic>).map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();

/// Lit le serveur et met la copie locale à jour ; en cas d'échec, renvoie la copie locale (ou rien).
Future<List<Question>> chargerQuestionnaireReseau(Ref ref, String userId) async {
  final cache = ref.read(cacheRepositoryProvider);
  try {
    final res = await ref.read(dioProvider).get<List<dynamic>>('/questionnaire');
    final raw = res.data ?? const [];
    await cache.put(userId, 'questionnaire', raw);
    return _questions(raw);
  } on Object {
    final cached = await cache.get(userId, 'questionnaire');
    return cached == null ? const [] : _questions(cached.value);
  }
}

/// Questionnaire de visite : copie locale d'abord (la visite doit s'ouvrir sans attendre), réseau au premier chargement.
final questionnaireProvider = FutureProvider.autoDispose<List<Question>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final cached = await ref.read(cacheRepositoryProvider).get(userId, 'questionnaire');
  return cached != null ? _questions(cached.value) : chargerQuestionnaireReseau(ref, userId);
});
