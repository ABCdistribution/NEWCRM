import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data.dart';
import '../../core/data/detail_produit.dart';
import '../../core/sync/detail_produit_provider.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'widgets/ligne_feuille.dart';

/// Ouvre la feuille « Fiche produit ». Maquette : modale `sproduit` l.1436-1440.
/// Appelée par `AppRoutes.ficheProduit(context, produitId)`.
Future<void> ouvrirFicheProduit(BuildContext context, String produitId) =>
    showAppSheet<void>(
      context,
      builder: (_) => FicheProduitSheet(produitId: produitId),
    );

/// Feuille « Fiche produit » : nom, prix HT indicatif, marque, famille, code article, EAN, colisage, stock, promotion
/// (ou version PEM réduite : code article et statut).
///
/// Comme dans la maquette, le titre de la feuille est le nom du produit ; une ligne dont la valeur est vide n'est
/// pas affichée.
class FicheProduitSheet extends ConsumerWidget {
  const FicheProduitSheet({super.key, required this.produitId});

  /// Identifiant du produit (« a1 », « kitKIT91265 », « pem20000 »…).
  final String produitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = produitParId(produitId);
    if (p == null) return const FeuilleBase(children: []);
    // Produit du CRM : tarifs, stock exact, promotions et remplaçants chargés à l'ouverture.
    final detail = ref.watch(detailProduitProvider(produitId)).value;
    return FicheProduitContenu(produit: p, detail: detail);
  }
}

/// Contenu de la fiche d'un produit connu : version PEM réduite ou version catalogue (`modale()` type `sproduit`).
class FicheProduitContenu extends StatelessWidget {
  const FicheProduitContenu({super.key, required this.produit, this.detail});

  final Produit produit;

  /// Détail venu du CRM (nul en démonstration ou tant qu'il n'est pas chargé).
  final DetailProduit? detail;

  @override
  Widget build(BuildContext context) {
    final p = produit;
    return FeuilleBase(
      titre: p.nom,
      children: [
        ...(p.pem ? _lignesPem(p) : _lignesCatalogue(context, p)),
        if (detail != null && !p.pem) ..._lignesDetail(context, detail!),
      ],
    );
  }

  /// Tarifs, stock exact, promotions en cours et produits de remplacement du CRM.
  List<Widget> _lignesDetail(BuildContext context, DetailProduit d) {
    final titre = AppText.t(13, w: FontWeight.w800, c: context.univers.bleu);
    return [
      if (d.stock != null) LigneFeuille('Quantité en stock', '${d.stock}'),
      if (d.tarifs.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text('TARIFS HT', style: titre),
        ),
        for (final t in d.tarifs)
          LigneFeuille(
            t.code == null ? 'Tarif' : 'Tarif ${t.code}',
            euros(t.montant),
          ),
      ],
      if (d.promos.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text('PROMOTIONS EN COURS', style: titre),
        ),
        for (final p in d.promos)
          LigneFeuille(
            p.libelle ?? 'Promotion',
            [
              if (p.du.isNotEmpty) 'du ${p.du}',
              if (p.au.isNotEmpty) 'au ${p.au}',
            ].join(' '),
          ),
      ],
      if (d.remplacements.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text('PRODUIT DE REMPLACEMENT', style: titre),
        ),
        for (final r in d.remplacements)
          LigneFeuille(
            r.nom,
            '${r.code.isEmpty ? '' : '${r.code} · '}${r.stock > 0 ? 'stock ${r.stock}' : 'rupture'}',
          ),
      ],
      if (d.details != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text('DESCRIPTIF', style: titre),
        ),
        Text(d.details!, style: AppText.t(13.5)),
      ],
      if (d.avantages != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Text('AVANTAGES', style: titre),
        ),
        Text(d.avantages!, style: AppText.t(13.5)),
      ],
    ];
  }

  /// Produit suivi lors des visites PEM : libellé, code article et statut (`p.pem` de la modale `sproduit`).
  List<Widget> _lignesPem(Produit p) {
    final statut = switch (p.actif) {
      true => 'Actif',
      false => 'Inactif',
      null => '',
    };
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Produit disponible dans les visites PEM',
          style: AppText.t(16, c: AppColors.muted),
        ),
      ),
      if (p.code.isNotEmpty) LigneFeuille('Code article', p.code),
      if (statut.isNotEmpty) LigneFeuille('Statut', statut),
    ];
  }

  /// Produit du catalogue ou kit : prix indicatif puis les caractéristiques renseignées.
  List<Widget> _lignesCatalogue(BuildContext context, Produit p) {
    final prix = p.prix;
    final pcb = p.pcb;
    final stock = p.stock;
    final promo = p.promo;
    return [
      // Code-barres juste sous le titre de la feuille (rien si l'EAN est vide ou non encodable).
      if (symboleCodeBarres(p.ean) != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Center(child: CodeBarres(p.ean)),
        ),
      if (prix != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${euros(prix)} HT (prix indicatif)',
            style: AppText.t(16, w: FontWeight.w800, c: context.univers.bleu),
          ),
        ),
      if (p.marque.isNotEmpty) LigneFeuille('Marque', p.marque),
      if (p.famille.isNotEmpty) LigneFeuille('Famille', p.famille),
      if (p.code.isNotEmpty) LigneFeuille('Code article', p.code),
      if (p.ean.isNotEmpty) LigneFeuille('EAN', p.ean),
      if (pcb != null) LigneFeuille('Colisage', '$pcb unités par colis'),
      if (stock != null) LigneFeuille('Stock', stock.libelle),
      if (promo != null && promo.isNotEmpty)
        const LigneFeuille('Promotion', 'En cours'),
    ];
  }
}
