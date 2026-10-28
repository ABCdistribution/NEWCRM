import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// États d'un élément de la file d'envoi.
abstract final class OutboxStatus {
  static const pending = 'pending';
  static const sending = 'sending';
  static const sent = 'sent';
  static const error = 'error';
}

/// Accès à la file d'envoi. Toutes les opérations sont cloisonnées par [userId].
class OutboxRepository {
  OutboxRepository(this._db, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  $OutboxItemsTable get _t => _db.outboxItems;

  /// Ajoute un élément. **Idempotent** : si `(userId, kind, idApk)` existe déjà, rien n'est créé et
  /// l'identifiant de l'élément existant est renvoyé.
  Future<int> enqueue({
    required String userId,
    required String kind,
    required String idApk,
    required Map<String, dynamic> payload,
    String? filePath,
    String? parentIdApk,
  }) async {
    final existing = await findByIdApk(userId, kind, idApk);
    if (existing != null) return existing.id;
    return _db.into(_t).insert(
          OutboxItemsCompanion.insert(
            userId: userId,
            kind: kind,
            idApk: idApk,
            payload: jsonEncode(payload),
            filePath: Value(filePath),
            parentIdApk: Value(parentIdApk),
            createdAt: _now(),
          ),
        );
  }

  Future<OutboxItem?> findByIdApk(String userId, String kind, String idApk) {
    return (_db.select(_t)
          ..where((r) => r.userId.equals(userId) & r.kind.equals(kind) & r.idApk.equals(idApk)))
        .getSingleOrNull();
  }

  /// Parent d'un élément dépendant : recherché par `idApk` seul (tous types confondus).
  Future<OutboxItem?> findParent(String userId, String parentIdApk) {
    return (_db.select(_t)
          ..where((r) => r.userId.equals(userId) & r.idApk.equals(parentIdApk))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<OutboxItem?> byId(int id) => (_db.select(_t)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Éléments à traiter, du plus ancien au plus récent : à envoyer, dont l'échéance de nouvel essai est passée.
  /// Les éléments « sending » restés bloqués (application tuée en plein envoi) sont repris.
  Future<List<OutboxItem>> due(String userId) async {
    final now = _now();
    final rows = await (_db.select(_t)
          ..where((r) =>
              r.userId.equals(userId) &
              (r.status.equals(OutboxStatus.pending) | r.status.equals(OutboxStatus.sending)))
          ..orderBy([(r) => OrderingTerm.asc(r.createdAt), (r) => OrderingTerm.asc(r.id)]))
        .get();
    return rows.where((r) => r.nextAttemptAt == null || !r.nextAttemptAt!.isAfter(now)).toList();
  }

  Future<void> markSending(int id) => _update(id, OutboxItemsCompanion(status: const Value(OutboxStatus.sending)));

  Future<void> markSent(int id, {String? serverId}) => _update(
        id,
        OutboxItemsCompanion(
          status: const Value(OutboxStatus.sent),
          serverId: Value(serverId),
          sentAt: Value(_now()),
          lastError: const Value(null),
          nextAttemptAt: const Value(null),
        ),
      );

  /// Échec temporaire : l'élément reste à envoyer, avec une attente progressive avant le nouvel essai.
  Future<void> markRetry(int id, {required int attempts, required String reason, required Duration wait}) => _update(
        id,
        OutboxItemsCompanion(
          status: const Value(OutboxStatus.pending),
          attempts: Value(attempts),
          lastError: Value(reason),
          nextAttemptAt: Value(_now().add(wait)),
        ),
      );

  /// Refus définitif du serveur (ou dépendance en erreur) : conservé avec son motif.
  Future<void> markError(int id, {required String reason, int? attempts}) => _update(
        id,
        OutboxItemsCompanion(
          status: const Value(OutboxStatus.error),
          lastError: Value(reason),
          attempts: attempts == null ? const Value.absent() : Value(attempts),
        ),
      );

  /// Remet un élément en erreur dans la file (bouton « Réessayer »).
  Future<void> retryNow(int id) => _update(
        id,
        const OutboxItemsCompanion(
          status: Value(OutboxStatus.pending),
          lastError: Value(null),
          nextAttemptAt: Value(null),
        ),
      );

  Future<void> retryAllErrors(String userId) async {
    await (_db.update(_t)..where((r) => r.userId.equals(userId) & r.status.equals(OutboxStatus.error))).write(
      const OutboxItemsCompanion(
        status: Value(OutboxStatus.pending),
        lastError: Value(null),
        nextAttemptAt: Value(null),
      ),
    );
  }

  /// Supprime des éléments non envoyés (réouverture d'une visite avant envoi). Jamais ceux déjà confirmés.
  Future<int> deleteUnsent(String userId, List<String> idApks) {
    return (_db.delete(_t)
          ..where((r) =>
              r.userId.equals(userId) & r.idApk.isIn(idApks) & r.status.isNotValue(OutboxStatus.sent)))
        .go();
  }

  Future<void> _update(int id, OutboxItemsCompanion c) => (_db.update(_t)..where((r) => r.id.equals(id))).write(c);

  // --- Observation (compteur permanent, écran de synchronisation) ---------------------------------------------------

  /// Éléments **non confirmés** : à envoyer, en cours ou en erreur. C'est le nombre de la pastille permanente.
  Stream<int> watchPendingCount(String userId) {
    final count = countAll();
    final q = _db.selectOnly(_t)
      ..addColumns([count])
      ..where(_t.userId.equals(userId) & _t.status.isNotValue(OutboxStatus.sent));
    return q.map((r) => r.read(count) ?? 0).watchSingle();
  }

  /// Date du plus ancien élément non confirmé (pour la couleur de la pastille : 24 h orange, 48 h rouge).
  Stream<DateTime?> watchOldestPending(String userId) {
    final minDate = _t.createdAt.min();
    final q = _db.selectOnly(_t)
      ..addColumns([minDate])
      ..where(_t.userId.equals(userId) & _t.status.isNotValue(OutboxStatus.sent));
    return q.map((r) => r.read(minDate)).watchSingle();
  }

  Stream<List<OutboxItem>> watchUnsent(String userId) {
    return (_db.select(_t)
          ..where((r) => r.userId.equals(userId) & r.status.isNotValue(OutboxStatus.sent))
          ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
        .watch();
  }

  Stream<List<OutboxItem>> watchByIdApks(String userId, List<String> idApks) {
    return (_db.select(_t)..where((r) => r.userId.equals(userId) & r.idApk.isIn(idApks))).watch();
  }

  /// Éléments non envoyés appartenant à d'AUTRES utilisateurs de ce téléphone (CDC §4.2).
  Future<int> countUnsentOfOthers(String userId) async {
    final count = countAll();
    final q = _db.selectOnly(_t)
      ..addColumns([count])
      ..where(_t.userId.equals(userId).not() & _t.status.isNotValue(OutboxStatus.sent));
    return (await q.map((r) => r.read(count) ?? 0).getSingle());
  }
}
