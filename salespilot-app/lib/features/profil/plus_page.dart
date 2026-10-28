import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// Profil, état de l'application et déconnexion (CDC §3.11).
class PlusPage extends ConsumerWidget {
  const PlusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    if (session == null) return const SizedBox.shrink();
    final u = session.user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text(_initiales(u.displayName))),
            title: Text(u.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${u.role.label}\n${u.username}'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Synchronisation'),
              subtitle: Text(pending == 0 ? 'Tout est synchronisé' : '$pending élément(s) en attente'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/sync'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Version de l\'application'),
              subtitle: const Text(AppConfig.appVersion),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _logout(context, ref, pending),
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: StatusColors.alert),
        ),
      ],
    );
  }

  String _initiales(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  /// Déconnexion : si des éléments ne sont pas envoyés, l'utilisateur est averti. Ils sont CONSERVÉS pour leur
  /// propriétaire et repartent à sa reconnexion (CDC §6.2).
  Future<void> _logout(BuildContext context, WidgetRef ref, int pending) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: Text(pending == 0
            ? 'Vous devrez saisir à nouveau votre mot de passe.'
            : '$pending élément(s) ne sont pas encore envoyés. Ils restent conservés sur ce téléphone et partiront '
                'à votre prochaine connexion.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (ok == true) await ref.read(sessionProvider.notifier).logout();
  }
}
