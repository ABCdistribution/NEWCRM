import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/planning_serveur.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/logique_planning.dart';
import 'state/planning_state.dart';
import 'widgets/ecarts_carte.dart';

/// Onglet « Mon planning » (tous les rôles). Maquette : `pageTournee` l.1010-1039 et `salesPlanning` l.1052.
///
/// Le promoteur voit son planning en lecture seule (composé par son encadrement). Le chef de secteur et le directeur
/// éditent le leur : jours, bandeau de phase (prévision, rapport en cours, validé), « Prévu vs réalisé », lignes du jour
/// et bouton « ＋ » qui ouvre le formulaire de RDV.
class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleActifProvider);
    final profil = ref.watch(profilActifProvider);
    final etat = ref.watch(crmProvider);
    final plan = ref.watch(planningProvider);
    final jour = ref.watch(jourPlanningProvider);
    final promoteur = role == Role.promoteur;
    // Connecté, le planning vient du CRM et se lit sans se modifier : rien ne repart vers le CRM depuis l'application.
    final reel = DemoTemps.reel;
    final lectureSeule = promoteur || reel;
    final u = context.univers;

    // Connecté : le planning du CRM sur quelques semaines, semaine par semaine. Démonstration : le promoteur lit le
    // planning que son encadrement a composé pour lui (semaine courante).
    final decalage = reel ? ref.watch(semainePlanningProvider) : 0;
    final lignesPlan = reel
        ? etat.planningFenetre
        : promoteur
        ? etat.planDe(profil.nom)
        : etat.etapes;
    final sem = reel || promoteur ? decalage : null;
    final lignes = lignesDuJour(lignesPlan, jour, sem: sem);
    final modifiee = previsionModifiee(plan.prevision, etat.etapes);
    final info = semaineInfo(decalage);
    final semaineCourante = decalage == 0;

    void changerSemaine(int delta) => reel
        ? ref.read(semainePlanningProvider.notifier).decaler(delta)
        : AppToast.show(
            context,
            'Navigation entre semaines : non détaillée dans la démo.',
          );

    final entete = AppEntete.libre(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mon planning',
                    style: AppText.t(21, w: FontWeight.w800, c: u.encre),
                  ),
                ),
                const SizedBox(width: 8),
                RondB(
                  '‹',
                  onTap: () => changerSemaine(-1),
                  semantique: 'Semaine précédente',
                ),
                const SizedBox(width: 8),
                RondB(
                  '›',
                  onTap: () => changerSemaine(1),
                  semantique: 'Semaine suivante',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              reel
                  ? 'Semaine ${info.num} · ${DemoTemps.libellePeriodeSemaine(DateTime(DemoTemps.lundi.year, DemoTemps.lundi.month, DemoTemps.lundi.day + 7 * decalage))}'
                  : 'Semaine ${DemoTemps.semaineCourante} · ${DemoTemps.semaineLibelle}',
              style: AppText.t(12.5, c: u.encre2),
            ),
          ),
          SelecteurJours(
            jours: [
              for (var i = 0; i < 5; i++)
                JourItem(
                  libelle: joursCourts[i],
                  numero: info.dates[i],
                  compte: '${lignesDuJour(lignesPlan, i, sem: sem).length} RDV',
                ),
            ],
            index: jour,
            onChanged: ref.read(jourPlanningProvider.notifier).choisir,
          ),
        ],
      ),
    );

    // Bandeau de phase (`icone`, `titre`, `detail` de pageTournee).
    final prevision = plan.prevision;
    final nbPrevision = prevision?.length ?? 0;
    final semaineRapport = reel ? rapportsServeur()?.semaine : null;
    // Connecté : dates et heures venues du CRM ; démonstration : celles de la maquette.
    final prevuAt = semaineRapport?.prevuAt;
    final jourPrevu = prevuAt == null
        ? DemoTemps.lundiLibelle
        : DemoTemps.libelleJour(prevuAt);
    final quandPrevu = semaineRapport?.prevuAt == null
        ? '${DemoTemps.lundiLibelle} à 09:10'
        : '${DemoTemps.libelleJour(semaineRapport!.prevuAt!)} à ${deuxChiffres(semaineRapport.prevuAt!.hour)}:${deuxChiffres(semaineRapport.prevuAt!.minute)}';
    String icone;
    String titre;
    String? detail;
    switch (plan.phase) {
      case PhasePlanning.valide:
        icone = '🔒';
        titre = reel
            ? piedValidation(
                semaineRapport?.valideAt,
                auto: semaineRapport?.valideAuto ?? true,
              )
            : 'Validé auto le ${DemoTemps.lundiSuivantLibelle} à 04:00';
        detail = "La semaine est verrouillée : plus rien n'est modifiable.";
      case PhasePlanning.prevision:
        titre = prevision == null
            ? (reel ? 'Prévision non enregistrée' : 'Prévision à saisir')
            : 'Prévision enregistrée le $quandPrevu (${nbLignes(nbPrevision)})';
        detail = reel
            ? null
            : prevision == null
            ? "Planifiez vos RDV de la semaine avec le « + », puis enregistrez votre prévision. Elle reste modifiable jusqu'au lundi soir, puis se fige."
            : modifiee
            ? "⚠ Des lignes ont changé depuis l'enregistrement : mettez la prévision à jour."
            : "Modifiable jusqu'au lundi soir, puis figée dès le mardi. Le rapport sera validé automatiquement en fin de semaine.";
        icone = prevision != null && !modifiee ? '✅' : '📝';
      case PhasePlanning.rapport:
        icone = '⏳';
        titre = 'Rapport en cours';
        detail = prevision != null
            ? 'Prévision figée le $jourPrevu (${nbLignes(nbPrevision)}).'
            : 'Prévision non renseignée cette semaine.';
    }
    // Le promoteur n'a pas de rapport ; les semaines voisines n'ont pas la phase de la semaine courante.
    if (promoteur || (reel && !semaineCourante)) {
      icone = '👁';
      titre = 'Planning de la semaine';
      detail = null;
    }

    final peutEnregistrer =
        !lectureSeule && plan.phase == PhasePlanning.prevision;
    final bandeau = BandeauInfo(
      titre: titre,
      icone: icone,
      detail: detail,
      child: peutEnregistrer
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AppBouton(
                prevision != null
                    ? 'Mettre à jour la prévision'
                    : 'Enregistrer la prévision',
                petit: true,
                variante: VarianteBouton.plein,
                onPressed: prevision != null && !modifiee
                    ? null
                    : () => _enregistrerPrevision(context, ref),
              ),
            )
          : null,
    );

    final montrerEcarts =
        !promoteur && semaineCourante && plan.phase != PhasePlanning.prevision;
    return PageUnivers(
      entete: entete,
      paddingBasFab: true,
      fab: !lectureSeule && !plan.verrouillee
          ? AppFab(
              rond: true,
              semantique: 'Ajouter un RDV',
              onPressed: () => AppRoutes.formulaireRdv(context),
            )
          : null,
      enfants: [
        bandeau,
        if (montrerEcarts)
          EcartsCarte(
            ecarts: ref.watch(ecartsSemaineProvider),
            ouvert: plan.ecartsOuverts,
            valide: plan.verrouillee,
            onBasculer: ref.read(planningProvider.notifier).basculerEcarts,
          ),
        if (lignes.isEmpty)
          Vide(
            lectureSeule || plan.verrouillee
                ? 'Aucune ligne ce jour.'
                : 'Aucune étape ce jour. Touchez le « + » pour ajouter une ligne.',
          )
        else
          for (final e in lignes)
            _CarteLigne(
              ligne: e,
              lectureSeule: lectureSeule,
              promoteur: promoteur,
              masquerFait: plan.phase == PhasePlanning.prevision,
              prospect: e.cible == CiblePlanning.prospect
                  ? etat.prospectParId(e.ref ?? '')
                  : null,
            ),
      ],
    );
  }

  /// `A.prevision` : la prévision ne peut pas être vide, et chaque soirée étape doit avoir son lieu et son adresse.
  void _enregistrerPrevision(BuildContext context, WidgetRef ref) {
    final etapes = ref.read(etapesProvider);
    if (etapes.isEmpty) {
      AppToast.show(context, 'La prévision ne peut pas être vide.');
      return;
    }
    for (final e in etapes) {
      if (e.soiree &&
          ((e.soireeLieu ?? '').isEmpty || (e.soireeAdr ?? '').isEmpty)) {
        AppToast.show(
          context,
          "Soirée étape : le lieu et l'adresse sont obligatoires.",
        );
        return;
      }
    }
    ref.read(planningProvider.notifier).enregistrerPrevision(etapes);
    AppToast.show(context, 'Prévision enregistrée.');
  }
}

/// Une ligne du jour : heure et carte colorée. Au toucher (chef de secteur, directeur) : la fiche du client ou du
/// prospect, sinon le formulaire de modification ; le crayon « ✎ » ouvre toujours le formulaire.
class _CarteLigne extends ConsumerWidget {
  const _CarteLigne({
    required this.ligne,
    required this.lectureSeule,
    required this.promoteur,
    required this.masquerFait,
    required this.prospect,
  });

  final EtapePlanning ligne;

  /// Aucune modification : promoteur, ou connecté au CRM (rien ne repart vers le CRM).
  final bool lectureSeule;

  /// Le promoteur ne consulte pas les fiches depuis son planning ; l'encadrement, oui.
  final bool promoteur;
  final bool masquerFait;
  final Prospect? prospect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ligne;
    final style = styleEtapePlanning(
      e,
      prospect: prospect,
      masquerFait: masquerFait,
    );
    final avecFiche =
        (e.cible == CiblePlanning.client ||
            e.cible == CiblePlanning.prospect) &&
        e.ref != null;
    return CarteEtapePlanning(
      heure: e.heure.isEmpty ? '—' : e.heure,
      titre: e.titre,
      libelle: style.libelle,
      fond: Color(style.fond),
      texte: Color(style.texte),
      detail: detailLigne(e, lectureSeule: promoteur),
      // Sans modification possible, seule une ligne qui vise un client ou un prospect s'ouvre (sa fiche).
      onTap: promoteur || (lectureSeule && !avecFiche)
          ? null
          : () => _ouvrir(context, avecFiche),
      onModifier: !lectureSeule && avecFiche
          ? () => AppRoutes.formulaireRdv(context, etapeId: e.id)
          : null,
    );
  }

  /// `ouvrirFiche` : un prospect s'ouvre sur l'onglet Prospects, un client sur l'onglet courant ; ADM et lignes libres
  /// ouvrent le formulaire.
  void _ouvrir(BuildContext context, bool avecFiche) {
    if (!avecFiche) {
      AppRoutes.formulaireRdv(context, etapeId: ligne.id);
    } else if (ligne.cible == CiblePlanning.prospect) {
      AppRoutes.ficheProspect(
        context,
        ligne.ref!,
        surOnglet: OngletApp.prospects,
      );
    } else {
      AppRoutes.ficheMagasin(context, ligne.ref!);
    }
  }
}
