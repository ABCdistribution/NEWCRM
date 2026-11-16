import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';

/// Ouvre la feuille « Changer d'étape ». Maquette : modale `feuille-etape` l.1830-1832 et action `etape-vers` l.2028.
/// Appelée par `AppRoutes.changerEtapeProspect(context, prospectId)`.
Future<void> ouvrirChangerEtape(BuildContext context, String prospectId) =>
    showAppSheet<void>(
      context,
      builder: (_) => ChangerEtapeSheet(prospectId: prospectId),
    );

/// Étapes proposées : de « Fiche créée » à « Perdu », sans « Référencé » qui passe par « Passer en client ».
const List<StatutProspect> _etapesProposees = [
  StatutProspect.nouveau,
  StatutProspect.contacte,
  StatutProspect.visite,
  StatutProspect.proposition,
  StatutProspect.negociation,
  StatutProspect.perdu,
];

/// Feuille « Changer d'étape » : six étapes (Fiche créée … Perdu), coche sur l'étape courante. Choisir une autre étape
/// change le statut et la probabilité du prospect, ajoute « Étape → … » à sa timeline, ferme la feuille et affiche
/// « Étape : … ». Toucher l'étape courante ne fait rien.
class ChangerEtapeSheet extends ConsumerWidget {
  const ChangerEtapeSheet({super.key, required this.prospectId});

  /// Prospect concerné.
  final String prospectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courante = ref.watch(
      prospectParIdProvider(prospectId).select((p) => p?.statut),
    );
    return FeuilleBase(
      titre: "Changer d'étape",
      children: [
        for (final s in _etapesProposees)
          _RangeeEtape(
            libelle: s.libelle,
            coche: courante == s,
            onTap: () {
              if (courante == s) return;
              ref
                  .read(crmProvider.notifier)
                  .changerEtapeProspect(prospectId, s);
              AppToast.show(context, 'Étape : ${s.libelle}.');
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

/// Ligne de choix d'une feuille (`.feuille .ch`) : libellé à gauche, coche à droite, filet dessous.
class _RangeeEtape extends StatelessWidget {
  const _RangeeEtape({
    required this.libelle,
    required this.coche,
    required this.onTap,
  });

  final String libelle;
  final bool coche;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.ligne)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(libelle, style: AppText.t(15)),
            if (coche) Text('✓', style: AppText.t(15)),
          ],
        ),
      ),
    );
  }
}
