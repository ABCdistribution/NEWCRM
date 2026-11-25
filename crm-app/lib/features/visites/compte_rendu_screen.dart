import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/referentiels_visite.dart';
import '../../core/logic/classes.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/sync/referentiels_visite_provider.dart';
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
    final liste = v.indispensables.isEmpty
        ? const <ProduitIndispensable>[]
        : ref.watch(produitsIndispensablesProvider(v.magasinId)).value ??
              const [];
    final articlesPem = !v.estPem || v.articlesPem.isEmpty
        ? const <ArticlePem>[]
        : ref.watch(articlesPemProvider).value ?? const [];
    final cpVille = m?.adresse.split(', ').last.toUpperCase() ?? '';
    return PageUnivers(
      entete: TopbarEcran(
        titre: v.num > 0 ? 'Visite #${v.num}' : 'Visite',
        sous: 'réalisée par ${v.par}',
        tailleTitre: 16,
        droite: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (v.estPem) ...[const BadgePem(), const SizedBox(width: 6)],
            BadgeVisite(v.etat),
          ],
        ),
      ),
      enfants: [
        SectionTitre(
          v.estPem
              ? 'Compte rendu de la visite PEM'
              : 'Compte rendu de la visite',
          couleur: bleu,
          margeHaut: 0,
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
        if (m != null && classeValide(m.classe).isNotEmpty)
          LigneCle('Classe', classeValide(m.classe)),
        LigneCle('Adresse', '$cpVille (FR)'),
        SectionTitre('La visite', couleur: bleu),
        LigneCle('Réception visite', v.recu ?? '—'),
        LigneCle('Réalisée par', v.par),
        if (v.estPem) ...[
          SectionTitre('Articles PEM', couleur: bleu),
          LigneCle(
            'Articles absents',
            '${v.articlesPemAbsents} sur ${v.articlesPem.length}',
          ),
          LigneCle(
            'Articles mis en avant',
            '${v.articlesPemMisEnAvant} sur ${v.articlesPem.length - v.articlesPemAbsents}',
          ),
          for (final libelle in articlesPemAbsents(v, articlesPem))
            LigneCle(libelle, 'Absent'),
          for (final libelle in articlesPemMisEnAvant(v, articlesPem))
            LigneCle(libelle, 'Mis en avant'),
        ] else ...[
          SectionTitre('Commande liée à la visite', couleur: bleu),
          if (v.cmd != null)
            LigneCle('Commande', '#${v.cmd!.id} : ${v.cmd!.ht} - ${v.cmd!.liv}')
          else
            const LigneCle('Aucune commande liée', ''),
          if (v.cmd == null && v.raisonAbsence.isNotEmpty)
            LigneCle("Raison de l'absence de commande", v.raisonAbsence),
          if (v.commandeEnRayon == true) ...[
            SectionTitre('Commande à mettre en rayon', couleur: bleu),
            const LigneCle('Commande à mettre en rayon', 'Oui'),
          ],
          if (v.kits.isNotEmpty) ...[
            SectionTitre('Distribution numérique par kit', couleur: bleu),
            for (final code in v.kits)
              _LigneKit(
                nom: kitDe(code).nom,
                onTap: () => AppRoutes.detailKit(context, code),
              ),
          ],
          if (v.indispensables.isNotEmpty) ...[
            SectionTitre('Produits indispensables', couleur: bleu),
            LigneCle(
              'Produits absents',
              '${v.indispensablesAbsents} sur ${v.indispensables.length}',
            ),
            for (final libelle in indispensablesAbsents(v, liste))
              LigneCle(libelle, 'Absent'),
          ],
        ],
        SectionTitre('Timing de visite', couleur: bleu),
        for (final e in EtapeDph.values)
          if (_dansTiming(v, e))
            LigneEcart(
              titre: e.libellePour(v.typeVisite),
              detail: v.chrono[e] ?? '',
            ),
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

/// L'étape figure-t-elle dans le timing de cette visite ? Le début toujours ; les étapes du parcours du type de visite ;
/// « Produits indispensables » et « Articles PEM » seulement si elles ont été faites (la liste peut manquer).
bool _dansTiming(Visite v, EtapeDph e) {
  if (e == EtapeDph.debut) return true;
  if (!v.etapes.contains(e)) return false;
  return (e != EtapeDph.indispensables && e != EtapeDph.articlesPem) ||
      v.etapeFaite(e);
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
