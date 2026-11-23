import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/session.dart';
import 'core/models/models.dart';
import 'core/state/state.dart';
import 'core/sync/catalogue_provider.dart';
import 'core/sync/domaines_provider.dart';
import 'core/sync/pem_provider.dart';
import 'core/sync/referentiels_visite_provider.dart';
import 'core/theme/theme.dart';
import 'features/auth/chargement_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/choix_profil_screen.dart';
import 'features/shell/shell_screen.dart';

/// Application « CRM ABC » : écran de choix du profil de démonstration, puis coquille du rôle choisi.
///
/// Le thème (palette bleue ou violette) suit le rôle au niveau de `MaterialApp` : feuilles et dialogues
/// héritent ainsi de la bonne palette.
class CrmApp extends ConsumerWidget {
  const CrmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    // Démarre le chargement du catalogue réel dès qu'un utilisateur est connecté ; tant qu'aucune donnée n'est
    // téléchargée (premier lancement), l'écran de chargement remplace l'application.
    final jeux = ref.watch(jeuxDeDonneesProvider).map((e) => e.$2);
    // Commandes en attente : téléchargées en arrière-plan, sans retenir l'ouverture de l'application.
    ref.watch(commandesAttenteSynchroProvider);
    // Visites PEM (propositions et articles à vérifier) : de même, en arrière-plan.
    ref.watch(propositionsPemSynchroProvider);
    if (ref.watch(attenteCrmActiveProvider)) ref.watch(articlesPemProvider);
    final continuerSansDonnees = ref.watch(continuerSansDonneesProvider);
    // Juste après une connexion, on attend la fin des téléchargements même avec une copie locale ; ensuite
    // l'attente est levée (elle ne revient qu'à la prochaine connexion).
    final apresConnexion = ref.watch(attenteConnexionProvider);
    final enCours = jeux.any((e) => e.phase == PhaseSynchro.chargement);
    if (apresConnexion && !enCours) {
      Future.microtask(
        () => ref.read(attenteConnexionProvider.notifier).terminer(),
      );
    }
    final retenu = jeux.any((e) => e.bloquant) || (apresConnexion && enCours);
    return MaterialApp(
      title: 'CRM ABC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.pour(role?.univers ?? Univers.pilot),
      themeAnimationDuration: Duration.zero,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: role != null
          ? (retenu && !continuerSansDonnees
                ? const ChargementScreen()
                : ShellScreen(key: ValueKey(role)))
          : ref.watch(modeDemoProvider)
          ? const ChoixProfilScreen()
          : const LoginScreen(),
    );
  }
}
