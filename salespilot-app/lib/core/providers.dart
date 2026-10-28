import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'auth/role.dart';
import 'auth/session.dart';
import 'config.dart';
import '../features/visite/draft_repository.dart';
import '../features/visite/visite_service.dart';
import 'db/app_database.dart';
import 'db/cache_repository.dart';
import 'sync/outbox_repository.dart';
import 'sync/outbox_transport.dart';
import 'sync/sync_engine.dart';

// --- Session -----------------------------------------------------------------------------------------------------------

final sessionStoreProvider = Provider<SessionStore>((ref) => SecureSessionStore());

/// Vrai quand le serveur a répondu 401 : le jeton a expiré. La lecture hors ligne reste possible, l'envoi
/// reprend après reconnexion (CDC §6.2).
class TokenExpiredNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final tokenExpiredProvider = NotifierProvider<TokenExpiredNotifier, bool>(TokenExpiredNotifier.new);

class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final stored = await ref.read(sessionStoreProvider).read();
    if (stored == null) return null;
    // Au-delà de la fenêtre hors ligne, reconnexion obligatoire. Les données non envoyées restent en base,
    // rattachées à leur propriétaire : rien n'est perdu.
    if (!stored.isWithinOfflineWindow(DateTime.now(), AppConfig.offlineReadWindow)) return null;
    return stored;
  }

  /// Connexion par identifiant et mot de passe AD. Lève une erreur lisible via [errorMessage].
  Future<void> login(String username, String password) async {
    if (AppConfig.devLogin) {
      final session = Session(
        token: AppConfig.devToken,
        user: SessionUser(id: 'dev-user', username: username.trim(), displayName: '${username.trim()} (dev)', role: Role.admin),
        authenticatedAt: DateTime.now(),
      );
      await ref.read(sessionStoreProvider).write(session);
      state = AsyncData(session);
      return;
    }
    final res = await ref.read(dioProvider).post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username.trim(), 'password': password},
    );
    final data = res.data!;
    final session = Session(
      token: data['accessToken'] as String,
      user: SessionUser.fromJson(data['user'] as Map<String, dynamic>),
      authenticatedAt: DateTime.now(),
    );
    await ref.read(sessionStoreProvider).write(session);
    ref.read(tokenExpiredProvider.notifier).set(false);
    state = AsyncData(session);
  }

  /// Déconnexion : efface le jeton. La file d'envoi est CONSERVÉE (rattachée à son propriétaire) et repartira à sa
  /// reconnexion — la suppression de données non envoyées exige une confirmation séparée.
  Future<void> logout() async {
    await ref.read(sessionStoreProvider).clear();
    ref.read(tokenExpiredProvider.notifier).set(false);
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

/// Identifiant de l'utilisateur connecté (null si déconnecté).
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(sessionProvider).value?.user.id);

/// Rôle de l'utilisateur connecté.
final currentRoleProvider = Provider<Role?>((ref) => ref.watch(sessionProvider).value?.user.role);

// --- Espace (Sales / Pilot) ----------------------------------------------------------------------------------------------

class SpaceNotifier extends Notifier<Space> {
  @override
  Space build() => Space.sales; // ABC Sales est l'espace par défaut pour tous les rôles

  /// N'accepte que les espaces autorisés pour le rôle : masquer un écran ne remplace pas le contrôle du serveur,
  /// mais l'application ne propose jamais un espace interdit.
  void select(Space space) {
    final role = ref.read(currentRoleProvider);
    if (role != null && role.spaces.contains(space)) state = space;
  }
}

final spaceProvider = NotifierProvider<SpaceNotifier, Space>(SpaceNotifier.new);

// --- Réseau, base locale, file d'envoi -----------------------------------------------------------------------------------

final dioProvider = Provider<Dio>((ref) {
  final store = ref.read(sessionStoreProvider);
  return buildDio(
    token: () => ref.read(sessionProvider).value?.token,
    installId: store.installId,
    onUnauthorized: () {
      if (ref.read(sessionProvider).value?.token == AppConfig.devToken) return; // connexion de dev : 401 attendu
      ref.read(tokenExpiredProvider.notifier).set(true);
    },
  );
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final outboxRepositoryProvider = Provider<OutboxRepository>((ref) => OutboxRepository(ref.watch(databaseProvider)));

final cacheRepositoryProvider = Provider<CacheRepository>((ref) => CacheRepository(ref.watch(databaseProvider)));

final draftRepositoryProvider = Provider<DraftRepository>((ref) => DraftRepository(ref.watch(databaseProvider)));

final visiteServiceProvider = Provider<VisiteService>(
  (ref) => VisiteService(ref.watch(databaseProvider), ref.watch(draftRepositoryProvider), ref.watch(outboxRepositoryProvider)),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(repo: ref.watch(outboxRepositoryProvider), transport: HttpOutboxTransport(ref.watch(dioProvider))),
);

/// Nombre d'éléments non confirmés par le serveur (pastille permanente, CDC §4.3).
final pendingCountProvider = StreamProvider.autoDispose<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(0);
  return ref.watch(outboxRepositoryProvider).watchPendingCount(userId);
});

/// Date du plus ancien élément non confirmé (couleur de la pastille).
final oldestPendingProvider = StreamProvider.autoDispose<DateTime?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);
  return ref.watch(outboxRepositoryProvider).watchOldestPending(userId);
});

/// État de la synchronisation, pour l'écran dédié.
class SyncStatus {
  const SyncStatus({this.running = false, this.lastReport, this.lastRunAt, this.lastSuccessAt});

  final bool running;
  final SyncReport? lastReport;
  final DateTime? lastRunAt;
  final DateTime? lastSuccessAt;

  SyncStatus copyWith({bool? running, SyncReport? lastReport, DateTime? lastRunAt, DateTime? lastSuccessAt}) =>
      SyncStatus(
        running: running ?? this.running,
        lastReport: lastReport ?? this.lastReport,
        lastRunAt: lastRunAt ?? this.lastRunAt,
        lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      );
}

/// Déclenche la synchronisation : au retour du réseau, périodiquement et sur demande.
class SyncController extends Notifier<SyncStatus> {
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _net;

  @override
  SyncStatus build() {
    _net = Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((c) => c != ConnectivityResult.none)) unawaited(run());
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => unawaited(run()));
    ref.onDispose(() {
      _timer?.cancel();
      _net?.cancel();
    });
    return const SyncStatus();
  }

  Future<void> run() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || state.running) return;
    state = state.copyWith(running: true);
    try {
      final report = await ref.read(syncEngineProvider).run(userId);
      // Les visites dont tout est confirmé (visite + photos) passent en « synchronisée ».
      await ref.read(visiteServiceProvider).reconcile(userId);
      if (report.sessionExpired && ref.read(sessionProvider).value?.token != AppConfig.devToken) ref.read(tokenExpiredProvider.notifier).set(true);
      final ok = report.rejected == 0 && report.retry == 0 && !report.sessionExpired;
      state = state.copyWith(
        running: false,
        lastReport: report,
        lastRunAt: DateTime.now(),
        lastSuccessAt: ok && !report.hasNothing ? DateTime.now() : state.lastSuccessAt,
      );
    } on Object {
      state = state.copyWith(running: false, lastRunAt: DateTime.now());
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);
