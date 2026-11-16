import 'package:flutter/material.dart';

import '../../core/data/data.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/visites_data.dart';
import 'logic/visites_logique.dart';

/// Ouvre la feuille « Détail du kit ». Maquette : modale `kit-detail` l.1345-1351 et `KIT_PRODUITS` l.361-366.
/// Appelée par `AppRoutes.detailKit(context, codeKit)`.
Future<void> ouvrirDetailKit(BuildContext context, String codeKit) =>
    showAppSheet<void>(
      context,
      builder: (_) => KitDetailSheet(codeKit: codeKit),
    );

/// Feuille « Détail du kit » : nom du kit, « Réf. … · N produits dans le kit », une ligne « ×6 » par produit du kit, bouton Fermer.
class KitDetailSheet extends StatelessWidget {
  const KitDetailSheet({super.key, required this.codeKit});

  /// Code du kit (« COSMIA-01 », « 900024 »…).
  final String codeKit;

  @override
  Widget build(BuildContext context) {
    final kit = kitDe(codeKit);
    final composition = compositionKitsDemo[codeKit] ?? const [];
    final lignes = <Widget>[];
    for (final c in composition) {
      for (final p in produitsCatalogue) {
        if (p.code == c.code) lignes.add(_LigneComposant(c.qte, p));
      }
    }
    return FeuilleBase(
      titre: kit.nom,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Réf. ${kit.code} · ${composition.length} produit${sPluriel(composition.length)} dans le kit',
            style: AppText.t(13, c: AppColors.muted),
          ),
        ),
        if (composition.isEmpty)
          const Vide('Composition non renseignée.')
        else
          ...lignes,
        Rangee(
          margeHaut: 14,
          children: [
            AppBouton(
              'Fermer',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Un produit de la composition d'un kit : « ×6 » dans une pastille bleue, nom, marque, référence et EAN.
class _LigneComposant extends StatelessWidget {
  const _LigneComposant(this.qte, this.produit);

  final int qte;
  final Produit produit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.ligne)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.pBleuFond,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '×$qte',
              style: AppText.t(13, w: FontWeight.w800, c: AppColors.pBleuTexte),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(produit.nom, style: AppText.t(13.5, w: FontWeight.w700)),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '${produit.marque} · Réf. ${produit.code} · EAN ${produit.ean}',
                    style: AppText.t(12, c: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
