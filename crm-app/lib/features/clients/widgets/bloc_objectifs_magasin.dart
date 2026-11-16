import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

/// Objectifs et opérations promotionnelles (OP) d'un magasin (maquette : `blocObjMag` l.1800-1804) : CA du mois sur
/// objectif avec sa barre, puis la liste des OP et leur état. Données de démonstration, stables par magasin.
class BlocObjectifsMagasin extends StatelessWidget {
  const BlocObjectifsMagasin(this.magasin, {super.key});

  final Magasin magasin;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final o = objectifMagasin(magasin);
    final pct = math.min(100, o.pct);
    return AppCarte(
      margeBas: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CA / objectif du mois',
                style: AppText.t(12, c: AppColors.muted),
              ),
              Text(
                '$pct %',
                style: AppText.t(12, w: FontWeight.w700, c: AppColors.muted),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              '${eur(o.ca)} / ${eur(o.obj)}',
              style: AppText.t(18, w: FontWeight.w800),
            ),
          ),
          BarreProgression(
            valeur: pct / 100,
            couleur: u.bleu,
            fond: AppColors.barreFond,
            margeHaut: 0,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              'Opérations promotionnelles (OP)',
              style: AppText.t(12, c: AppColors.muted),
            ),
          ),
          for (final op in o.ops) _LigneOp(op),
        ],
      ),
    );
  }
}

/// Une opération promotionnelle (`.ecart` sans rond) : nom, période, pastille d'état.
class _LigneOp extends StatelessWidget {
  const _LigneOp(this.op);

  final OperationPromo op;

  @override
  Widget build(BuildContext context) {
    final variante = switch (op.etat) {
      EtatOp.enCours => VariantePastille.vert,
      EtatOp.aVenir => VariantePastille.bleu,
      EtatOp.terminee => VariantePastille.gris,
    };
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
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '${op.du} → ${op.au}',
                    style: AppText.t(12, c: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Pastille(op.etat.libelle, variante: variante),
        ],
      ),
    );
  }
}
