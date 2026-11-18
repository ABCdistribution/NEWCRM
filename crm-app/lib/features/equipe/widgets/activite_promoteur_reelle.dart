import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/state/state.dart';
import '../../../core/ui/ui.dart';
import 'lignes_equipe.dart';

/// Visites et commandes récentes d'un promoteur du CRM (lecture seule), prises dans les données téléchargées :
/// les visites des 60 derniers jours et les commandes rattachées à son code représentant.
class ActiviteDuPromoteur extends ConsumerStatefulWidget {
  const ActiviteDuPromoteur({super.key, required this.userId});

  /// Identifiant du promoteur dans le CRM.
  final String? userId;

  @override
  ConsumerState<ActiviteDuPromoteur> createState() =>
      _ActiviteDuPromoteurState();
}

class _ActiviteDuPromoteurState extends ConsumerState<ActiviteDuPromoteur> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    final id = widget.userId;
    final etat = ref.watch(crmProvider);
    final visites = [
      for (final v in [...etat.visites, ...etat.visitesAutres])
        if (id != null && v.parId == id) v,
    ];
    final commandes = [
      for (final c in etat.commandes)
        if (id != null && c.auteurId == id) c,
    ];
    String client(String magasinId) => etat.magasinParId(magasinId)?.nom ?? '';
    final liste = _onglet == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segment(
          libelles: [
            'Visites (${visites.length})',
            'Commandes (${commandes.length})',
          ],
          index: _onglet,
          onChanged: (i) => setState(() => _onglet = i),
        ),
        if (liste && visites.isEmpty) const Vide('Aucune visite récente.'),
        if (!liste && commandes.isEmpty) const Vide('Aucune commande.'),
        if (liste)
          for (final v in visites)
            CarteVisiteLecture(
              client: client(v.magasinId),
              detail: v.date,
              enCours: v.etat == EtatVisite.brouillon,
            )
        else
          for (final c in commandes)
            CarteCommandeLecture(
              ht: c.ht,
              detail: '${c.id} · ${client(c.magasinId)} · ${c.date}',
              statut: c.statut,
            ),
        const Pied('Lecture seule.', centre: true),
      ],
    );
  }
}
