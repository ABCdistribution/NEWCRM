import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nav/nav_bar.dart';
import '../../core/nav/onglets.dart';
import '../../core/state/state.dart';
import '../../core/ui/page_univers.dart';
import 'ecran_onglet.dart';

/// Coquille de l'application pour un profil : l'écran de l'onglet courant, la barre de navigation du rôle
/// et le menu « + » (dropup). Les écrans empilés sont des routes posées par-dessus (voir `AppRoutes`).
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    final onglet = ref.watch(ongletProvider);
    final plusOuvert = ref.watch(menuPlusOuvertProvider);
    final config = configNavPour(role);
    final bas = MediaQuery.paddingOf(context).bottom;
    void aller(OngletApp o) {
      ref.read(ongletProvider.notifier).aller(o);
      ref.read(menuPlusOuvertProvider.notifier).fermer();
    }

    return PopScope(
      canPop: !plusOuvert,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(menuPlusOuvertProvider.notifier).fermer();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            body: FondSousBarre(
              hauteur: hauteurNav + bas,
              child: KeyedSubtree(
                key: ValueKey('${role.name}-${onglet.name}'),
                child: ecranPourOnglet(onglet),
              ),
            ),
            bottomNavigationBar: AppNavBar(
              onglets: config.barre,
              actif: onglet,
              onSelect: aller,
              plusActif: config.plus.contains(onglet),
              plusOuvert: plusOuvert,
              onPlus: ref.read(menuPlusOuvertProvider.notifier).basculer,
            ),
          ),
          if (plusOuvert) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: ref.read(menuPlusOuvertProvider.notifier).fermer,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              right: 10,
              bottom: hauteurNav + bas + 10,
              child: MenuPlus(
                onglets: config.plus,
                actif: onglet,
                onSelect: aller,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
