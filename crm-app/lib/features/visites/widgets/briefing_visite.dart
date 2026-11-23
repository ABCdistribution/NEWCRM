import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../state/briefing_magasin.dart';

/// Bloc « Briefing » en haut de la visite : replié sur une ligne, ou déplié sur le contenu du briefing. N'apparaît pas
/// quand le magasin n'a rien à montrer.
class BlocBriefing extends ConsumerWidget {
  const BlocBriefing({
    super.key,
    required this.magasinId,
    required this.ouvert,
    required this.onBasculer,
  });

  final String magasinId;
  final bool ouvert;
  final VoidCallback onBasculer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(briefingMagasinProvider(magasinId));
    if (b.vide) return const SizedBox.shrink();
    return AppCarte(
      margeBas: 14,
      onTap: ouvert ? null : onBasculer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ouvert ? onBasculer : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Briefing',
                    style: AppText.t(15, w: FontWeight.w800),
                  ),
                ),
                if (!ouvert && b.alertes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pastille(
                      '${b.alertes.length} alerte${b.alertes.length > 1 ? 's' : ''}',
                      variante: VariantePastille.rouge,
                    ),
                  ),
                Text(
                  ouvert ? '⌃' : '⌄',
                  style: AppText.t(16, w: FontWeight.w700, c: AppColors.muted),
                ),
              ],
            ),
          ),
          if (ouvert) ContenuBriefing(briefing: b),
        ],
      ),
    );
  }
}

/// Feuille du briefing, ouverte depuis l'en-tête de la visite à n'importe quelle étape.
Future<void> ouvrirBriefing(BuildContext context, String magasinId) =>
    showAppSheet<void>(
      context,
      builder: (_) => Consumer(
        builder: (context, ref, _) => FeuilleBase(
          titre: 'Briefing',
          children: [
            ContenuBriefing(
              briefing: ref.watch(briefingMagasinProvider(magasinId)),
              premier: true,
            ),
          ],
        ),
      ),
    );

/// Les trois rubriques du briefing ; une rubrique sans contenu n'est pas affichée.
class ContenuBriefing extends StatelessWidget {
  const ContenuBriefing({
    super.key,
    required this.briefing,
    this.premier = false,
  });

  final BriefingMagasin briefing;

  /// Vrai quand le contenu ouvre une feuille : la première rubrique n'a pas de marge haute.
  final bool premier;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    final o = briefing.objectif;
    var debut = premier;
    double haut() {
      final h = debut ? 0.0 : 8.0;
      debut = false;
      return h;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (o != null) ...[
          SectionTitre('Objectifs', couleur: bleu, margeHaut: haut()),
          _LigneObjectif(o),
        ],
        if (briefing.operations.isNotEmpty) ...[
          SectionTitre(
            'Opérations à proposer',
            couleur: bleu,
            margeHaut: haut(),
          ),
          for (final op in briefing.operations) _LigneOperation(op),
        ],
        if (briefing.alertes.isNotEmpty) ...[
          SectionTitre('Alertes du magasin', couleur: bleu, margeHaut: haut()),
          for (final a in briefing.alertes) _LigneAlerte(a),
        ],
      ],
    );
  }
}

class _LigneObjectif extends StatelessWidget {
  const _LigneObjectif(this.o);

  final ObjectifMois o;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CA du mois / objectif mensuel',
              style: AppText.t(12, c: AppColors.muted),
            ),
            Text(
              '${o.taux} %',
              style: AppText.t(
                12,
                w: FontWeight.w700,
                c: couleurObjectif(o.taux),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${eur(o.ca)} / ${eur(o.objectif)}',
            style: AppText.t(17, w: FontWeight.w800),
          ),
        ),
        BarreObjectif(real: o.ca, cible: o.objectif),
      ],
    );
  }
}

class _LigneOperation extends StatelessWidget {
  const _LigneOperation(this.op);

  final OperationPromo op;

  @override
  Widget build(BuildContext context) {
    final periode = periodeOperation(op);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.ligne)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(op.nom, style: AppText.t(13.5, w: FontWeight.w700)),
                if (periode.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      periode,
                      style: AppText.t(12, c: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Pastille(
            op.etat.libelle,
            variante: op.etat == EtatOp.enCours
                ? VariantePastille.vert
                : VariantePastille.bleu,
          ),
        ],
      ),
    );
  }
}

class _LigneAlerte extends StatelessWidget {
  const _LigneAlerte(this.a);

  final Alerte a;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(a.icone, style: AppText.t(15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              a.detail,
              style: AppText.t(
                13.5,
                w: FontWeight.w600,
                c: a.niveau == NiveauAlerte.haut
                    ? AppColors.alert
                    : AppColors.texte,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
