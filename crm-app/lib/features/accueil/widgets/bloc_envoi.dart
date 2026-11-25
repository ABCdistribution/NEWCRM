import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/envois_base.dart';
import '../../../core/envoi/envoi_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

/// Pastille de la file d'envoi vers le CRM : nombre d'éléments « À envoyer » et en erreur, avec « Relancer ». Rien
/// n'est affiché quand la file est vide (et en démonstration, où rien ne part).
class BlocEnvoi extends ConsumerWidget {
  const BlocEnvoi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(envoiProvider);
    if (etat.vide) return const SizedBox.shrink();
    return AppCarte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (etat.aEnvoyer > 0)
                Pastille(
                  '${etat.aEnvoyer} à envoyer',
                  variante: VariantePastille.jaune,
                ),
              if (etat.aEnvoyer > 0 && etat.enErreur > 0)
                const SizedBox(width: 8),
              if (etat.enErreur > 0)
                Pastille(
                  '${etat.enErreur} en erreur',
                  variante: VariantePastille.rouge,
                ),
              const Spacer(),
              AppBouton(
                'Relancer',
                petit: true,
                pleineLargeur: false,
                onPressed: etat.enCours
                    ? null
                    : () => ref.read(envoiProvider.notifier).relancer(),
              ),
            ],
          ),
          for (final e in etat.erreurs)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${e.libelle ?? (e.type == TypeEnvoi.visite ? 'Visite' : 'Commande')} · ${e.message}',
                style: AppText.sousCarte,
              ),
            ),
        ],
      ),
    );
  }
}
