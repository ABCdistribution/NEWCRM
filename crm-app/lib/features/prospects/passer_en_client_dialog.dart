import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/ui/ui.dart';

/// Ouvre le dialogue « Passer en client ? ». Maquette : modale `confirm` l.1833-1835 et actions `en-client` / `en-client-ok` l.2029-2030.
/// Appelée par `AppRoutes.passerEnClient(context, prospectId)`.
Future<void> ouvrirPasserEnClient(BuildContext context, String prospectId) =>
    showAppDialog<void>(
      context,
      builder: (_) => PasserEnClientDialog(prospectId: prospectId),
    );

/// Dialogue « Passer en client ? » : « Annuler » le ferme ; « Passer en client » met le prospect à « Référencé » (probabilité
/// 100 %), ajoute « Étape → Référencé » à sa timeline, ferme le dialogue et affiche « Le prospect est maintenant un client. ».
class PasserEnClientDialog extends ConsumerWidget {
  const PasserEnClientDialog({super.key, required this.prospectId});

  /// Prospect concerné.
  final String prospectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DialogueBase(
      titre: 'Passer en client ?',
      children: [
        const TexteDialogue(
          'Le prospect devient un client, avec ses contacts, notes et visites. Cette action est définitive.',
        ),
        Rangee(
          children: [
            AppBouton(
              'Annuler',
              petit: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppBouton(
              'Passer en client',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: () {
                ref
                    .read(crmProvider.notifier)
                    .majProspect(
                      prospectId,
                      (p) => p.copyWith(
                        statut: StatutProspect.gagne,
                        proba: 100,
                        timeline: [
                          const EvenementProspect(
                            icone: IconeEvenement.doc,
                            couleur: 0xFFD97706,
                            titre: 'Étape → Référencé',
                            date: 'auj.',
                            detail: 'Le prospect est maintenant un client.',
                          ),
                          ...p.timeline,
                        ],
                      ),
                    );
                AppToast.show(context, 'Le prospect est maintenant un client.');
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }
}
