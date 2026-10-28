import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/role.dart';
import '../../core/db/cache_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../shell/app_shell.dart';
import '../shell/selecteur_espace.dart';
import '../tournee/tournee_page.dart' show montantCourt;
import 'pilot_repository.dart';

final pilotRepositoryProvider = Provider<PilotRepository>(
  (ref) => PilotRepository(
    ref.watch(dioProvider),
    ref.watch(cacheRepositoryProvider),
  ),
);

final pilotAccueilProvider = FutureProvider.autoDispose<Cached<AccueilPilot>>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Aucune session');
  return ref.watch(pilotRepositoryProvider).load(userId, DateTime.now());
});

/// Onglet affiché dans l'espace ABC Pilot (Tableau, Équipe, Planning, Prospects).
class PilotTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void select(int i) => state = i;
}

final pilotTabProvider = NotifierProvider<PilotTabNotifier, int>(
  PilotTabNotifier.new,
);

const _moisNoms = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Accueil d'ABC Pilot d'après la maquette : en-tête violet, CA par promoteur, équipe du jour.
class PilotAccueilPage extends ConsumerWidget {
  const PilotAccueilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pilotAccueilProvider);
    final data = async.value?.value;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pilotAccueilProvider);
          await ref
              .read(pilotAccueilProvider.future)
              .catchError(
                (_) => Cached(
                  const AccueilPilot(
                    caMois: 0,
                    evolutionPct: null,
                    mois: 1,
                    equipe: [],
                  ),
                  DateTime.now(),
                ),
              );
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Entete(data: data),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 36,
                          color: StatusColors.muted,
                        ),
                        const SizedBox(height: 8),
                        Text(errorMessage(e), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(pilotAccueilProvider),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (c) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c.fromCache)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Hors ligne — données du ${DateFormat('dd/MM HH:mm').format(c.fetchedAt)}',
                          style: const TextStyle(
                            color: StatusColors.warn,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    _CaParPromoteur(data: c.value),
                    const SizedBox(height: 22),
                    _Equipe(data: c.value),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entete extends ConsumerWidget {
  const _Entete({required this.data});

  final AccueilPilot? data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value?.user;
    final prenom = (user?.displayName ?? '')
        .split(' ')
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final initiales = (user?.displayName ?? '?')
        .split(' ')
        .where((s) => s.isNotEmpty && RegExp('[A-Za-zÀ-ÿ]').hasMatch(s[0]))
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    final violet = SpacePalette.pilot.accent;
    final n = data?.equipe.length;
    final evo = data?.evolutionPct;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 14,
        16,
        18,
      ),
      decoration: BoxDecoration(
        color: violet,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/profil'),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Text(
                    initiales.isEmpty ? '?' : initiales,
                    style: TextStyle(
                      color: violet,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour $prenom',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        user?.role.label ?? '',
                        if (n != null) '$n promoteur${n > 1 ? 's' : ''}',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const PendingBadge(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SelecteurEspace(space: Space.pilot),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Chiffre(
                  label: data == null
                      ? 'CA équipe · mois'
                      : 'CA équipe · ${_moisNoms[data!.mois - 1]}',
                  valeur: data == null ? '—' : montantCourt(data!.caMois),
                  badge: evo == null ? null : '${evo >= 0 ? '+' : ''}$evo %',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Chiffre(
                  label: 'Visites réalisées',
                  valeur: data == null ? '—' : '${data!.visitesFaites}',
                  suite: data == null
                      ? null
                      : ' / ${data!.visitesPrevues} prévues',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({
    required this.label,
    required this.valeur,
    this.badge,
    this.suite,
  });

  final String label;
  final String valeur;
  final String? badge;
  final String? suite;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valeur,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (badge != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 3),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Color(0xFF86EFAC),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (suite != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    suite!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Barres du CA du mois par promoteur (les six premiers), le premier en couleur pleine.
class _CaParPromoteur extends StatelessWidget {
  const _CaParPromoteur({required this.data});

  final AccueilPilot data;

  @override
  Widget build(BuildContext context) {
    final top = data.equipe.where((p) => p.ca > 0).take(6).toList();
    final violet = SpacePalette.pilot.accent;
    final max = top.isEmpty
        ? 1.0
        : top.map((p) => p.ca).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CA commandé par promoteur',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const Text(
                'k€ HT',
                style: TextStyle(color: StatusColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aucune commande ce mois-ci.',
                  style: TextStyle(color: StatusColors.muted),
                ),
              ),
            )
          else
            SizedBox(
              height: 128,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < top.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              (top[i].ca / 1000)
                                  .toStringAsFixed(1)
                                  .replaceAll('.', ','),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 8 + 70 * (top[i].ca / max),
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? violet
                                    : violet.withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              top[i].prenom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: StatusColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Equipe extends ConsumerWidget {
  const _Equipe({required this.data});

  final AccueilPilot data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final violet = SpacePalette.pilot.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mon équipe aujourd\'hui',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            InkWell(
              onTap: () => ref.read(pilotTabProvider.notifier).select(1),
              child: Text(
                'Tout voir',
                style: TextStyle(color: violet, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EAF2)),
          ),
          child: data.equipe.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Aucun promoteur dans votre périmètre.',
                      style: TextStyle(color: StatusColors.muted),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < data.equipe.take(6).length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Color(0xFFEEF0F6),
                        ),
                      _LignePromoteur(p: data.equipe[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

String _initiales(String nom) => nom
    .split(' ')
    .where((s) => s.isNotEmpty)
    .take(2)
    .map((s) => s[0].toUpperCase())
    .join();

class _LignePromoteur extends StatelessWidget {
  const _LignePromoteur({required this.p});

  final PromoteurEquipe p;

  @override
  Widget build(BuildContext context) {
    final violet = SpacePalette.pilot.accent;
    final part = p.visitesPrevues == 0
        ? 0.0
        : (p.visitesFaites / p.visitesPrevues).clamp(0.0, 1.0);
    final (label, couleur) = switch (p.etat) {
      EtatPromoteur.termine => ('Terminé', StatusColors.ok),
      EtatPromoteur.enRetard => ('Retard', StatusColors.warn),
      EtatPromoteur.enCours => ('En cours', violet),
      EtatPromoteur.aVenir => ('À venir', StatusColors.muted),
      EtatPromoteur.sansTournee => ('Pas de tournée', StatusColors.muted),
    };
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: violet.withValues(alpha: .12),
            child: Text(
              _initiales(p.nom),
              style: TextStyle(
                color: violet,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      p.planningConnu
                          ? '${p.visitesFaites} / ${p.visitesPrevues} visites'
                          : '— visites',
                      style: const TextStyle(
                        color: StatusColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: part,
                    minHeight: 6,
                    color: violet,
                    backgroundColor: violet.withValues(alpha: .12),
                  ),
                ),
              ],
            ),
          ),
          if (p.planningConnu) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: couleur,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Onglets d'ABC Pilot pas encore développés (Équipe, Planning, Prospects).
class PilotBientot extends StatelessWidget {
  const PilotBientot({super.key, required this.titre, required this.icon});

  final String titre;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: StatusColors.muted),
            const SizedBox(height: 12),
            Text(
              titre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ce module arrive bientôt.',
              style: TextStyle(color: StatusColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
