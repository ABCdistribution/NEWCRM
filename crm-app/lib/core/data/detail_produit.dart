/// Tarif d'un article (`codeTarif` : liste de prix du CRM).
class TarifProduit {
  const TarifProduit({this.code, required this.montant});

  final String? code;
  final double montant;
}

/// Promotion en cours sur un article, avec ses dates (« jj/mm/aaaa », vides si absentes).
class PromoProduit {
  const PromoProduit({this.libelle, this.du = '', this.au = ''});

  final String? libelle;
  final String du;
  final String au;
}

/// Produit proposé à la place d'un article en rupture.
class RemplacementProduit {
  const RemplacementProduit({
    required this.nom,
    required this.code,
    required this.stock,
    this.marque,
  });

  final String nom;
  final String code;

  /// Quantité disponible (0 ou moins : rupture).
  final int stock;
  final String? marque;
}

/// Ce que le CRM sait d'un article au-delà de la liste : tarifs, stock exact, promotions, remplaçants, descriptif.
class DetailProduit {
  const DetailProduit({
    required this.tarifs,
    required this.promos,
    required this.remplacements,
    this.stock,
    this.details,
    this.avantages,
  });

  final List<TarifProduit> tarifs;
  final List<PromoProduit> promos;
  final List<RemplacementProduit> remplacements;

  /// Quantité en stock.
  final int? stock;
  final String? details;
  final String? avantages;
}

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

String _date(Object? v) {
  final d = v is String ? DateTime.tryParse(v)?.toLocal() : null;
  if (d == null) return '';
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${p2(d.day)}/${p2(d.month)}/${d.year}';
}

/// Détail à partir de la réponse de `GET /articles/:id`.
DetailProduit detailProduitDepuisJson(Map<String, dynamic> j) {
  final stock = j['stock'];
  return DetailProduit(
    tarifs: [
      for (final t in (j['tarifs'] as List? ?? const []))
        if (t is Map<String, dynamic> && t['montant'] is num)
          TarifProduit(
            code: _texte(t['codeTarif']),
            montant: (t['montant'] as num).toDouble(),
          ),
    ],
    promos: [
      for (final p in (j['promos'] as List? ?? const []))
        if (p is Map<String, dynamic>)
          PromoProduit(
            libelle: _texte(p['libelle']),
            du: _date(p['dateDebut']),
            au: _date(p['dateFin']),
          ),
    ],
    remplacements: [
      for (final r in (j['remplacements'] as List? ?? const []))
        if (r is Map<String, dynamic> && r['article'] is Map<String, dynamic>)
          (() {
            final a = r['article'] as Map<String, dynamic>;
            final marque = a['marque'];
            return RemplacementProduit(
              nom: _texte(a['libelle']) ?? '—',
              code: _texte(a['codeAs400']) ?? '',
              stock: a['stock'] is num ? (a['stock'] as num).toInt() : 0,
              marque: marque is Map ? _texte(marque['nom']) : null,
            );
          })(),
    ],
    stock: stock is num ? stock.toInt() : null,
    details: _texte(j['details']),
    avantages: _texte(j['avantages']),
  );
}
