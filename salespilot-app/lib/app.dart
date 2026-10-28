import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/commandes/commandes_page.dart';
import 'features/visites/visites_page.dart';
import 'features/magasins/magasin_repository.dart';
import 'features/magasins/magasin_fiche_page.dart';
import 'features/magasins/magasins_page.dart';
import 'features/produits/produits_page.dart';
import 'features/profil/plus_page.dart';
import 'features/shell/app_shell.dart';
import 'features/sync/sync_page.dart';
import 'features/tournee/tournee_page.dart';
import 'features/visite/visite_page.dart';

/// Navigation. La redirection suit la session : sans session (ou hors de la fenêtre de lecture hors ligne),
/// on arrive sur la connexion ; la reconnexion après expiration du jeton (`/relogin`) reste accessible.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (session.isLoading) return loc == '/splash' ? null : '/splash';
      if (session.value == null) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/relogin', builder: (_, _) => const LoginPage(relogin: true)),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const TourneePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/visites', builder: (_, _) => const VisitesPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/commandes', builder: (_, _) => const CommandesPage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/magasins',
              builder: (_, state) => MagasinsPage(pick: state.uri.queryParameters['pick'] == '1'),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => MagasinFichePage(id: state.pathParameters['id']!, magasin: state.extra as Magasin?),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/produits', builder: (_, _) => const ProduitsPage())]),
        ],
      ),
      GoRoute(path: '/visite/:id', builder: (_, state) => VisitePage(id: state.pathParameters['id']!)),
      GoRoute(path: '/sync', builder: (_, _) => const SyncPage()),
      // Profil : accessible depuis l'avatar des accueils (la navigation du bas porte désormais les Produits).
      GoRoute(
        path: '/profil',
        builder: (_, _) => Scaffold(appBar: AppBar(title: const Text('Profil')), body: const PlusPage()),
      ),
    ],
  );
});

class SalesPilotApp extends ConsumerWidget {
  const SalesPilotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(spaceProvider);
    // Le moteur de synchronisation tourne dès que l'application est ouverte (réseau retrouvé, minuterie).
    ref.watch(syncControllerProvider);
    return MaterialApp.router(
      title: 'SalesPilot',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(space),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
