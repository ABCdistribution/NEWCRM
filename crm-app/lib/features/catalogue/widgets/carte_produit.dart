import 'package:flutter/material.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

/// Couleur du niveau de stock sur une carte produit (`couleur` de `salesProduits` : `var(--ok)`, `#B45309`, `var(--alert)`).
Color couleurStock(NiveauStock stock) => switch (stock) {
  NiveauStock.enStock => AppColors.ok,
  NiveauStock.stockBas => const Color(0xFFB45309),
  NiveauStock.rupture => AppColors.alert,
};

/// Carte d'un produit dans la liste du « Référentiel produits » (`salesProduits` l.1247) : nom, marque et famille,
/// pastilles (promotion, mis en avant, kit, PEM, actif), prix HT et stock à droite, référence en pied.
class CarteProduit extends StatelessWidget {
  const CarteProduit({super.key, required this.produit, required this.onTap});

  final Produit produit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = produit;
    final promo = p.promo;
    final stock = p.stock;
    final prix = p.prix;
    return AppCarte(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLigne(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nom, style: AppText.titreCarte),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${p.marque.isEmpty ? '' : '${p.marque} · '}${p.famille}',
                        style: AppText.sousCarte,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (promo != null && promo.isNotEmpty)
                            Pastille(promo, variante: VariantePastille.rose),
                          if (p.avant)
                            const Pastille(
                              'Mis en avant',
                              variante: VariantePastille.bleu,
                            ),
                          if (p.kit) const Pastille('Kit'),
                          if (p.pem) const Pastille('PEM'),
                          if (p.actif == true)
                            const Pastille(
                              'Actif',
                              variante: VariantePastille.vert,
                            )
                          else if (p.actif == false)
                            const Pastille('Inactif'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (prix != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(euros(prix), style: AppText.gras),
                    Text('HT', style: AppText.t(11, c: AppColors.muted)),
                    if (stock != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${stock.libelle}${p.qte != null && p.qte != 0 ? ' · ${p.qte}' : ''}',
                          style: AppText.t(
                            12,
                            w: FontWeight.w700,
                            c: couleurStock(stock),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Réf. ${p.code}',
              style: AppText.t(11, c: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
