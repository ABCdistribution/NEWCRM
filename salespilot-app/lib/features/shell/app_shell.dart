import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/role.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../pilot/pilot_accueil_page.dart';
import '../prechargement.dart';
import 'premier_chargement.dart';
import '../pilot/pilot_planning_page.dart';

/// Pastille permanente : nombre d'éléments non envoyés, visible sur tous les écrans (CDC §4.3).
/// Neutre, orange à partir de 24 h, rouge à partir de 48 h d'ancienneté du plus vieil élément.
class PendingBadge extends ConsumerWidget {
  const PendingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingCountProvider).value ?? 0;
    final oldest = ref.watch(oldestPendingProvider).value;
    final age = oldest == null ? Duration.zero : DateTime.now().difference(oldest);

    final Color color;
    if (count == 0) {
      color = StatusColors.ok;
    } else if (age >= AppConfig.pendingAlertAfter) {
      color = StatusColors.alert;
    } else if (age >= AppConfig.pendingWarnAfter) {
      color = StatusColors.warn;
    } else {
      color = Colors.white70;
    }

    return Semantics(
      label: count == 0 ? 'Tout est synchronisé' : '$count éléments en attente d\'envoi',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/sync'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(count == 0 ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined, color: color, size: 22),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Coque de l'application : en-tête avec sélecteur d'espace et pastille, bandeau de session, navigation.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tout premier lancement : écran de chargement complet. Ensuite, la mise à jour se fait en arrière-plan.
    if (ref.watch(prechargementProvider.select((e) => e.bloquant))) return const PremierChargement();
    final space = ref.watch(spaceProvider);
    final role = ref.watch(currentRoleProvider);
    final expired = ref.watch(tokenExpiredProvider);
    final canSwitch = role?.canSwitchSpace ?? false;
    // L'accueil, les produits et la fiche magasin d'ABC Sales dessinent leur propre en-tête bleu (maquettes).
    final fiche = RegExp(r'^/magasins/[^/]+$').hasMatch(GoRouterState.of(context).uri.path);
    final accueil = space == Space.sales && (shell.currentIndex == 0 || shell.currentIndex == 4 || fiche);

    return Scaffold(
      appBar: accueil || space == Space.pilot
          ? null
          : AppBar(
              title: canSwitch ? _SpaceSwitcher(current: space) : Text(space.label),
              actions: const [PendingBadge()],
            ),
      body: Column(
        children: [
          if (expired)
            SafeArea(
              bottom: false,
              top: accueil,
              child: Material(
                color: StatusColors.warn,
                child: InkWell(
                  onTap: () => context.push('/relogin'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Icon(Icons.lock_clock, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Session expirée : reconnectez-vous pour envoyer vos saisies. Elles sont conservées.',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white),
                    ]),
                  ),
                ),
              ),
            ),
          Expanded(
            child: space == Space.pilot
                ? IndexedStack(index: ref.watch(pilotTabProvider), children: const [
                    PilotAccueilPage(),
                    PilotBientot(titre: 'Équipe', icon: Icons.groups_outlined),
                    PilotPlanningPage(),
                    PilotBientot(titre: 'Prospects', icon: Icons.track_changes),
                  ])
                // La bannière occupe déjà la zone de la barre d'état : l'en-tête de l'accueil ne la compte pas deux fois.
                : (expired && accueil ? MediaQuery.removePadding(context: context, removeTop: true, child: shell) : shell),
          ),
        ],
      ),
      bottomNavigationBar: space == Space.pilot
          ? NavigationBar(
              selectedIndex: ref.watch(pilotTabProvider),
              onDestinationSelected: (i) => ref.read(pilotTabProvider.notifier).select(i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Tableau'),
                NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Équipe'),
                NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Planning'),
                NavigationDestination(icon: Icon(Icons.track_changes), label: 'Prospects'),
              ],
            )
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
                NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on), label: 'Visites'),
                NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Commandes'),
                NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Magasins'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Produits'),
              ],
            ),
    );
  }
}

/// Sélecteur d'espace (ABC Sales / ABC Pilot) — uniquement pour les rôles qui ont accès aux deux espaces.
class _SpaceSwitcher extends ConsumerWidget {
  const _SpaceSwitcher({required this.current});

  final Space current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<Space>(
      tooltip: 'Changer d\'espace',
      onSelected: (s) => ref.read(spaceProvider.notifier).select(s),
      itemBuilder: (_) => [
        for (final s in Space.values)
          PopupMenuItem(
            value: s,
            child: Row(children: [
              Icon(s == current ? Icons.check : null, size: 18),
              const SizedBox(width: 8),
              Text('${s.label} — ${s.subtitle}'),
            ]),
          ),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(current.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        const Icon(Icons.arrow_drop_down, color: Colors.white),
      ]),
    );
  }
}
