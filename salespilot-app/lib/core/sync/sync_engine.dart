// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'outbox_repository.dart';
import 'outbox_transport.dart';

/// Bilan d'une passe de synchronisation.
class SyncReport {
  const SyncReport({this.sent = 0, this.retry = 0, this.rejected = 0, this.blocked = 0, this.sessionExpired = false});

  final int sent;
  final int retry;
  final int rejected;

  /// Éléments non traités car leur parent n'est pas (encore) confirmé.
  final int blocked;

  /// L'envoi s'est arrêté sur une session expirée : rien n'est perdu, reprise après reconnexion.
  final bool sessionExpired;

  bool get hasNothing => sent + retry + rejected + blocked == 0 && !sessionExpired;

  @override
  String toString() => 'SyncReport(envoyés: $sent, à réessayer: $retry, refusés: $rejected, bloqués: $blocked, '
      'session expirée: $sessionExpired)';
}

/// Rejoue la file d'envoi : dans l'ordre de création, en respectant les dépendances (une photo part après sa visite),
/// avec une attente progressive entre les essais. Un refus définitif ne bloque que les éléments qui en dépendent.
class SyncEngine {
  SyncEngine({
    required OutboxRepository repo,
    required OutboxTransport transport,
    Duration Function(int attempts)? backoff,
  }) : _repo = repo, _transport = transport, _backoff = backoff ?? defaultBackoff;

  final OutboxRepository _repo;
  final OutboxTransport _transport;
  final Duration Function(int attempts) _backoff;

  /// Un seul envoi à la fois : une passe lancée pendant une autre attend la suivante.
  Future<SyncReport>? _running;

  /// 5 s, 10 s, 20 s… plafonné à 15 min.
  static Duration defaultBackoff(int attempts) {
    final seconds = 5 * (1 << (attempts.clamp(0, 10)));
    return Duration(seconds: seconds.clamp(5, 15 * 60));
  }

  /// Lance une passe pour [userId]. Si une passe est déjà en cours, renvoie la même (pas de double envoi).
  Future<SyncReport> run(String userId) => _running ??= _runOnce(userId).whenComplete(() => _running = null);

  Future<SyncReport> _runOnce(String userId) async {
    var sent = 0, retry = 0, rejected = 0, blocked = 0;
    final batch = await _repo.due(userId);

    for (final item in batch) {
      // Dépendance : le parent doit être confirmé (relu à chaque tour, il a pu être envoyé juste avant).
      String? parentServerId;
      if (item.parentIdApk != null) {
        final parent = await _repo.findParent(userId, item.parentIdApk!);
        if (parent == null) {
          await _repo.markError(item.id, reason: 'Élément parent introuvable.');
          rejected++;
          continue;
        }
        if (parent.status == OutboxStatus.error) {
          await _repo.markError(item.id, reason: 'Bloqué : l\'élément dont il dépend est en erreur.');
          rejected++;
          continue;
        }
        if (parent.status != OutboxStatus.sent || parent.serverId == null) {
          blocked++; // le parent n'est pas encore parti : on réessaiera à la prochaine passe
          continue;
        }
        parentServerId = parent.serverId;
      }

      await _repo.markSending(item.id);
      final result = await _transport.send(item, parentServerId: parentServerId);

      switch (result) {
        case Sent(:final serverId):
          await _repo.markSent(item.id, serverId: serverId);
          sent++;
        case RetryLater(:final reason):
          final attempts = item.attempts + 1;
          await _repo.markRetry(item.id, attempts: attempts, reason: reason, wait: _backoff(attempts));
          retry++;
        case Rejected(:final reason):
          await _repo.markError(item.id, reason: reason, attempts: item.attempts + 1);
          rejected++;
        case Unauthorized():
          // Remet l'élément à envoyer, sans compter d'essai : la session, pas la donnée, est en cause.
          await _repo.retryNow(item.id);
          return SyncReport(sent: sent, retry: retry, rejected: rejected, blocked: blocked, sessionExpired: true);
      }
    }
    return SyncReport(sent: sent, retry: retry, rejected: rejected, blocked: blocked);
  }
}
