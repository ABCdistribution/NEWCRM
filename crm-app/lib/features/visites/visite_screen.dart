import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/sync/referentiels_visite_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'compte_rendu_screen.dart';
import 'parcours_etapes.dart';
import 'kilometrage_dialog.dart';
import 'logic/visites_logique.dart';
import 'state/actions_visite.dart';
import 'state/kilometrage.dart';
import 'widgets/badge_visite.dart';

/// Écran d'une visite (écran empilé `visite`) : parcours « Précédent / Suivant » si c'est un brouillon, compte rendu
/// sinon. Maquette : visiteEtapes l.1261-1280 (brouillon) et compteRendu l.1313-1333.
/// Ouvert par `AppRoutes.visite(context, visiteId)` ou `AppRoutes.demarrerVisite(context, magasinId)`.
class VisiteScreen extends ConsumerStatefulWidget {
  const VisiteScreen({super.key, required this.visiteId});

  final String visiteId;

  @override
  ConsumerState<VisiteScreen> createState() => _VisiteScreenState();
}

class _VisiteScreenState extends ConsumerState<VisiteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _proposerDepart());
  }

  /// Au démarrage d'une visite, le promoteur se voit proposer une fois le relevé de départ (`startVisite`).
  void _proposerDepart() {
    if (!mounted) return;
    final visite = ref.read(crmProvider).visiteParId(widget.visiteId);
    final km = ref.read(kilometrageProvider);
    if (ref.read(roleActifProvider) != Role.promoteur ||
        visite == null ||
        visite.etat != EtatVisite.brouillon ||
        km.departPropose) {
      return;
    }
    ref
        .read(kilometrageProvider.notifier)
        .maj((k) => k.copyWith(departPropose: true));
    ouvrirKilometrage(context, PhaseKilometrage.depart);
  }

  @override
  Widget build(BuildContext context) {
    final visite = ref.watch(visiteParIdProvider(widget.visiteId));
    if (visite == null) {
      return const PageUnivers(
        entete: TopbarEcran(titre: 'Visite'),
        enfants: [Vide('Visite introuvable.')],
      );
    }
    if (visite.etat != EtatVisite.brouillon) {
      return CompteRenduScreen(visiteId: widget.visiteId);
    }
    return _ParcoursVisite(visite: visite);
  }
}

/// Visite en cours : une étape à la fois, « Précédent » / « Suivant » en bas ; « Terminer la visite » remplace
/// « Suivant » à la dernière étape.
class _ParcoursVisite extends ConsumerStatefulWidget {
  const _ParcoursVisite({required this.visite});

  final Visite visite;

  @override
  ConsumerState<_ParcoursVisite> createState() => _ParcoursVisiteState();
}

class _ParcoursVisiteState extends ConsumerState<_ParcoursVisite> {
  static final List<EtapeDph> _etapes = EtapeDph.parcours;

  /// Étape affichée : la première non encore validée à l'ouverture.
  late int _index = () {
    final i = _etapes.indexWhere((e) => !widget.visite.etapeFaite(e));
    return i < 0 ? _etapes.length - 1 : i;
  }();

  ActionsVisite get _actions =>
      ActionsVisite(ref.read(crmProvider.notifier), widget.visite.id);

  void _suivant() {
    final e = _etapes[_index];
    final visite = ref.read(visiteParIdProvider(widget.visite.id)) ?? widget.visite;
    final erreur = erreurEtape(
      visite,
      e,
      questions: ref.read(questionnaireProvider).value ?? const [],
      raisonsDisponibles:
          (ref.read(raisonsAbsenceProvider).value ?? const []).isNotEmpty,
    );
    if (erreur != null) {
      AppToast.show(context, erreur);
      return;
    }
    _actions.enregistrerEtape(e);
    if (_index == _etapes.length - 1) {
      AppRoutes.validerVisite(context, widget.visite.id);
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le parcours reste à jour quand le CRM livre le questionnaire, les raisons ou les promotions.
    ref.watch(questionnaireProvider);
    ref.watch(raisonsAbsenceProvider);
    ref.watch(promosOpProvider);
    final visite = ref.watch(visiteParIdProvider(widget.visite.id)) ?? widget.visite;
    final etape = _etapes[_index];
    final derniere = _index == _etapes.length - 1;
    final nom = ref.watch(magasinParIdProvider(visite.magasinId))?.nom ?? '';
    return PageUnivers(
      entete: _EnteteVisite(
        visite: visite,
        nomClient: nom,
        etape: _index + 1,
        total: _etapes.length,
      ),
      enfants: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            etape.libelle,
            style: AppText.t(18, w: FontWeight.w800, h: 1.25),
          ),
        ),
        CorpsEtape(key: ValueKey(etape), visite: visite, etape: etape),
      ],
      bas: BarreBasse.libre(
        blanc: true,
        child: Row(
          children: [
            if (_index > 0) ...[
              AppBouton(
                '‹ Précédent',
                variante: VarianteBouton.clair,
                pleineLargeur: false,
                onPressed: () => setState(() => _index--),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: AppBouton(
                derniere ? '✓ Terminer la visite' : 'Suivant ›',
                variante: VarianteBouton.plein,
                onPressed: _suivant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// En-tête de la visite en cours : retour, client, numéro et début, état, progression des étapes.
/// Blanc avec un filet dans l'univers de l'encadrement, transparent dans celui du promoteur (`.v-tete`).
class _EnteteVisite extends StatelessWidget {
  const _EnteteVisite({
    required this.visite,
    required this.nomClient,
    required this.etape,
    required this.total,
  });

  final Visite visite;
  final String nomClient;

  /// Rang de l'étape affichée (à partir de 1).
  final int etape;
  final int total;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final pilot = u.univers == Univers.pilot;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pilot
          ? const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.ligne)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLigne(
            children: [
              const BoutonRetour(taille: 44),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomClient,
                      style: AppText.t(17, w: FontWeight.w800, h: 1.2),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${visite.num > 0 ? 'Visite #${visite.num} · ' : ''}début ${visite.chrono[EtapeDph.debut]}',
                        style: AppText.t(12, c: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              BadgeVisite(visite.etat),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Visite', style: AppText.t(12, w: FontWeight.w700)),
                Text(
                  'Étape $etape / $total',
                  style: AppText.t(12, c: AppColors.muted),
                ),
              ],
            ),
          ),
          BarreProgression(
            valeur: etape / total,
            couleur: u.bleu,
            fond: AppColors.barreFond,
            margeHaut: 0,
          ),
        ],
      ),
    );
  }
}
