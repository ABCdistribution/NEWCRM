import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../providers.dart';
import '../visite/draft_repository.dart';

/// Visites saisies sur ce téléphone, avec leur état (brouillon, à envoyer, envoyée).
class VisitesPage extends ConsumerWidget {
  const VisitesPage({super.key});

  static (String, Color) _etat(VisiteDraft d) => switch (d.state) {
        VisiteState.terminee => ('À envoyer', StatusColors.warn),
        VisiteState.synchronisee => ('Envoyée', StatusColors.ok),
        _ => ('Brouillon', StatusColors.muted),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftsProvider).value ?? const <VisiteDraft>[];
    if (drafts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Aucune visite sur ce téléphone.\nDémarrez-en une depuis l\'accueil ou la liste des magasins.',
              textAlign: TextAlign.center, style: TextStyle(color: StatusColors.muted)),
        ),
      );
    }
    final list = [...drafts]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = list[i];
        final (label, color) = _etat(d);
        return Card(
          child: ListTile(
            onTap: () => context.push('/visite/${d.id}'),
            title: Text(d.libelle.isEmpty ? 'Visite' : d.libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(d.updatedAt)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        );
      },
    );
  }
}
