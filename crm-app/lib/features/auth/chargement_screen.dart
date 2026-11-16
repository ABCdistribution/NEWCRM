import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/catalogue_provider.dart';
import '../../core/sync/domaines_provider.dart';
import '../../core/theme/theme.dart';

/// Écran affiché après la connexion tant que les données ne sont pas toutes téléchargées dans la base locale
/// (premier lancement). Même style que la connexion : fond blanc, logo, violet de l'espace Direction.
class ChargementScreen extends ConsumerWidget {
  const ChargementScreen({super.key});

  static const _violet = Color(0xFF7656B8);
  static const _texte = Color(0xFF171717);
  static const _discret = Color(0xFF737373);
  static const _fondBarre = Color(0xFFE5E5E5);

  static String _nombre(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les jeux de données encore sans copie locale : seuls ceux-là retiennent l'utilisateur.
    final attendus = ref
        .watch(jeuxDeDonneesProvider)
        .where((e) => e.$2.bloquant || e.$2.phase == PhaseSynchro.chargement)
        .toList();
    final enCours = attendus.any((e) => e.$2.phase == PhaseSynchro.chargement);
    final enEchec = attendus.firstWhere(
      (e) => e.$2.phase != PhaseSynchro.chargement,
      orElse: () =>
          attendus.isEmpty ? ('', const EtatSynchro()) : attendus.first,
    );
    final totalRecus = attendus.fold<int>(0, (a, e) => a + e.$2.recus);
    final totalAnnonce = attendus.fold<int>(0, (a, e) => a + e.$2.total);
    final etat = enEchec.$2;
    final avance = totalAnnonce > 0
        ? (totalRecus / totalAnnonce).clamp(0.0, 1.0)
        : null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 96,
                        height: 96,
                        semanticLabel: 'ABC Group',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    enCours
                        ? 'Chargement des données'
                        : 'Chargement impossible',
                    textAlign: TextAlign.center,
                    style: AppText.t(24, w: FontWeight.w800, c: _texte),
                  ),
                  const SizedBox(height: 24),
                  if (enCours) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: avance,
                        minHeight: 8,
                        color: _violet,
                        backgroundColor: _fondBarre,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (totalAnnonce == 0)
                      Text(
                        'Connexion au serveur…',
                        textAlign: TextAlign.center,
                        style: AppText.t(14, c: _discret),
                      )
                    else
                      for (final e in attendus)
                        if (e.$2.total > 0)
                          Text(
                            '${e.$1} : ${_nombre(e.$2.recus)} / ${_nombre(e.$2.total)}',
                            textAlign: TextAlign.center,
                            style: AppText.t(14, c: _discret),
                          ),
                  ] else ...[
                    Text(
                      etat.phase == PhaseSynchro.horsLigne
                          ? 'Serveur injoignable. Vérifiez votre connexion.'
                          : (etat.message ?? 'Une erreur est survenue.'),
                      textAlign: TextAlign.center,
                      style: AppText.t(14, c: _discret),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => rafraichirTout(ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: _texte,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Réessayer',
                        style: AppText.t(
                          16,
                          w: FontWeight.w500,
                          c: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref
                          .read(continuerSansDonneesProvider.notifier)
                          .continuer(),
                      child: Text(
                        'Continuer sans données',
                        style: AppText.t(14, c: _discret),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
