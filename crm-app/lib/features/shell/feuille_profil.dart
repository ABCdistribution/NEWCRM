import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/ui/ui.dart';
import '../../core/theme/theme.dart';

/// Ouvre la feuille « Changer de profil (démo) » : un appui sur l'avatar de l'accueil.
Future<void> ouvrirChangerProfil(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const FeuilleProfil());

/// Feuille de choix du profil de démonstration (promoteur, chef de secteur, directeur régional).
///
/// Choisir un profil ferme tous les écrans empilés et réinitialise les données partagées.
class FeuilleProfil extends ConsumerWidget {
  const FeuilleProfil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reel = ref.watch(sessionProvider);
    if (reel != null) {
      // Utilisateur connecté : l'avatar propose seulement la déconnexion.
      return FeuilleBase(
        titre: reel.nomAffiche,
        children: [
          AppBouton(
            'Se déconnecter',
            onPressed: () {
              final session = ref.read(sessionProvider.notifier);
              Navigator.of(context).popUntil((route) => route.isFirst);
              session.deconnecter();
            },
          ),
        ],
      );
    }
    final actif = ref.watch(roleActifProvider);
    return FeuilleBase(
      titre: 'Changer de profil (démo)',
      titreDroite: const Pastille('Démo', variante: VariantePastille.jaune),
      children: [
        for (final r in Role.values)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              ref.read(roleProvider.notifier).choisir(r);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.ligne)),
              ),
              child: Row(
                children: [
                  Avatar(
                    r.profil.initiales,
                    taille: 40,
                    fond: r.univers == Univers.sales
                        ? AppColors.pBleuFond
                        : const Color(0xFFE7E0F7),
                    texte: r.univers == Univers.sales
                        ? AppColors.pBleuTexte
                        : UniversPalette.pilot.violet,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.profil.libelle,
                          style: AppText.t(15, w: FontWeight.w700),
                        ),
                        Text(
                          '${r.profil.nom} · ${r.univers == Univers.sales ? 'univers bleu' : 'univers violet'}',
                          style: AppText.sousCarte,
                        ),
                      ],
                    ),
                  ),
                  Radio20(selectionne: r == actif),
                ],
              ),
            ),
          ),
        const Pied('Données fictives de démonstration.'),
      ],
    );
  }
}
