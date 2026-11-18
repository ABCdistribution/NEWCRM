import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/equipe_serveur.dart';
import '../../core/data/planning_serveur.dart';
import '../../core/logic/logic.dart';
import '../../core/sync/planning_equipe_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/equipe_demo.dart';
import 'data/semaine_reelle.dart';
import 'widgets/lignes_equipe.dart';

/// Une semaine du rapport d'un chef de secteur (écran empilé `cs-sem`). Maquette : pageSemaineCS l.817-835.
/// Ouverte par `AppRoutes.semaineChefSecteur(context, csId: ..., numSemaine: ...)` ; `numSemaine` va de 45 à 39.
///
/// Rapport d'activité en lecture seule : prévu et réalisé, écarts avec la prévision (pour la semaine 44 de Nadia H.,
/// le réalisé ligne à ligne), puis la prévision enregistrée, que le bouton affiche ou masque.
class SemaineCsScreen extends ConsumerStatefulWidget {
  const SemaineCsScreen({
    super.key,
    required this.csId,
    required this.numSemaine,
  });

  final String csId;
  final int numSemaine;

  @override
  ConsumerState<SemaineCsScreen> createState() => _SemaineCsScreenState();
}

class _SemaineCsScreenState extends ConsumerState<SemaineCsScreen> {
  /// La prévision est masquée à l'ouverture (`voirPrev`).
  bool _voirPrevision = false;

  /// Lundi (« yyyy-mm-dd ») de la semaine de ce numéro, parmi celles autour de la semaine courante.
  String? _lundiDuNumero(int numero) {
    final base = DemoTemps.lundi;
    for (var decalage = -12; decalage <= 6; decalage++) {
      final lundi = DateTime(base.year, base.month, base.day + 7 * decalage);
      if (DemoTemps.numeroSemaine(lundi) == numero) return isoJour(lundi);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = chefActuelParId(widget.csId);
    if (cs == null) {
      return const PageUnivers(
        entete: TopbarEcran(titre: 'Rapport'),
        enfants: [Vide('Chef de secteur introuvable.')],
      );
    }
    final SemaineCs? w;
    if (cs.reel) {
      // Chef de secteur du CRM : rapport chargé à l'ouverture (copie locale d'abord).
      final lundi = _lundiDuNumero(widget.numSemaine);
      final rapport = lundi == null
          ? null
          : ref
                .watch(rapportEquipeProvider((userId: cs.id, lundi: lundi)))
                .value;
      w = rapport == null ? null : semaineCsDepuisRapport(rapport);
      if (w == null) {
        return PageUnivers(
          entete: TopbarEcran(
            titre: 'Semaine ${widget.numSemaine}',
            sous: cs.nom,
          ),
          paddingCorps: false,
          corps: const CorpsSousTopbar(
            children: [Vide('Rapport indisponible pour cette semaine.')],
          ),
        );
      }
    } else {
      w = semainesChefSecteur(
        cs.id,
      ).firstWhere((x) => x.n == widget.numSemaine);
    }
    return PageUnivers(
      entete: TopbarEcran(
        titre: 'Semaine ${w.n}${w.enCours ? ' · en cours' : ''}',
        sous: '${cs.nom} · ${w.periode}',
        droite: pastilleSemaine(w),
      ),
      paddingCorps: false,
      corps: CorpsSousTopbar(
        children: [
          const SectionTitre("RAPPORT D'ACTIVITÉ", margeHaut: 0),
          ..._rapport(w),
          if (w.valide != null)
            Pied('Validé${w.auto ? ' automatiquement' : ''} le ${w.valide}'),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppBouton(
              _voirPrevision ? '▲ Masquer la prévision' : '▼ Voir la prévision',
              onPressed: () => setState(() => _voirPrevision = !_voirPrevision),
            ),
          ),
          if (_voirPrevision) ...[
            const SectionTitre('PRÉVISION ENREGISTRÉE'),
            if (w.prevision.isEmpty)
              const Vide('Aucune prévision enregistrée.')
            else
              for (final l in w.prevision) LignePrevisionEnregistree(l),
          ],
          const Pied('Lecture seule.', centre: true, margeHaut: 10),
        ],
      ),
    );
  }

  /// Le rapport : message sans prévision, comparaison ligne à ligne (semaine 44 de Nadia H.) ou écarts.
  List<Widget> _rapport(SemaineCs w) {
    if (w.nonRenseignee) {
      return const [
        Vide(
          'Prévision non renseignée cette semaine : pas de comparaison possible.',
        ),
      ];
    }
    final cmp = w.comparaison;
    return [
      Text(
        'Prévu ${w.prevues} · Réalisé ${w.realisees} (${w.pct} %)',
        style: AppText.t(16, w: FontWeight.w700, c: context.univers.violet),
      ),
      BarreProgression(valeur: w.pct! / 100),
      const SizedBox(height: 12),
      if (cmp != null) ...[
        const TitreFiltre("Ce qui s'est réellement passé", margeHaut: 0),
        for (final x in cmp.lignes) _LigneComparee(x),
        const TitreFiltre('Prévu mais non réalisé'),
        if (cmp.manquees.isEmpty)
          const Vide('Rien : tout a été fait.')
        else
          for (final x in cmp.manquees) _LigneComparee(x),
      ] else ...[
        const TitreFiltre('Écarts avec la prévision', margeHaut: 0),
        if (w.ecarts.isEmpty)
          const Vide("Aucun écart : tout s'est passé comme prévu.")
        else
          ListeEcarts(w.ecarts),
      ],
    ];
  }
}

/// Style d'une ligne comparée (`BADGE` de pageSemaineCS) : symbole, texte, fond et libellé.
const Map<GenreComparaison, (String, Color, Color, String)> _badges = {
  GenreComparaison.fait: (
    '✓',
    Color(0xFF166534),
    Color(0xFFDDF5E6),
    'Comme prévu',
  ),
  GenreComparaison.deplace: (
    '↔',
    Color(0xFF92400E),
    Color(0xFFFCEFC6),
    'Déplacé',
  ),
  GenreComparaison.ajoute: (
    '＋',
    Color(0xFF1E3A8A),
    Color(0xFFDFE8FF),
    'Non prévu',
  ),
  GenreComparaison.retire: (
    '✕',
    Color(0xFF991B1B),
    Color(0xFFFEE2E2),
    'Prévu, non réalisé',
  ),
};

class _LigneComparee extends StatelessWidget {
  const _LigneComparee(this.ligne);

  final LigneComparee ligne;

  @override
  Widget build(BuildContext context) {
    final (symbole, texte, fond, libelle) = _badges[ligne.genre]!;
    final detail = ligne.genre == GenreComparaison.deplace
        ? 'prévu ${ligne.prevu!.quand} → réalisé ${ligne.reel.quand}'
        : ligne.reel.quand;
    return LigneEcart(
      titre: ligne.reel.titre,
      detail: '$libelle · $detail',
      symbole: symbole,
      fond: fond,
      texte: texte,
    );
  }
}
