import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';

/// Ouvre la feuille de suivi du transport d'une commande. Maquette : modale `slivraison` l.1424-1435.
/// Appelée par `AppRoutes.detailLivraison(context, commandeId)` (accueil, clients, commandes).
Future<void> ouvrirDetailLivraison(BuildContext context, String commandeId) =>
    showAppSheet<void>(
      context,
      builder: (_) => DetailLivraisonSheet(commandeId: commandeId),
    );

/// Feuille « CDE-2041 · Client » : statut, suivi du transport, transporteur, lien de suivi du colis.
class DetailLivraisonSheet extends ConsumerWidget {
  const DetailLivraisonSheet({super.key, required this.commandeId});

  final String commandeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(commandeParIdProvider(commandeId));
    final m = c == null ? null : ref.watch(magasinParIdProvider(c.magasinId));
    final titre = '$commandeId${m != null ? ' · ${m.nom}' : ''}';
    if (c == null) return FeuilleBase(titre: titre, children: const []);
    final u = context.univers;
    final livree = c.statut == StatutLivraison.livree;
    final futures = [
      'Commande reçue',
      'Expédiée',
      'Livrée',
    ].where((x) => !c.evenements.any((e) => e.libelle == x)).toList();
    return FeuilleBase(
      titre: titre,
      children: [
        // Sa marge basse (10 px) se fusionne avec celle de « SUIVI DU TRANSPORT » (14 px), comme en CSS.
        Row(
          children: [
            Pastille(
              c.statut.libelle,
              variante: livree ? VariantePastille.vert : VariantePastille.jaune,
            ),
            if (classeValide(m?.classe).isNotEmpty) ...[
              const SizedBox(width: 6),
              PastilleClasse(m?.classe),
            ],
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${c.ht} HT · ${c.lignes} références${c.colis > 0 ? ' · ${c.colis} colis' : ''}',
                style: AppText.t(12.5, c: AppColors.muted),
              ),
            ),
          ],
        ),
        SectionTitre('Suivi du transport', couleur: u.bleu),
        for (final e in c.evenements)
          LigneEcart(titre: e.libelle, detail: e.detail),
        if (!livree)
          for (final x in futures)
            LigneEcart(
              titre: x,
              detail: x == 'Livrée' ? 'Prévue ${c.eta}' : 'À venir',
              symbole: '…',
              fond: AppColors.ecartGrisFond,
              texte: AppColors.ecartGrisTexte,
            ),
        SectionTitre('Transporteur', couleur: u.bleu),
        _LigneFeuille(
          'Origine',
          c.estEdi ? 'Commande EDI' : "Saisie dans l'appli",
        ),
        _LigneFeuille('Transporteur', c.transporteur ?? 'Pas encore attribué'),
        _LigneFeuille('N° de suivi', c.suivi ?? '—'),
        _LigneFeuille('Livraison', c.eta),
        if (c.pasAvant != null) ...[
          _LigneFeuille('Ne pas livrer avant', dateFr(c.pasAvant!)),
          if (c.motifPas != null && c.motifPas!.isNotEmpty)
            _LigneFeuille('Motif', c.motifPas!),
        ],
        if (c.suivi != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppBouton(
              '🚚 Suivre le colis chez le transporteur',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: () => AppToast.show(
                context,
                'Ouverture du suivi du transporteur (lien externe).',
              ),
            ),
          ),
      ],
    );
  }
}

/// Ligne « libellé gris / valeur en gras » d'une feuille (`.feuille .ch` : 15 px, marges de 14 px sur 4 px).
class _LigneFeuille extends StatelessWidget {
  const _LigneFeuille(this.cle, this.valeur);

  final String cle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ligne)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cle, style: AppText.t(15, c: AppColors.muted)),
          Flexible(
            child: Text(
              valeur,
              textAlign: TextAlign.right,
              style: AppText.t(15, w: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
