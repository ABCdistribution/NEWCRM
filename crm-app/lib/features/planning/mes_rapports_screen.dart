import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/rapports_demo.dart';
import 'state/planning_state.dart';

/// Onglet « Mes rapports » (chef de secteur, directeur ; menu « + »). Maquette : `pageRapportsMes` l.1054-1068.
///
/// La carte « Semaine 45 · en cours » renvoie au planning ; les rapports précédents ouvrent leur détail
/// (`AppRoutes.detailRapport`). Une fois la semaine 45 validée, elle rejoint la liste des rapports précédents.
class MesRapportsScreen extends ConsumerWidget {
  const MesRapportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planningProvider);
    final etapes = ref.watch(etapesProvider);
    final precedents = ref.watch(rapportsPrecedentsProvider);
    final prevision = plan.prevision;

    final String detail;
    if (plan.phase == PhasePlanning.prevision) {
      detail = prevision != null
          ? "${prevision.length} lignes prévues · modifiable jusqu'au lundi soir"
          : 'Prévision à saisir';
    } else {
      detail =
          '${prevision?.length ?? etapes.length} lignes ${prevision != null ? 'prévues' : 'saisies'} · validation automatique lundi à 4 h';
    }

    return PageUnivers(
      entete: const AppEntete(titre: 'Mes rapports', tailleTitre: 24),
      enfants: [
        if (!plan.verrouillee)
          _CarteEnCours(
            detail: detail,
            badge: plan.phase == PhasePlanning.prevision ? 'Prévision' : 'Auto',
            onTap: () => AppRoutes.allerOnglet(context, OngletApp.planning),
          ),
        TitreLigne(
          'Rapports précédents',
          droite: Text(
            '${DemoTemps.aujourdhui.year}',
            style: AppText.t(13, c: AppColors.muted),
          ),
        ),
        for (final r in precedents)
          _CarteRapport(
            rapport: r,
            onTap: () => AppRoutes.detailRapport(context, r.numero),
          ),
      ],
    );
  }
}

/// Carte jaune de la semaine en cours (`.rap-carte`).
class _CarteEnCours extends StatelessWidget {
  const _CarteEnCours({
    required this.detail,
    required this.badge,
    required this.onTap,
  });

  final String detail;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 22),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF9E7),
          border: Border.all(color: const Color(0xFFF3E3A1)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE9A8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '📄',
                style: AppText.t(16, c: const Color(0xFFB45309)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semaine ${DemoTemps.semaineCourante} · en cours',
                    style: AppText.t(15, w: FontWeight.w700),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(detail, style: AppText.sousCarte),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Pastille(
              badge,
              fond: const Color(0xFFFCE9A8),
              texte: AppColors.pJauneTexte,
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'un rapport précédent : semaine, période, pastille « Validé auto », chiffres, pied et écarts.
class _CarteRapport extends StatelessWidget {
  const _CarteRapport({required this.rapport, required this.onTap});

  final RapportSemaine rapport;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = rapport;
    final u = context.univers;
    return AppCarte(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Semaine ${r.numero}', style: AppText.titreCarte),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(r.periode, style: AppText.sousCarte),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pastille(
                !r.valide
                    ? 'Non validé'
                    : r.auto
                    ? 'Validé auto'
                    : 'Validé',
                variante: !r.valide
                    ? VariantePastille.jaune
                    : r.auto
                    ? VariantePastille.gris
                    : VariantePastille.vert,
              ),
            ],
          ),
          Chiffres([
            Chiffre('${r.visites}', 'visites'),
            if (r.pct != null) Chiffre('${r.pct} %', 'du prévu'),
            Chiffre('${r.rdv}', 'RDV obtenus'),
          ]),
          Pied(r.pied),
          if (r.ecartsConnus)
            Pied(
              'Écarts avec la prévision : ${resumeEcarts(r.ecarts.map((e) => e.genre))}',
              style: AppText.t(11.5, w: FontWeight.w700, c: u.violet),
            ),
        ],
      ),
    );
  }
}
