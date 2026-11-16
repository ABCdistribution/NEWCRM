import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'compte_rendu_screen.dart';
import 'data/visites_data.dart';
import 'kilometrage_dialog.dart';
import 'logic/visites_logique.dart';
import 'state/actions_visite.dart';
import 'state/kilometrage.dart';
import 'widgets/badge_visite.dart';

/// Écran d'une visite (écran empilé `visite`) : étapes DPH et visite PEM si c'est un brouillon, compte rendu
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
    return _EtapesVisite(visite: visite);
  }
}

/// Visite en cours : progression, étapes DPH, visite PEM, commande liée, « Commander » et « Terminer la visite ».
class _EtapesVisite extends ConsumerWidget {
  const _EtapesVisite({required this.visite});

  final Visite visite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const etapes = EtapeDph.values;
    final faites = etapes.where(visite.etapeFaite).length;
    final courante = etapes.indexWhere((e) => !visite.etapeFaite(e));
    final nom = ref.watch(magasinParIdProvider(visite.magasinId))?.nom ?? '';
    final actions = ActionsVisite(ref.read(crmProvider.notifier), visite.id);
    final pem = visite.pem;

    void ouvrirEtape(EtapeDph e) {
      if (e.estPhoto) {
        AppRoutes.photosEtapeVisite(context, visiteId: visite.id, etape: e);
      } else {
        AppRoutes.saisieEtapeVisite(context, visiteId: visite.id, etape: e);
      }
    }

    return PageUnivers(
      entete: _EnteteVisite(
        visite: visite,
        nomClient: nom,
        faites: faites,
        total: etapes.length,
      ),
      enfants: [
        AppCarte(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (var i = 0; i < etapes.length; i++)
                _LigneEtape(
                  etape: etapes[i],
                  numero: i + 1,
                  premiere: i == 0,
                  fait: visite.etapeFaite(etapes[i]),
                  courante: i == courante,
                  detail: _detail(visite, etapes[i], i == courante),
                  onTap: etapes[i] == EtapeDph.debut
                      ? null
                      : () => ouvrirEtape(etapes[i]),
                ),
            ],
          ),
        ),
        const TitreLigne('Visite PEM', taille: 16, margeHaut: 18),
        AppCarte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Segment(
                libelles: const ['Réalisée', 'Pas de visite PEM'],
                index: pem.realisee == true
                    ? 0
                    : pem.realisee == false
                    ? 1
                    : -1,
                margeBas: pem.realisee == false ? 10 : 0,
                onChanged: (i) => actions.definirPemRealisee(realisee: i == 0),
              ),
              if (pem.realisee == false) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Pas de visite PEM car :',
                    style: AppText.t(12.5, c: AppColors.muted),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in raisonsPem)
                      _ChipRaison(
                        r,
                        selectionne: pem.raison == r,
                        onTap: () => actions.definirRaisonPem(r),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const TitreLigne(
          'Commande liée à la visite DPH',
          taille: 16,
          margeHaut: 18,
        ),
        AppCarte(
          child: visite.cmd == null
              ? Text(
                  'Aucune commande liée à cette visite.',
                  style: AppText.t(16, c: AppColors.muted),
                )
              : Text(
                  'Commande #${visite.cmd!.id} : ${visite.cmd!.ht} - ${visite.cmd!.liv}',
                  style: AppText.gras,
                ),
        ),
      ],
      bas: BarreBasse.libre(
        blanc: true,
        child: Row(
          children: [
            AppBouton(
              '🛒 Commander',
              variante: VarianteBouton.clair,
              pleineLargeur: false,
              onPressed: () => AppRoutes.priseCommande(
                context,
                magasinId: visite.magasinId,
                visiteId: visite.id,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppBouton(
                '✓ Terminer la visite',
                variante: VarianteBouton.plein,
                onPressed: () => AppRoutes.validerVisite(context, visite.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ligne grise sous le titre d'une étape : horodatage et résumé si elle est faite, « À faire maintenant » si c'est la
  /// prochaine, rien sinon.
  String _detail(Visite v, EtapeDph e, bool courante) {
    if (!v.etapeFaite(e)) return courante ? 'À faire maintenant' : '';
    final b = StringBuffer(v.chrono[e] ?? '');
    if (e == EtapeDph.dn && v.kits.isNotEmpty) {
      b.write(' · ${v.kits.length} kit${sPluriel(v.kits.length)}');
    }
    if (e == EtapeDph.concurrence) {
      final n = v.concurrence.liste.length;
      b.write(
        v.concurrence.aucune
            ? ' · aucune marque'
            : ' · $n marque${sPluriel(n)}',
      );
    }
    if (e.estPhoto) {
      final n = v.photos[e] ?? 0;
      b.write(' · $n photo${sPluriel(n)}');
    }
    return b.toString();
  }
}

/// En-tête de la visite en cours : retour, client, numéro et début, état, progression des étapes DPH.
/// Blanc avec un filet dans l'univers de l'encadrement, transparent dans celui du promoteur (`.v-tete`).
class _EnteteVisite extends StatelessWidget {
  const _EnteteVisite({
    required this.visite,
    required this.nomClient,
    required this.faites,
    required this.total,
  });

  final Visite visite;
  final String nomClient;
  final int faites;
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
                        'Visite #${visite.num} · début DPH ${visite.chrono[EtapeDph.debut]}',
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
                Text('Visite DPH', style: AppText.t(12, w: FontWeight.w700)),
                Text(
                  '$faites / $total étapes',
                  style: AppText.t(12, c: AppColors.muted),
                ),
              ],
            ),
          ),
          BarreProgression(
            valeur: faites / total,
            couleur: u.bleu,
            fond: AppColors.barreFond,
            margeHaut: 0,
          ),
        ],
      ),
    );
  }
}

/// Une étape de la liste : rond numéroté, titre, détail, et à droite « Saisir », « Modifier » ou « ＋ Photo ».
class _LigneEtape extends StatelessWidget {
  const _LigneEtape({
    required this.etape,
    required this.numero,
    required this.premiere,
    required this.fait,
    required this.courante,
    required this.detail,
    required this.onTap,
  });

  final EtapeDph etape;
  final int numero;
  final bool premiere;
  final bool fait;
  final bool courante;
  final String detail;

  /// Nul pour le début de visite, qui n'a pas de saisie.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    final action = etape.estPhoto
        ? '＋ Photo'
        : fait
        ? 'Modifier'
        : 'Saisir';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: premiere
              ? null
              : const Border(top: BorderSide(color: AppColors.ligne)),
        ),
        child: AppLigne(
          alignement: CrossAxisAlignment.center,
          children: [
            NumeroEtape(
              numero,
              etat: fait
                  ? EtatNumero.faite
                  : courante
                  ? EtatNumero.courante
                  : EtatNumero.aFaire,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etape.libelle,
                    style: AppText.t(14.5, w: FontWeight.w700),
                  ),
                  if (detail.isNotEmpty)
                    Text(detail, style: AppText.t(12, c: AppColors.muted)),
                ],
              ),
            ),
            if (onTap != null)
              Text(
                action,
                style: AppText.t(13, w: FontWeight.w700, c: bleu),
              ),
          ],
        ),
      ),
    );
  }
}

/// Raison de l'absence de visite PEM : puce blanche, ou pleine couleur quand elle est choisie.
class _ChipRaison extends StatelessWidget {
  const _ChipRaison(
    this.label, {
    required this.selectionne,
    required this.onTap,
  });

  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne ? bleu : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selectionne ? bleu : AppColors.bordureChamp,
          ),
        ),
        child: Text(
          label,
          style: AppText.t(
            13.5,
            c: selectionne ? Colors.white : AppColors.texte,
          ),
        ),
      ),
    );
  }
}
