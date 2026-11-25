import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/erreur_api.dart';
import '../../core/envoi/corps_visite.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/sync/catalogue_provider.dart';
import '../../core/sync/detail_prospect_provider.dart';
import '../../core/sync/domaines_provider.dart';
import '../../core/ui/ui.dart';
import 'logic/actions_prospect.dart';

/// Ouvre le dialogue « Passer en client ? ». Maquette : modale `confirm` l.1833-1835 et actions `en-client` / `en-client-ok` l.2029-2030.
/// Appelée par `AppRoutes.passerEnClient(context, prospectId)`.
Future<void> ouvrirPasserEnClient(BuildContext context, String prospectId) =>
    showAppDialog<void>(
      context,
      builder: (_) => PasserEnClientDialog(prospectId: prospectId),
    );

/// Dialogue « Passer en client ? » : « Annuler » le ferme ; « Passer en client » ferme le dialogue et affiche « Le
/// prospect est maintenant un client. ».
///
/// Démonstration : le prospect passe à « Référencé » (probabilité 100 %) dans le store local, avec « Étape → Référencé »
/// en timeline. Connecté : le CRM le convertit (`POST /prospects/:id/convert`, idempotent, le serveur gagne) ; en cas de
/// refus le dialogue reste ouvert avec le message de l'API ; sinon la fiche, la liste des prospects et celle des clients
/// sont relues.
class PasserEnClientDialog extends ConsumerStatefulWidget {
  const PasserEnClientDialog({super.key, required this.prospectId});

  /// Prospect concerné.
  final String prospectId;

  @override
  ConsumerState<PasserEnClientDialog> createState() =>
      _PasserEnClientDialogState();
}

class _PasserEnClientDialogState extends ConsumerState<PasserEnClientDialog> {
  bool _envoi = false;
  String? _erreur;

  void _local() {
    ref
        .read(crmProvider.notifier)
        .majProspect(
          widget.prospectId,
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
  }

  Future<void> _convertir() async {
    if (_envoi) return;
    final conteneur = ProviderScope.containerOf(context);
    final api = ref.read(apiEcritureProvider);
    final id = widget.prospectId;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await api.envoyer('POST', cheminProspect(id, 'convert'));
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = messageErreurActionProspect(e);
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = const ErreurApi(TypeErreurApi.inattendue).message;
      });
      return;
    }
    conteneur.invalidate(detailProspectProvider(id));
    unawaited(conteneur.read(prospectsSynchroProvider.notifier).rafraichir());
    unawaited(conteneur.read(clientsProvider.notifier).rafraichir());
    if (!mounted) return;
    AppToast.show(context, 'Le prospect est maintenant un client.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DialogueBase(
      titre: 'Passer en client ?',
      children: [
        const TexteDialogue(
          'Le prospect devient un client, avec ses contacts, notes et visites. Cette action est définitive.',
        ),
        if (_erreur != null) MessageErreur(_erreur!),
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
              onPressed: _envoi
                  ? null
                  : () {
                      if (DemoTemps.reel && estUuid(widget.prospectId)) {
                        unawaited(_convertir());
                      } else {
                        _local();
                      }
                    },
            ),
          ],
        ),
      ],
    );
  }
}
