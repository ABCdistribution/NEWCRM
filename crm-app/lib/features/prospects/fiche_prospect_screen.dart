import '../../core/auth/session.dart';
import '../../core/sync/detail_prospect_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/vue_prospects.dart';
import 'widgets/onglet_magasins_prospect.dart';

/// Fiche d'un prospect (écran empilé `prospect`). Maquette : fichePros l.1776-1792.
/// Ouverte par `AppRoutes.ficheProspect(context, prospectId)`.
///
/// Entête (retour, badge « Prospect · groupe », nom, raison sociale, actions Appeler / Mail / Itinéraire / Planifier /
/// Note), carte « Étape de prospection » avec ses segments, segment Timeline / Magasins (de l'enseigne), barre basse
/// « Changer d'étape » et « Passer en client » (absent quand le prospect est déjà référencé).
class FicheProspectScreen extends ConsumerStatefulWidget {
  const FicheProspectScreen({super.key, required this.prospectId});

  final String prospectId;

  @override
  ConsumerState<FicheProspectScreen> createState() =>
      _FicheProspectScreenState();
}

class _FicheProspectScreenState extends ConsumerState<FicheProspectScreen> {
  /// Onglet affiché : 0 = Timeline (à l'ouverture), 1 = Magasins (`S.proTab`).
  int _onglet = 0;

  static const List<String> _noms = [
    'Fiche créée',
    'À contacter',
    'RDV pris',
    'En négo',
    'Référencé',
  ];

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final id = widget.prospectId;
    final base = ref.watch(prospectParIdProvider(id));
    // Prospect du CRM : contact et historique chargés à l'ouverture (sans rien inventer en attendant).
    final detail = ref.watch(detailProspectProvider(id)).value;
    final p = base == null || detail == null
        ? base
        : base.copyWith(
            contact: detail.contact ?? base.contact,
            timeline: detail.timeline,
          );
    if (p == null) {
      return const PageUnivers(
        entete: TopbarEcran(titre: 'Prospect'),
        enfants: [Vide('Prospect introuvable.')],
      );
    }
    final prochaine = prochaineEtape(ref.watch(etapesProvider), id);

    // Actions externes : inactives (onTap nul) tant que le CRM ne fournit pas la donnée.
    final lanceur = ref.read(lanceurExterneProvider);
    VoidCallback? lancer(Uri? uri) =>
        uri == null ? null : () => lancerExterne(context, lanceur, uri);
    final uriCarte = uriItineraire(
      detail?.adresse ?? (p.cp.isEmpty ? null : p.cp),
    );

    return PageUnivers(
      entete: AppEntete.libre(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BoutonRetour(),
                BadgeInfo('Prospect · ${libelleGroupeProspect(p)}'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                p.nom,
                style: AppText.t(23, w: FontWeight.w800, c: u.encre, h: 1.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${p.raison} · classe ${p.classe} · ${p.cp}'
                '${p.cs != null && p.cs!.isNotEmpty ? ' · Resp. ${p.cs}' : ''}',
                style: AppText.t(12.5, c: u.encre2),
              ),
            ),
            RangeeActions(
              six: true,
              actions: [
                ActionRapide(
                  label: 'Appeler',
                  icone: AppIcons.tel,
                  onTap: lancer(uriAppel(detail?.telephone)),
                ),
                ActionRapide(
                  label: 'Mail',
                  icone: AppIcons.mail,
                  onTap: lancer(uriMail(detail?.mail)),
                ),
                ActionRapide(
                  label: 'Itinéraire',
                  icone: AppIcons.nav,
                  onTap: lancer(uriCarte),
                ),
                ActionRapide(
                  label: 'Planifier',
                  icone: AppIcons.cal,
                  onTap: () => AppRoutes.formulaireRdv(
                    context,
                    cible: CiblePlanning.prospect,
                    ref: id,
                    depuisFiche: true,
                    visite: false,
                  ),
                ),
                ActionRapide(
                  label: 'Note',
                  icone: AppIcons.note,
                  onTap: () => AppRoutes.noteProspect(context, id),
                ),
              ],
            ),
          ],
        ),
      ),
      enfants: [
        _CarteEtape(prospect: p, noms: _noms),
        const SizedBox(height: 16),
        Segment(
          libelles: const ['Timeline', 'Magasins'],
          index: _onglet,
          margeBas: 0,
          onChanged: (i) => setState(() => _onglet = i),
        ),
        if (_onglet == 1)
          OngletMagasinsProspect(prospect: p)
        else ...[
          TitreLigne(
            'Timeline de prospection',
            margeHaut: 20,
            droite: ref.watch(sessionProvider) != null
                ? null
                : Text(
                    'depuis le 2 oct.',
                    style: AppText.t(12.5, c: AppColors.muted),
                  ),
          ),
          Timeline(_evenements(p, prochaine)),
        ],
      ],
      bas: BarreBasse(
        enfants: [
          AppBouton(
            "Changer d'étape",
            variante: VarianteBouton.tonal,
            onPressed: () => AppRoutes.changerEtapeProspect(context, id),
          ),
          if (p.statut != StatutProspect.gagne)
            AppBouton(
              'Passer en client',
              variante: VarianteBouton.plein,
              onPressed: () => AppRoutes.passerEnClient(context, id),
            ),
        ],
      ),
    );
  }

  /// Événements de la timeline : le prochain RDV du planning en tête (il remplace « RDV de négociation prévu »), puis
  /// l'historique du prospect.
  List<TimelineItem> _evenements(Prospect p, EtapePlanning? prochaine) {
    TimelineItem item(
      IconeEvenement icone,
      int couleur,
      String titre,
      String date,
      String detail,
    ) => TimelineItem(
      icone: icone.emoji,
      fondIcone: Color(couleur).withValues(alpha: 0x22 / 255),
      couleurIcone: Color(couleur),
      titre: titre,
      date: date,
      detail: detail,
    );
    return [
      if (prochaine != null)
        item(
          IconeEvenement.cal,
          0xFF6545C5,
          'RDV prévu',
          '${joursCourts[prochaine.jour]} ${prochaine.heure}',
          prochaine.note.isNotEmpty
              ? prochaine.note
              : 'Visite planifiée dans mon planning',
        ),
      for (final e in p.timeline)
        if (!(prochaine != null && e.titre == 'RDV de négociation prévu'))
          item(e.icone, e.couleur, e.titre, e.date, e.detail),
    ];
  }
}

/// Carte « Étape de prospection » : probabilité, segments de la barre d'étapes, potentiel et contact.
class _CarteEtape extends StatelessWidget {
  const _CarteEtape({required this.prospect, required this.noms});

  final Prospect prospect;
  final List<String> noms;

  @override
  Widget build(BuildContext context) {
    final p = prospect;
    final muted = AppText.t(13, c: AppColors.muted);
    final gras = AppText.t(13, w: FontWeight.w700);
    return AppCarte(
      margeBas: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Étape de prospection',
                  style: AppText.t(16, w: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Probabilité ${p.proba} %',
                style: AppText.t(12.5, c: AppColors.muted),
              ),
            ],
          ),
          EtapesBarre(noms: noms, segments: p.statut.segments),
          Container(height: 1, color: AppColors.ligne),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Potentiel ', style: muted),
                  TextSpan(text: '${kf(p.pot)} k€/an', style: gras),
                  if (p.contact != null) ...[
                    const TextSpan(text: '   '),
                    TextSpan(text: 'Contact ', style: muted),
                    TextSpan(text: p.contact, style: gras),
                  ],
                ],
              ),
              style: AppText.t(13),
            ),
          ),
        ],
      ),
    );
  }
}
