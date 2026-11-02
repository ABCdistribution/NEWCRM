import '../prechargement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../providers.dart';
import 'magasin_repository.dart';

enum _Etat { tous, actifs, inactifs }

/// Magasins du portefeuille (recherche et filtre actif / inactif). Avec [pick], l'appui démarre une visite non
/// planifiée au lieu d'ouvrir la fiche.
class MagasinsPage extends ConsumerStatefulWidget {
  const MagasinsPage({super.key, this.pick = false});

  final bool pick;

  @override
  ConsumerState<MagasinsPage> createState() => _MagasinsPageState();
}

class _MagasinsPageState extends ConsumerState<MagasinsPage> {
  var _q = '';
  var _etat = _Etat.tous;

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp('[éèêë]'), 'e').replaceAll(RegExp('[àâä]'), 'a').replaceAll(RegExp('[îï]'), 'i').replaceAll(RegExp('[ôö]'), 'o').replaceAll(RegExp('[ùûü]'), 'u').replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(magasinsProvider);
    return Column(children: [
      if (widget.pick)
        Container(
          width: double.infinity,
          color: SpacePalette.sales.active,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Text('Visite non planifiée : choisissez le magasin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Enseigne, ville, code…'),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(spacing: 8, children: [
          for (final e in _Etat.values)
            ChoiceChip(
              label: Text(switch (e) { _Etat.tous => 'Tous', _Etat.actifs => 'Actifs', _Etat.inactifs => 'Inactifs' }),
              selected: _etat == e,
              onSelected: (_) => setState(() => _etat = e),
            ),
        ]),
      ),
      Expanded(
        child: async.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(errorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => ref.invalidate(magasinsProvider), child: const Text('Réessayer')),
              ]),
            ),
          ),
          data: (cached) {
            final q = _norm(_q.trim());
            final list = cached.value.where((m) {
              if (_etat == _Etat.actifs && !m.actif) return false;
              if (_etat == _Etat.inactifs && m.actif) return false;
              if (q.isEmpty) return true;
              return _norm('${m.enseigne} ${m.ville ?? ''} ${m.codeAs400} ${m.raisonSociale ?? ''}').contains(q);
            }).toList();
            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(miseAJourLocaleProvider).magasins();
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: list.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${list.length} magasin${list.length > 1 ? 's' : ''}'
                        '${cached.fromCache ? ' — hors ligne, données du ${DateFormat('dd/MM HH:mm').format(cached.fetchedAt)}' : ''}',
                        style: TextStyle(color: cached.fromCache ? StatusColors.warn : StatusColors.muted, fontSize: 12),
                      ),
                    );
                  }
                  return _Tuile(magasin: list[i - 1], pick: widget.pick);
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _Tuile extends ConsumerWidget {
  const _Tuile({required this.magasin, required this.pick});

  final Magasin magasin;
  final bool pick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = magasin;
    final etat = switch (m.etat) { 'alerte' => StatusColors.alert, 'attention' => StatusColors.warn, _ => StatusColors.ok };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () async {
          if (pick) {
            final userId = ref.read(currentUserIdProvider);
            if (userId == null) return;
            final id = await ref.read(visiteServiceProvider).startOrResume(userId: userId, clientId: m.id, libelle: m.enseigne);
            if (context.mounted) context.push('/visite/$id');
          } else {
            context.push('/magasins/${m.id}', extra: m);
          }
        },
        leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: m.actif ? etat : StatusColors.muted, shape: BoxShape.circle)),
        title: Text(m.enseigne, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          if (m.ville != null && m.ville!.isNotEmpty) m.ville!,
          m.derniereVisiteJours == null ? 'Jamais visité' : 'Visité il y a ${m.derniereVisiteJours} j',
          if (!m.actif) 'Inactif',
        ].join(' · ')),
        trailing: m.niveauClass == null
            ? null
            : CircleAvatar(radius: 14, backgroundColor: const Color(0xFFE5E7EB), child: Text(m.niveauClass!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black87))),
      ),
    );
  }
}
