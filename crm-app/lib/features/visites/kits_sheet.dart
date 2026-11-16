import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/visites_data.dart';
import 'state/actions_visite.dart';

/// Ouvre la feuille « Kits du rayon ». Maquette : modale `kits` l.1352-1358 et `KITS` l.354-359.
/// Appelée par `AppRoutes.kitsDuRayon(context, visiteId)`.
Future<void> ouvrirKitsDuRayon(BuildContext context, String visiteId) =>
    showAppSheet<void>(context, builder: (_) => KitsSheet(visiteId: visiteId));

/// Feuille « Kits du rayon » : cases à cocher des kits constatés en rayon, « Tout décocher » et « Valider (N) ».
class KitsSheet extends ConsumerWidget {
  const KitsSheet({super.key, required this.visiteId});

  /// Visite en cours.
  final String visiteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choisis =
        ref.watch(visiteParIdProvider(visiteId))?.kits ?? const <String>[];
    final actions = ActionsVisite(ref.read(crmProvider.notifier), visiteId);
    return FeuilleBase(
      titre: 'Kits du rayon',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Cochez les kits constatés en rayon pour la distribution numérique.',
            style: AppText.t(13, c: AppColors.muted),
          ),
        ),
        for (final k in kitsDemo)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => actions.basculerKit(k.code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.ligne)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: k.nom,
                            style: AppText.t(14.5, w: FontWeight.w700),
                          ),
                          TextSpan(
                            text:
                                '\n${k.marque.isEmpty ? '' : '${k.marque} · '}Réf. ${k.code}',
                            style: AppText.t(12.5, c: AppColors.muted),
                          ),
                        ],
                      ),
                      style: AppText.t(15),
                      strutStyle: const StrutStyle(
                        fontFamily: AppText.famille,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CaseCoche(cochee: choisis.contains(k.code)),
                ],
              ),
            ),
          ),
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Tout décocher',
              petit: true,
              onPressed: actions.viderKits,
            ),
            AppBouton(
              'Valider (${choisis.length})',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}
