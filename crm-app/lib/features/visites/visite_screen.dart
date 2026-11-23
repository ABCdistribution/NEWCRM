import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/referentiels_visite.dart';
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
import 'state/briefing_magasin.dart';
import 'state/kilometrage.dart';
import 'widgets/badge_visite.dart';
import 'widgets/briefing_visite.dart';

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
  /// Produits indispensables du magasin ; l'étape n'est proposée que si la liste n'est pas vide (visite commerciale).
  List<ProduitIndispensable> get _indispensables => widget.visite.estPem
      ? const []
      : ref
                .read(produitsIndispensablesProvider(widget.visite.magasinId))
                .value ??
            const [];

  /// Articles PEM à vérifier (visite PEM) ; l'étape n'est proposée que si la liste est connue et non vide.
  List<ArticlePem> get _articlesPem =>
      ref.read(articlesPemProvider).value ?? const [];

  List<EtapeDph> get _etapes => widget.visite.estPem
      ? EtapeDph.parcoursPemPour(articles: _articlesPem.isNotEmpty)
      : EtapeDph.parcoursPour(indispensables: _indispensables.isNotEmpty);

  /// Étape affichée : la première non encore validée à l'ouverture. Elle est retenue par sa nature, non par son rang,
  /// pour que l'arrivée tardive de la liste des indispensables ne change pas d'étape.
  late EtapeDph _etape = () {
    final etapes = _etapes;
    return etapes.firstWhere(
      (e) => !widget.visite.etapeFaite(e),
      orElse: () => etapes.last,
    );
  }();

  /// Briefing du magasin : déplié sur la première étape, replié dès qu'on avance.
  late bool _briefingOuvert = _etape == EtapeDph.arrivee;

  int get _index => max(0, _etapes.indexOf(_etape));

  ActionsVisite get _actions =>
      ActionsVisite(ref.read(crmProvider.notifier), widget.visite.id);

  void _suivant() {
    final etapes = _etapes;
    final e = etapes[_index];
    final visite =
        ref.read(visiteParIdProvider(widget.visite.id)) ?? widget.visite;
    final erreur = erreurEtape(
      visite,
      e,
      questions: ref.read(questionnaireProvider).value ?? const [],
      raisonsDisponibles:
          (ref.read(raisonsAbsenceProvider).value ?? const []).isNotEmpty,
      indispensables: _indispensables,
      articlesPem: _articlesPem,
    );
    if (erreur != null) {
      AppToast.show(context, erreur);
      return;
    }
    _actions.enregistrerEtape(e);
    if (_index == etapes.length - 1) {
      AppRoutes.validerVisite(context, widget.visite.id);
    } else {
      setState(() {
        _etape = etapes[_index + 1];
        _briefingOuvert = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Le parcours reste à jour quand le CRM livre le questionnaire, les raisons ou les promotions.
    ref.watch(questionnaireProvider);
    ref.watch(raisonsAbsenceProvider);
    if (widget.visite.estPem) {
      ref.watch(articlesPemProvider);
    } else {
      ref.watch(produitsIndispensablesProvider(widget.visite.magasinId));
    }
    final etapes = _etapes;
    final visite =
        ref.watch(visiteParIdProvider(widget.visite.id)) ?? widget.visite;
    final etape = etapes[_index];
    final derniere = _index == etapes.length - 1;
    final nom = ref.watch(magasinParIdProvider(visite.magasinId))?.nom ?? '';
    final avecBriefing = !ref
        .watch(briefingMagasinProvider(visite.magasinId))
        .vide;
    return PageUnivers(
      entete: _EnteteVisite(
        visite: visite,
        nomClient: nom,
        etape: _index + 1,
        total: etapes.length,
        onBriefing: avecBriefing
            ? () => ouvrirBriefing(context, visite.magasinId)
            : null,
      ),
      enfants: [
        BlocBriefing(
          magasinId: visite.magasinId,
          ouvert: _briefingOuvert,
          onBasculer: () => setState(() => _briefingOuvert = !_briefingOuvert),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            etape.libellePour(visite.typeVisite),
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
                onPressed: () => setState(() => _etape = etapes[_index - 1]),
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
    this.onBriefing,
  });

  final Visite visite;
  final String nomClient;

  /// Ouvre la feuille du briefing ; nul quand le magasin n'a rien à montrer.
  final VoidCallback? onBriefing;

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
              if (onBriefing != null) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBriefing,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Pastille(
                      'Briefing',
                      variante: VariantePastille.bleu,
                    ),
                  ),
                ),
              ],
              if (visite.estPem) ...[
                const BadgePem(),
                const SizedBox(width: 2),
              ],
              BadgeVisite(visite.etat),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  visite.estPem ? 'Visite PEM' : 'Visite',
                  style: AppText.t(12, w: FontWeight.w700),
                ),
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
