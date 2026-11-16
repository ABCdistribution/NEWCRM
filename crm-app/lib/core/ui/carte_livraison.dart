import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/commandes_demo.dart';
import '../logic/dates.dart';
import '../models/models.dart';
import '../nav/app_routes.dart';
import '../state/state.dart';
import '../theme/theme.dart';
import 'cartes.dart';
import 'progression.dart';

/// Carte de suivi de livraison d'une commande (`carteLivraison`), partagée par l'accueil et le lot commandes.
///
/// Un appui ouvre le détail du transport (`AppRoutes.detailLivraison`) sauf si `onTap` est fourni.
class CarteLivraison extends ConsumerWidget {
  const CarteLivraison(this.commande, {super.key, this.onTap});

  final Commande commande;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = commande;
    final magasin = ref.watch(magasinParIdProvider(c.magasinId));
    final moi = ref.watch(profilActifProvider).nom;
    final u = context.univers;
    final auteur = auteurCommande(c);
    final etape = c.statut == StatutLivraison.livree
        ? 3
        : (c.transporteur != null ? 2 : 1);
    final ligne = c.statut == StatutLivraison.livree
        ? c.eta
        : c.transporteur == null
        ? 'Départ prévu ${c.eta}'
        : 'Livraison prévue ${c.eta}';
    return AppCarte(
      onTap: onTap ?? () => AppRoutes.detailLivraison(context, c.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppLigne(
            alignement: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      magasin?.nom ?? c.magasinId,
                      style: AppText.titreCarte,
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: c.id),
                          if (c.estEdi) ...[
                            const TextSpan(text: ' '),
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Pastille(
                                'EDI',
                                variante: VariantePastille.violet,
                                petite: true,
                              ),
                            ),
                          ],
                          TextSpan(text: ' · ${c.ht} HT · ${c.lignes} réf.'),
                          if (auteur != null && auteur != moi) ...[
                            const TextSpan(text: ' · par '),
                            TextSpan(
                              text: auteur,
                              style: AppText.t(12.5, w: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                      style: AppText.sousCarte,
                    ),
                  ],
                ),
              ),
              Pastille(
                c.statut.libelle,
                variante: c.statut == StatutLivraison.livree
                    ? VariantePastille.vert
                    : VariantePastille.jaune,
              ),
            ],
          ),
          BarreLivraison(
            noms: const ['Reçue', 'Expédiée', 'Livrée'],
            etats: [
              for (var i = 1; i <= 3; i++)
                i <= etape
                    ? EtatSegmentLivraison.rempli
                    : EtatSegmentLivraison.vide,
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '🚚 ${c.transporteur != null ? '${c.transporteur} · ' : ''}$ligne',
              style: AppText.t(12.5, c: AppColors.muted),
            ),
          ),
          if (c.pasAvant != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⏳ Ne pas livrer avant le ${dateFr(c.pasAvant!)}${c.motifPas != null ? ' · ${c.motifPas}' : ''}',
                style: AppText.t(12.5, w: FontWeight.w700, c: u.bleu),
              ),
            ),
        ],
      ),
    );
  }
}
