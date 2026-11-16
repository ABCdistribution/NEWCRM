import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/regles_commande.dart';
import 'state/commande_en_cours.dart';
import 'state/commande_provider.dart';
import 'widgets/stock_widgets.dart';

/// Ouvre la feuille « Produits de remplacement ». Maquette : modale `cmd-remp` l.1644-1651, `remplacements` l.1589-1593, `cmd-choisir` l.1687-1693.
/// Appelée par `AppRoutes.produitsRemplacement(context, produitId)`.
Future<void> ouvrirProduitsRemplacement(
  BuildContext context,
  String produitId,
) => showAppSheet<void>(
  context,
  builder: (_) => ProduitsRemplacementSheet(produitId: produitId),
);

/// Feuille « Produits de remplacement » : encadré d'erreur du produit, jusqu'à 3 produits de la même marque en stock, un appui reprend la quantité.
class ProduitsRemplacementSheet extends ConsumerWidget {
  const ProduitsRemplacementSheet({super.key, required this.produitId});

  /// Produit en rupture ou en stock insuffisant.
  final String produitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = produitParId(produitId);
    if (p == null) {
      return const FeuilleBase(titre: 'Produits de remplacement', children: []);
    }
    final cmd = ref.watch(commandeEnCoursProvider);
    final l = cmd?.ligne(produitId);
    final besoin = quantiteReprise(p, l);
    final info = infoStock(p);
    final propositions = produitsDeRemplacement(p);
    return FeuilleBase(
      titre: 'Produits de remplacement',
      children: [
        _ErreurProduit(
          nom: p.nom,
          detail: p.stock == NiveauStock.rupture
              ? info.texte
              : 'Stock insuffisant : ${p.qte} disponibles, ${l?.qty ?? ''} demandés',
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(
            TextSpan(
              text:
                  'Proposés de la même marque, en stock (même famille en premier). Quantité reprise : ',
              children: [
                TextSpan(
                  text: '$besoin',
                  style: AppText.t(13, w: FontWeight.w700, c: AppColors.muted),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            style: AppText.t(13, c: AppColors.muted),
          ),
        ),
        if (propositions.isEmpty)
          const Vide('Aucun produit de remplacement disponible.')
        else
          for (final r in propositions)
            _CarteRemplacement(
              remplacement: r,
              memeFamille: r.famille == p.famille,
              onChoisir: () {
                ref
                    .read(commandeEnCoursProvider.notifier)
                    .choisirRemplacement(p.id, r.id);
                AppToast.show(context, '${r.nom} ajouté en remplacement.');
                Navigator.of(context).pop();
              },
            ),
      ],
    );
  }
}

/// Encadré d'erreur du produit à remplacer : son nom en gras, puis la raison (`.erreur`).
class _ErreurProduit extends StatelessWidget {
  const _ErreurProduit({required this.nom, required this.detail});

  final String nom;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pRougeFond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: nom,
              style: AppText.t(
                13,
                w: FontWeight.w700,
                c: AppColors.pRougeTexte,
              ),
            ),
            TextSpan(text: '\n$detail'),
          ],
        ),
        style: AppText.t(13, c: AppColors.pRougeTexte),
      ),
    );
  }
}

/// Un produit proposé : nom, marque et famille (« même famille » en bleu), stock, prix et bouton « Choisir ».
class _CarteRemplacement extends StatelessWidget {
  const _CarteRemplacement({
    required this.remplacement,
    required this.memeFamille,
    required this.onChoisir,
  });

  final Produit remplacement;
  final bool memeFamille;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final r = remplacement;
    final u = context.univers;
    return AppCarte(
      margeBas: 8,
      child: AppLigne(
        alignement: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.nom, style: AppText.t(14, w: FontWeight.w800)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    text: '${r.marque} · ${r.famille}',
                    children: [
                      if (memeFamille) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: 'même famille',
                          style: AppText.t(12.5, w: FontWeight.w700, c: u.bleu),
                        ),
                      ],
                    ],
                  ),
                  style: AppText.sousCarte,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: LigneStock(
                    infoStock(r),
                    taille: 12,
                    suite: ' · ${euros(r.prix ?? 0)} HT',
                  ),
                ),
              ],
            ),
          ),
          AppBouton(
            'Choisir',
            petit: true,
            variante: VarianteBouton.plein,
            pleineLargeur: false,
            paddingH: 12,
            onPressed: onChoisir,
          ),
        ],
      ),
    );
  }
}
