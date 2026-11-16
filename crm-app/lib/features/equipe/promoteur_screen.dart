import '../../core/data/equipe_serveur.dart';
import 'resume_activite.dart';
import 'package:flutter/material.dart';

import '../../core/data/data.dart';
import '../../core/logic/logic.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'state/filtres.dart';
import 'widgets/lignes_equipe.dart';
import 'widgets/planning_equipe.dart';

/// Page d'un promoteur vue par son encadrement (écran empilé `promo-page`). Maquette : pagePromo l.891-905.
/// Ouverte par `AppRoutes.pagePromoteur(context, csId: ..., nom: ...)` ; `nom` doit être celui d'un promoteur de la démo.
///
/// Chiffres de la semaine et du mois, puis trois onglets : « Planning » (modifiable par l'encadrement, via la feuille
/// de saisie du lot planning), « Visites » et « Commandes » (lecture seule, filtrables par client).
class PromoteurScreen extends StatefulWidget {
  const PromoteurScreen({super.key, required this.csId, required this.nom});

  /// Chef de secteur du promoteur (« n », « k » ou « s »).
  final String csId;

  /// Nom court du promoteur (« Léa P. »).
  final String nom;

  @override
  State<PromoteurScreen> createState() => _PromoteurScreenState();
}

class _PromoteurScreenState extends State<PromoteurScreen> {
  /// Onglet affiché : le planning à l'ouverture (`promoTab`).
  int _onglet = 0;

  /// Client choisi dans la liste déroulante (`promoClient`).
  String _client = filtreTous;

  /// Décalage de la semaine du planning par rapport à la semaine 45 (`promoSem`).
  int _semaine = 0;

  @override
  Widget build(BuildContext context) {
    final reel = promoteurActuelParNom(widget.nom);
    if (reel != null && reel.reel) {
      return ResumeActivite(
        titre: reel.nom,
        sous: 'Promoteur · ${reel.mag} clients',
        visites: reel.v,
        commandes: reel.commandes,
        ca: reel.real,
        objectif: reel.cible,
      );
    }
    final p = promoteurParNom(widget.nom)!;
    final a = activitePromoteur(
      nom: p.nom,
      visitesPrevues: p.v,
      mag: p.mag,
      jour: p.jour,
    );
    final planning = _onglet == 0;
    final clients = triStable({
      for (final v in a.visites) v.client,
      for (final c in a.commandes) c.client,
    }, compareFr);
    final client = clients.contains(_client) ? _client : filtreTous;
    final visites = [
      for (final v in a.visites)
        if (client == filtreTous || v.client == client) v,
    ];
    final commandes = [
      for (final c in a.commandes)
        if (client == filtreTous || c.client == client) c,
    ];
    final affichees = _onglet == 1 ? visites.length : commandes.length;
    return PageUnivers(
      entete: TopbarEcran(titre: p.nom, sous: 'Promoteur · ${p.mag} clients'),
      paddingCorps: false,
      corps: CorpsSousTopbar(
        children: [
          KpiRangee([
            KpiItem('Visites semaine', '${p.v}/${p.p}'),
            KpiItem(
              'Réalisé',
              eur(p.real),
              couleurValeur: couleurObjectif(p.obj),
            ),
            KpiItem('Objectif', eur(p.cible)),
          ]),
          Segment(
            libelles: [
              'Planning',
              'Visites (${a.visites.length})',
              'Commandes (${a.commandes.length})',
            ],
            index: _onglet,
            onChanged: (i) => setState(() {
              _onglet = i;
              _client = filtreTous;
            }),
          ),
          if (!planning)
            ChampListe<String>(
              label: 'Client',
              valeur: client,
              margeBas: 8,
              options: {
                filtreTous: 'Tous les clients (${clients.length})',
                for (final c in clients) c: c,
              },
              onChanged: (c) => setState(() => _client = c),
            ),
          if (!planning && affichees == 0)
            const Vide('Aucun résultat pour ce client.'),
          if (planning) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              child: Text(
                'Vous pouvez modifier ce planning.',
                style: AppText.t(12.5, c: AppColors.muted),
              ),
            ),
            PlanningEquipe(
              nom: p.nom,
              semaine: _semaine,
              onSemaine: (d) => setState(() => _semaine += d),
            ),
          ] else if (_onglet == 1) ...[
            for (final v in visites)
              CarteVisiteLecture(
                client: v.client,
                detail: v.date,
                enCours: v.enCours,
              ),
          ] else ...[
            for (final c in commandes)
              CarteCommandeLecture(
                ht: c.ht,
                detail: '${c.id} · ${c.client} · ${c.date}',
                statut: c.statut,
              ),
          ],
          if (!planning)
            Pied(
              'Lecture seule.',
              centre: true,
              margeHaut: affichees == 0 ? 8 : 0,
            ),
        ],
      ),
    );
  }
}
