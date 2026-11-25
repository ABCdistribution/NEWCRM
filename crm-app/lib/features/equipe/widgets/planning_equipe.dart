/// Planning d'un promoteur ou d'un chef de secteur ouvert par son encadrement : maquette `pageTournee('mgr')` (modifiable,
/// page d'un promoteur) et `pageTournee('lect')` (lecture seule, page d'un chef de secteur), l.1031-1034.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/nav/nav.dart';
import '../../../core/state/state.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

/// Semaine, jours et lignes du planning de `nom`.
///
/// Le planning vient du store (`planDe`) : les lignes ajoutées ou modifiées par la feuille de saisie du lot planning
/// (`AppRoutes.formulaireRdv` avec `planCible`) s'y affichent aussitôt. `semaine` est le décalage par rapport à la
/// semaine 45 (`S.promoSem`), `onSemaine` reçoit -1 ou +1. Le jour sélectionné est celui du planning, commun à
/// toute l'application (`S.jour`).
///
/// `lecture` : pas de modification (ni crayon, ni « ＋ Ajouter une ligne »). `apres` s'affiche sous les lignes
/// (carte du rapport d'activité du chef de secteur).
class PlanningEquipe extends ConsumerWidget {
  const PlanningEquipe({
    super.key,
    required this.nom,
    required this.semaine,
    required this.onSemaine,
    this.lecture = false,
    this.apres,
  });

  final String nom;
  final int semaine;
  final ValueChanged<int> onSemaine;
  final bool lecture;
  final Widget? apres;

  @override
  Widget build(BuildContext context, WidgetRef ref) => VuePlanningEquipe(
    plan: ref.watch(crmProvider.select((e) => e.planDe(nom))),
    nom: nom,
    semaine: semaine,
    onSemaine: onSemaine,
    lecture: lecture,
    apres: apres,
  );
}

/// Semaine, jours et lignes d'un planning déjà lu (store ou CRM) : navigation entre semaines, sélecteur de jours,
/// cartes des lignes. `plan` contient les lignes de toutes les semaines affichables (`EtapePlanning.sem`).
///
/// `nom` désigne la personne dont on modifie le planning ; il n'est utile que sans `lecture`.
class VuePlanningEquipe extends ConsumerWidget {
  const VuePlanningEquipe({
    super.key,
    required this.plan,
    required this.semaine,
    required this.onSemaine,
    this.nom = '',
    this.lecture = false,
    this.apres,
    this.message,
  });

  final List<EtapePlanning> plan;
  final String nom;
  final int semaine;
  final ValueChanged<int> onSemaine;
  final bool lecture;
  final Widget? apres;

  /// Texte à la place de « Aucune ligne ce jour. » quand le planning n'est pas encore lu (chargement, indisponible).
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = ref.watch(crmProvider);
    final jour = ref.watch(jourPlanningProvider);
    final info = semaineInfo(semaine);
    final lignes = lignesDuJour(plan, jour, sem: semaine);

    void modifier(EtapePlanning e) => AppRoutes.formulaireRdv(
      context,
      etapeId: e.id,
      planCible: nom,
      semaine: semaine,
    );

    Widget carte(EtapePlanning e) {
      final prospect = e.cible == CiblePlanning.prospect
          ? crm.prospectParId(e.ref ?? '')
          : null;
      final style = styleEtapePlanning(e, prospect: prospect);
      final detail = [
        if (e.acc) 'Accompagnement',
        if (e.rdv) 'RDV',
        if (e.appel) 'Appel téléphonique',
        if (e.remp) 'Visite de remplacement',
        if (e.soiree) 'Soirée étape (${e.soireeLieu ?? ''})',
        if (e.note.isNotEmpty) e.note,
      ].join(' · ');
      final modifiable =
          e.cible == CiblePlanning.client || e.cible == CiblePlanning.prospect;
      return CarteEtapePlanning(
        heure: e.heure.isEmpty ? '—' : e.heure,
        titre: e.titre,
        libelle: style.libelle,
        fond: Color(style.fond),
        texte: Color(style.texte),
        detail: detail,
        classe: crm.classeEtape(e),
        onTap: lecture ? null : () => modifier(e),
        onModifier: !lecture && modifiable ? () => modifier(e) : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              RondB(
                '‹',
                semantique: 'Semaine précédente',
                onTap: () => onSemaine(-1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Semaine ${info.num}',
                      style: AppText.t(13, w: FontWeight.w700),
                    ),
                    Text(
                      info.libelle,
                      style: AppText.t(12, c: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              RondB(
                '›',
                semantique: 'Semaine suivante',
                onTap: () => onSemaine(1),
              ),
            ],
          ),
        ),
        SelecteurJours(
          margeHaut: 0,
          index: jour,
          onChanged: (i) => ref.read(jourPlanningProvider.notifier).choisir(i),
          jours: [
            for (var i = 0; i < 5; i++)
              JourItem(
                libelle: joursCourts[i],
                numero: info.dates[i],
                compte: '${lignesDuJour(plan, i, sem: semaine).length} RDV',
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (lignes.isEmpty)
          Vide(message ?? 'Aucune ligne ce jour.')
        else
          for (final e in lignes) carte(e),
        if (!lecture) ...[
          const SizedBox(height: 10),
          AppBouton(
            '＋ Ajouter une ligne',
            variante: VarianteBouton.plein,
            onPressed: () => AppRoutes.formulaireRdv(
              context,
              planCible: nom,
              semaine: semaine,
            ),
          ),
        ],
        if (apres != null) ...[
          // Les marges verticales se confondent dans la maquette : 14 px entre la dernière ligne et le bloc suivant.
          SizedBox(height: lignes.isEmpty ? 14 : 2),
          apres!,
        ],
      ],
    );
  }
}
