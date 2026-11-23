import '../../core/data/equipe_serveur.dart';
import 'resume_activite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/data/planning_serveur.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/sync/planning_equipe_provider.dart';
import '../../core/ui/ui.dart';
import 'data/equipe_demo.dart';
import 'data/semaine_reelle.dart';
import '../planning/state/planning_state.dart';
import 'state/equipe_state.dart';
import 'widgets/lignes_equipe.dart';
import 'widgets/planning_equipe.dart';
import 'widgets/planning_equipe_reel.dart';

/// Page d'un chef de secteur vue par son directeur (écran empilé `equipe-cs`). Maquette : pageCS l.851-877.
/// Ouverte par `AppRoutes.pageChefSecteur(context, csId)` ; `csId` doit être « n », « k » ou « s ».
///
/// Actions « Appeler » et « Envoyer un mail », puis quatre onglets en lecture seule : « Planning » (planning du chef de
/// secteur, semaine par semaine, avec la carte de son rapport d'activité), « Visites », « Commandes » et « Promoteurs ».
class ChefSecteurScreen extends ConsumerStatefulWidget {
  const ChefSecteurScreen({super.key, required this.csId});

  /// « n », « k » ou « s ».
  final String csId;

  @override
  ConsumerState<ChefSecteurScreen> createState() => _ChefSecteurScreenState();
}

class _ChefSecteurScreenState extends ConsumerState<ChefSecteurScreen> {
  /// 0 Planning (à l'ouverture), 1 Visites, 2 Commandes, 3 Promoteurs (`csTab`).
  int _onglet = 0;

  /// Décalage de la semaine du planning par rapport à la semaine 45 (`promoSem`).
  int _semaine = 0;

  @override
  void initState() {
    super.initState();
    // Ouvrir la page d'un chef de secteur remet son filtre de semaines à « Toutes » (action `equipe-cs`).
    Future.microtask(() {
      if (mounted) {
        ref
            .read(filtreSemainesProvider.notifier)
            .choisir(FiltreSemaines.toutes);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = chefActuelParId(widget.csId);
    if (cs == null) {
      return const PageUnivers(
        entete: TopbarEcran(titre: 'Chef de secteur'),
        enfants: [Vide('Chef de secteur introuvable.')],
      );
    }
    final promoteurs = promoteursDuChef(cs.id);
    if (cs.reel) {
      return ResumeActivite(
        titre: cs.nom,
        sous: 'Chef de secteur · Secteur ${cs.secteur}',
        visites: cs.visites,
        commandes: cs.commandes,
        ca: cs.ca,
        objectif: cs.objectif,
        enfants: [
          const TitreLigne('Planning', taille: 16),
          PlanningEquipeReel(
            userId: cs.id,
            promoteur: false,
            semaine: _semaine,
            onSemaine: (d) => setState(
              () => _semaine = (_semaine + d).clamp(
                -SemainePlanningNotifier.avant,
                SemainePlanningNotifier.apres,
              ),
            ),
            apres: _rapportReel(cs),
          ),
          TitreCompte(
            "Résumé de l'équipe",
            '${promoteurs.length} promoteurs',
            margeHaut: 16,
          ),
          for (final p in promoteurs)
            LignePromoteur(
              promoteur: p,
              onTap: () =>
                  AppRoutes.pagePromoteur(context, csId: cs.id, nom: p.nom),
            ),
        ],
      );
    }
    final activite = activitePromoteur(
      nom: cs.nom,
      clientsPerso: clientsParChefSecteur[cs.nom],
    );
    return PageUnivers(
      entete: TopbarEcran(
        titre: cs.nom,
        sous: 'Chef de secteur · Secteur ${cs.secteur}',
      ),
      paddingCorps: false,
      corps: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: RangeeActions(
              actions: [
                ActionRapide(
                  label: 'Appeler',
                  icone: AppIcons.tel,
                  onTap: () =>
                      AppToast.show(context, 'Appel de ${cs.nom} en cours.'),
                ),
                ActionRapide(
                  label: 'Envoyer un mail',
                  icone: AppIcons.mail,
                  onTap: () => AppToast.show(
                    context,
                    'Ouverture de la messagerie : nouveau mail à ${cs.nom}.',
                  ),
                ),
              ],
            ),
          ),
          CorpsSousTopbar(
            children: [
              Segment(
                libelles: const [
                  'Planning',
                  'Visites',
                  'Commandes',
                  'Promoteurs',
                ],
                index: _onglet,
                onChanged: (i) => setState(() => _onglet = i),
              ),
              ...switch (_onglet) {
                0 => [_planning(cs)],
                1 => [
                  TitreCompte(
                    'Visites de ${cs.nom}',
                    '${activite.visites.length}',
                  ),
                  for (final v in activite.visites)
                    CarteVisiteLecture(
                      client: v.client,
                      detail: v.date,
                      enCours: v.enCours,
                    ),
                ],
                2 => [
                  TitreCompte(
                    'Commandes de ${cs.nom}',
                    '${activite.commandes.length}',
                  ),
                  for (final c in activite.commandes)
                    CarteCommandeLecture(
                      ht: c.ht,
                      detail: '${c.id} · ${c.client} · ${c.date}',
                      statut: c.statut,
                    ),
                ],
                _ => [
                  TitreCompte(
                    "Résumé de l'équipe",
                    '${promoteurs.length} promoteurs · ${cs.secteur}',
                  ),
                  for (final p in promoteurs)
                    LignePromoteur(
                      promoteur: p,
                      avecJour: true,
                      onTap: () => AppRoutes.pagePromoteur(
                        context,
                        csId: cs.id,
                        nom: p.nom,
                      ),
                    ),
                  const Pied(
                    'Touchez un promoteur pour voir sa tournée du jour (lecture seule).',
                    centre: true,
                    margeHaut: 0,
                  ),
                ],
              },
            ],
          ),
        ],
      ),
    );
  }

  /// Carte du rapport d'activité de la semaine affichée pour un chef de secteur du CRM (`GET /rapports/:userId`,
  /// réservé à la direction, aux directeurs régionaux et aux administrateurs) ; nulle sans rapport à montrer.
  Widget? _rapportReel(ChefSecteur cs) {
    final base = DemoTemps.lundi;
    final lundi = DateTime(base.year, base.month, base.day + 7 * _semaine);
    final rapport = ref
        .watch(rapportEquipeProvider((userId: cs.id, lundi: isoJour(lundi))))
        .value;
    if (rapport == null || rapportVide(rapport)) return null;
    final semaine = semaineCsDepuisRapport(rapport);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TitreLigne("Rapport d'activité", taille: 16),
        CarteSemaine(
          semaine: semaine,
          onTap: () => AppRoutes.semaineChefSecteur(
            context,
            csId: cs.id,
            numSemaine: semaine.n,
          ),
        ),
      ],
    );
  }

  /// Planning du chef de secteur en lecture seule, suivi de la carte du rapport d'activité de la semaine affichée
  /// (aucune carte quand la semaine n'a pas de rapport : après la semaine 45 ou avant la 39).
  Widget _planning(ChefSecteur cs) {
    final numSemaine = semaineInfo(_semaine).num;
    final rapport = semainesChefSecteur(
      cs.id,
    ).where((w) => w.n == numSemaine).firstOrNull;
    return PlanningEquipe(
      nom: cs.nom,
      semaine: _semaine,
      lecture: true,
      onSemaine: (d) => setState(() => _semaine += d),
      apres: rapport == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TitreLigne("Rapport d'activité", taille: 16),
                CarteSemaine(
                  semaine: rapport,
                  onTap: () => AppRoutes.semaineChefSecteur(
                    context,
                    csId: cs.id,
                    numSemaine: rapport.n,
                  ),
                ),
              ],
            ),
    );
  }
}
