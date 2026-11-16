import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/ui/ui.dart';
import 'kilometrage_dialog.dart';
import 'logic/visites_logique.dart';
import 'state/actions_visite.dart';
import 'state/envoi_visites.dart';
import 'state/kilometrage.dart';

/// Ouvre le dialogue « Valider la visite ? ». Maquette : modale `svalider` l.1397-1400 et actions l.1561-1567.
/// Appelée par `AppRoutes.validerVisite(context, visiteId)`.
Future<void> ouvrirValiderVisite(BuildContext context, String visiteId) =>
    showAppDialog<void>(
      context,
      builder: (_) => ValiderVisiteDialog(visiteId: visiteId),
    );

/// Dialogue « Valider la visite ? » : « Valider la visite ? » si les 7 étapes sont horodatées, sinon « Visite incomplète » et la liste de ce qui manque.
class ValiderVisiteDialog extends ConsumerWidget {
  const ValiderVisiteDialog({super.key, required this.visiteId});

  /// Visite à valider.
  final String visiteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visite = ref.watch(visiteParIdProvider(visiteId));
    if (visite == null) return const SizedBox.shrink();
    final manque = manquants(visite);
    final ok = manque.isEmpty;
    return DialogueBase(
      titre: ok ? 'Valider la visite ?' : 'Visite incomplète',
      children: [
        if (ok)
          const TexteDialogue(
            "La visite DPH est complète (7 étapes horodatées). Une fois validée, elle part dès que le réseau le permet et n'est plus modifiable.",
          )
        else ...[
          const TexteDialogue('Il reste à faire :'),
          for (final b in manque) MessageErreur(b, compact: true),
        ],
        Rangee(
          children: [
            AppBouton(
              ok ? 'Continuer' : 'Corriger',
              petit: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (ok)
              AppBouton(
                'Valider',
                petit: true,
                variante: VarianteBouton.plein,
                onPressed: () => _valider(context, ref, visite),
              ),
          ],
        ),
      ],
    );
  }

  /// Termine la visite, revient à l'écran racine (l'accueil pour le promoteur), propose le kilométrage d'arrivée
  /// quand la tournée est finie et programme l'envoi simulé (`v-valider-ok`).
  void _valider(BuildContext context, WidgetRef ref, Visite visite) {
    final role = ref.read(roleActifProvider);
    ActionsVisite(ref.read(crmProvider.notifier), visiteId).terminer();

    // Ferme le dialogue et tous les écrans empilés, et garde un contexte qui reste affiché pour la suite.
    BuildContext? racine;
    Navigator.of(context, rootNavigator: true).popUntil((r) {
      if (r.isFirst && r is ModalRoute) racine = r.subtreeContext;
      return r.isFirst;
    });
    final ecran = racine ?? context;

    if (role == Role.promoteur) {
      ref.read(ongletProvider.notifier).aller(OngletApp.accueil);
      ref.read(menuPlusOuvertProvider.notifier).fermer();
      final km = ref.read(kilometrageProvider);
      if (!km.arriveePropose && !tourneeRestante(ref.read(crmProvider))) {
        ref
            .read(kilometrageProvider.notifier)
            .maj((k) => k.copyWith(arriveePropose: true));
        ouvrirKilometrage(ecran, PhaseKilometrage.arrivee);
      }
    }
    AppToast.show(
      ecran,
      'Visite #${visite.num} validée. Envoi dès que le réseau le permet.',
    );
    ref.read(envoiVisitesProvider).programmer(visiteId, ecran);
  }
}
