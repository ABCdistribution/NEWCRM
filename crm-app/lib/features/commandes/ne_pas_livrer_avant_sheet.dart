import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'state/commande_provider.dart';
import 'widgets/champ_date.dart';

/// Motifs proposés pour une consigne « Ne pas livrer avant » (`motifs` de la modale `cmd-pas`).
const List<String> motifsConsigne = ['Impératif', 'Inventaire'];

/// Ouvre la feuille « Ne pas livrer avant… ». Maquette : modale `cmd-pas` l.1359-1368 et actions l.1495-1508.
/// Appelée par `AppRoutes.nePasLivrerAvant(context)`.
///
/// La feuille modifie la consigne au fil des choix. Fermée autrement que par « Valider » (« Annuler », appui sur
/// le voile, glissement), elle abandonne la consigne si elle est incomplète (`pas-annuler`).
Future<void> ouvrirNePasLivrerAvant(BuildContext context) async {
  final conteneur = ProviderScope.containerOf(context);
  final validee = await showAppSheet<bool>(
    context,
    builder: (_) => const NePasLivrerAvantSheet(),
  );
  if (validee != true) {
    conteneur.read(commandeEnCoursProvider.notifier).annulerConsigne();
  }
}

/// Feuille « Ne pas livrer avant… » : encadré « ⚠ Important », motif (Impératif / Inventaire), date minimale
/// (obligatoire), Annuler / Valider.
class NePasLivrerAvantSheet extends ConsumerWidget {
  const NePasLivrerAvantSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cmd = ref.watch(commandeEnCoursProvider);
    final notifier = ref.read(commandeEnCoursProvider.notifier);
    final motif = cmd?.motifPas ?? '';
    final dateMin = cmd?.dateMin ?? '';

    void valider() {
      if (motif.isEmpty) {
        AppToast.show(context, 'Choisissez le motif de cette consigne.');
        return;
      }
      if (motif == 'Autre' && (cmd?.motifAutre.trim().isEmpty ?? true)) {
        AppToast.show(context, 'Précisez le motif.');
        return;
      }
      if (dateMin.isEmpty) {
        AppToast.show(
          context,
          'Indiquez la date avant laquelle ne pas livrer.',
        );
        return;
      }
      Navigator.of(context).pop(true);
    }

    return FeuilleBase(
      children: [
        const EncadreImportant(
          titre: '⚠ Important',
          texte:
              "Cette consigne est transmise à l'ADV : indiquez pourquoi et à partir de quand le client peut être livré.",
        ),
        // Titre sans marge basse : celle de `.feuille h3` (10 px) se fusionne avec la marge haute de « MOTIF » (14 px).
        Text('Ne pas livrer avant…', style: AppText.titreFeuille),
        const TitreFiltre('Motif'),
        for (final m in motifsConsigne)
          OptionRadio(
            label: m,
            selectionne: motif == m,
            onTap: () => notifier.choisirMotif(m),
          ),
        ChampDate(
          label: 'Ne pas livrer avant le *',
          valeur: dateMin,
          onChanged: notifier.majDateMin,
          margeHaut: 12,
        ),
        Rangee(
          margeHaut: 6,
          children: [
            AppBouton(
              'Annuler',
              petit: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppBouton(
              'Valider',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: valider,
            ),
          ],
        ),
      ],
    );
  }
}
