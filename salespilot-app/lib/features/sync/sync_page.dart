import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/outbox_transport.dart';
import '../../core/theme/app_theme.dart';

final _unsentProvider = StreamProvider.autoDispose<List<OutboxItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(outboxRepositoryProvider).watchUnsent(userId);
});

final _othersProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  ref.watch(_unsentProvider); // recalcule quand la file change
  return ref.read(outboxRepositoryProvider).countUnsentOfOthers(userId);
});

String _kindLabel(String kind) => switch (kind) {
      OutboxKind.visite => 'Visite',
      OutboxKind.visiteCommerciale => 'Visite commerciale',
      OutboxKind.photo => 'Photo',
      OutboxKind.commande => 'Commande',
      OutboxKind.note => 'Note',
      _ => kind,
    };

/// Écran de synchronisation : éléments en attente par état, dernière synchro réussie, erreurs et « Réessayer ».
class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_unsentProvider).value ?? const <OutboxItem>[];
    final status = ref.watch(syncControllerProvider);
    final others = ref.watch(_othersProvider).value ?? 0;
    final expired = ref.watch(tokenExpiredProvider);
    final userId = ref.watch(currentUserIdProvider);
    final errors = items.where((i) => i.status == OutboxStatus.error).length;
    final fmt = DateFormat('dd/MM HH:mm');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/')),
        title: const Text('Synchronisation'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(items.isEmpty ? Icons.cloud_done : Icons.cloud_upload, color: items.isEmpty ? StatusColors.ok : StatusColors.warn, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items.isEmpty ? 'Tout est synchronisé' : '${items.length} élément${items.length > 1 ? 's' : ''} en attente',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  status.lastSuccessAt == null
                      ? 'Aucune synchronisation réussie depuis l\'ouverture de l\'application.'
                      : 'Dernière synchronisation réussie : ${fmt.format(status.lastSuccessAt!)}',
                  style: const TextStyle(color: StatusColors.muted),
                ),
                if (expired)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Session expirée : reconnectez-vous pour envoyer.', style: TextStyle(color: StatusColors.warn.withValues(alpha: 1), fontWeight: FontWeight.w600)),
                  ),
                if (others > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('$others élément(s) appartiennent à un autre utilisateur de ce téléphone : ils partiront à sa reconnexion.',
                        style: const TextStyle(color: StatusColors.muted)),
                  ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: status.running ? null : () => ref.read(syncControllerProvider.notifier).run(),
                  icon: status.running
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync),
                  label: Text(status.running ? 'Synchronisation…' : 'Synchroniser maintenant'),
                ),
                if (errors > 0) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: userId == null
                        ? null
                        : () async {
                            await ref.read(outboxRepositoryProvider).retryAllErrors(userId);
                            await ref.read(syncControllerProvider.notifier).run();
                          },
                    icon: const Icon(Icons.replay),
                    label: Text('Réessayer les $errors en erreur'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),
          for (final i in items)
            Card(
              child: ListTile(
                leading: Icon(
                  i.status == OutboxStatus.error ? Icons.error_outline : Icons.schedule,
                  color: i.status == OutboxStatus.error ? StatusColors.alert : StatusColors.warn,
                ),
                title: Text(_kindLabel(i.kind)),
                subtitle: Text([
                  'Saisi le ${fmt.format(i.createdAt)}',
                  if (i.status == OutboxStatus.error) 'Refusé : ${i.lastError ?? 'motif inconnu'}' else if (i.lastError != null) 'Nouvel essai : ${i.lastError}',
                  if (i.attempts > 0) '${i.attempts} essai(s)',
                ].join('\n')),
                isThreeLine: i.lastError != null,
              ),
            ),
        ],
      ),
    );
  }
}
