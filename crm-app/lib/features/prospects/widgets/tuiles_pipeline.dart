import 'package:flutter/material.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import 'compteur_anime.dart';

/// Les quatre tuiles du pipeline dans l'entête de la page Prospects (`.tuiles` de `.tuile.c`) : chacune compte les
/// prospects d'un groupe et, touchée, ne montre que ce groupe ; la tuile du groupe retenu est blanche.
class TuilesPipeline extends StatelessWidget {
  const TuilesPipeline({
    super.key,
    required this.compteurs,
    required this.retenu,
    required this.onTap,
  });

  /// Nombre de prospects de chaque groupe, dans l'ordre de `GroupeProspect.values`.
  final Map<GroupeProspect, int> compteurs;
  final GroupeProspect? retenu;
  final ValueChanged<GroupeProspect> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      // Les quatre tuiles ont la hauteur de la plus haute (`.tuiles` est un flex qui étire ses enfants).
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < GroupeProspect.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Tuile(
                  groupe: GroupeProspect.values[i],
                  nombre: compteurs[GroupeProspect.values[i]] ?? 0,
                  actif: retenu == GroupeProspect.values[i],
                  onTap: () => onTap(GroupeProspect.values[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.groupe,
    required this.nombre,
    required this.actif,
    required this.onTap,
  });

  final GroupeProspect groupe;
  final int nombre;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final couleurValeur = actif ? u.acc : u.encre;
    final couleurLibelle = actif ? u.acc : u.encre2;
    return Semantics(
      button: true,
      selected: actif,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: actif ? Colors.white : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            boxShadow: u.ombreDouce,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompteurAnime(
                key: ValueKey('compteur-${groupe.libelle}'),
                cle: 'pv-${groupe.libelle}',
                valeur: nombre,
                style: AppText.t(22, w: FontWeight.w800, c: couleurValeur),
              ),
              Text(
                groupe.libelle,
                textAlign: TextAlign.center,
                style: AppText.t(11.5, c: couleurLibelle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
