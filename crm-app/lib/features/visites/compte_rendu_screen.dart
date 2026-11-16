import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/visites_data.dart';
import 'logic/visites_logique.dart';
import 'widgets/badge_visite.dart';

/// Compte rendu d'une visite terminée ou d'un autre promoteur (écran empilé `cr`), en lecture seule.
/// Maquette : compteRendu l.1313-1333. Ouvert par `AppRoutes.compteRendu(context, visiteId)`.
///
/// Rubriques : Le client, La visite, Commande liée, Visite PEM, Distribution numérique par kit, Concurrence,
/// Timing de visite.
class CompteRenduScreen extends ConsumerWidget {
  const CompteRenduScreen({super.key, required this.visiteId});

  final String visiteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(visiteParIdProvider(visiteId));
    if (v == null) {
      return const PageUnivers(
        entete: TopbarEcran(titre: 'Visite'),
        enfants: [Vide('Visite introuvable.')],
      );
    }
    final bleu = context.univers.bleu;
    final moi = ref.watch(profilActifProvider).nom;
    final m = ref.watch(magasinParIdProvider(v.magasinId));
    final cpVille = m?.adresse.split(', ').last.toUpperCase() ?? '';
    final conc = v.concurrence;
    return PageUnivers(
      entete: TopbarEcran(
        titre: 'Visite #${v.num}',
        sous: 'réalisée par ${v.par}',
        tailleTitre: 16,
        droite: BadgeVisite(v.etat),
      ),
      enfants: [
        SectionTitre('Compte rendu de la visite', couleur: bleu, margeHaut: 0),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Pastille('Visite DPH', variante: VariantePastille.vert),
              Pastille(
                'Visite PEM${v.pem.realisee == true ? '' : ' · non réalisée'}',
                variante: v.pem.realisee == true
                    ? VariantePastille.vert
                    : VariantePastille.gris,
              ),
            ],
          ),
        ),
        SectionTitre('Le client', couleur: bleu),
        LigneCle(
          'Enseigne',
          m == null ? '' : m.nom.replaceFirst(' – ', ' ').toUpperCase(),
        ),
        LigneCle(
          'Fiche client',
          '',
          valeurWidget: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: m == null
                ? null
                : () => AppRoutes.ficheMagasin(context, m.id),
            child: Text(
              'Cliquez ici',
              textAlign: TextAlign.right,
              style: AppText.t(
                14,
                w: FontWeight.w700,
                c: bleu,
                deco: TextDecoration.underline,
              ),
            ),
          ),
        ),
        LigneCle('Adresse', '$cpVille (FR)'),
        SectionTitre('La visite', couleur: bleu),
        LigneCle('Réception visite', v.recu ?? '—'),
        LigneCle('Réalisée par', v.par),
        SectionTitre('Commande liée à la visite DPH', couleur: bleu),
        if (v.cmd != null)
          LigneCle('Commande', '#${v.cmd!.id} : ${v.cmd!.ht} - ${v.cmd!.liv}')
        else
          const LigneCle('Aucune commande liée', ''),
        if (v.pem.realisee != true) ...[
          SectionTitre('Visite PEM', couleur: bleu),
          LigneCle('Pas de visite PEM car', v.pem.raison),
        ],
        if (v.kits.isNotEmpty) ...[
          SectionTitre('Distribution numérique par kit', couleur: bleu),
          for (final code in v.kits)
            _LigneKit(
              nom: kitDe(code).nom,
              onTap: () => AppRoutes.detailKit(context, code),
            ),
        ],
        SectionTitre('Concurrence', couleur: bleu),
        if (conc.aucune || conc.liste.isEmpty)
          const LigneCle('Aucune marque concurrente en rayon', '')
        else
          for (final c in conc.liste)
            LigneCle(c.marque, '${nombreFr(c.metrage)} m'),
        SectionTitre('Timing de visite', couleur: bleu),
        for (final e in EtapeDph.values)
          LigneEcart(titre: e.libelle, detail: v.chrono[e] ?? ''),
        if (v.etat != EtatVisite.brouillon)
          Pied(
            v.par != moi
                ? "Lecture seule : cette visite n'est pas la vôtre."
                : "Visite validée : elle n'est plus modifiable.",
            margeHaut: 10,
          ),
      ],
    );
  }
}

/// Un kit de la distribution numérique : nom suivi d'un « › » bleu, coche verte ; un appui ouvre sa composition.
class _LigneKit extends StatelessWidget {
  const _LigneKit({required this.nom, required this.onTap});

  final String nom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.ligne)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$nom '),
                    TextSpan(
                      text: '›',
                      style: AppText.t(14, c: context.univers.bleu),
                    ),
                  ],
                ),
                style: AppText.t(14),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '✓',
              style: AppText.t(14, w: FontWeight.w700, c: AppColors.ok),
            ),
          ],
        ),
      ),
    );
  }
}
