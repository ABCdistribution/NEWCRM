/// État propre au catalogue : recherche et filtres (maquette `S.sProd`, `prodsFiltres` l.1237-1240).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';
import '../../../core/state/state.dart';
import '../../../core/sync/catalogue_provider.dart';

/// Recherche et filtres du « Référentiel produits » (`S.sProd`).
@immutable
class FiltresCatalogue {
  const FiltresCatalogue({
    this.q = '',
    this.marque,
    this.stock,
    this.promo = false,
    this.avant = false,
    this.kit = false,
    this.pem = false,
  });

  /// Texte cherché dans le nom, la marque, l'EAN et le code article (`q`).
  final String q;

  /// Marque retenue (`cat`), nulle = « Toutes les marques ».
  final String? marque;

  /// Niveau de stock retenu, nul = « Tous les stocks » (`'tous'`).
  final NiveauStock? stock;

  /// Interrupteurs « En promotion », « Mis en avant », « Kits », « Produits PEM ».
  final bool promo;
  final bool avant;
  final bool kit;
  final bool pem;

  static const Object _inchange = Object();

  /// Copie avec modifications ; `marque` et `stock` acceptent `null` (retour à « tous »).
  FiltresCatalogue copyWith({
    String? q,
    Object? marque = _inchange,
    Object? stock = _inchange,
    bool? promo,
    bool? avant,
    bool? kit,
    bool? pem,
  }) => FiltresCatalogue(
    q: q ?? this.q,
    marque: identical(marque, _inchange) ? this.marque : marque as String?,
    stock: identical(stock, _inchange) ? this.stock : stock as NiveauStock?,
    promo: promo ?? this.promo,
    avant: avant ?? this.avant,
    kit: kit ?? this.kit,
    pem: pem ?? this.pem,
  );

  /// Nombre de filtres actifs, affiché sur le bouton filtre (`nb` de `salesProduits`). La recherche n'en fait pas partie.
  int get nombreActifs =>
      (marque != null ? 1 : 0) +
      (stock != null ? 1 : 0) +
      (promo ? 1 : 0) +
      (avant ? 1 : 0) +
      (kit ? 1 : 0) +
      (pem ? 1 : 0);

  /// Vrai si le produit passe la recherche et tous les filtres (`prodsFiltres`).
  bool accepte(Produit p) {
    final recherche = q.toLowerCase();
    if (recherche.isNotEmpty &&
        !('${p.nom}${p.marque}${p.ean}${p.code}'.toLowerCase().contains(
          recherche,
        ))) {
      return false;
    }
    if (marque != null && p.cat != marque) return false;
    if (stock != null && p.stock != stock) return false;
    if (promo && (p.promo == null || p.promo!.isEmpty)) return false;
    if (avant && !p.avant) return false;
    if (kit && !p.kit) return false;
    if (pem && !p.pem) return false;
    return true;
  }
}

/// Recherche et filtres du catalogue ; se réinitialise quand le profil change (la maquette reconstruit tout `S`).
class FiltresCatalogueNotifier extends Notifier<FiltresCatalogue> {
  @override
  FiltresCatalogue build() {
    ref.watch(roleActifProvider);
    return const FiltresCatalogue();
  }

  /// Saisie dans la barre de recherche (`prodQ`).
  void chercher(String q) => state = state.copyWith(q: q);

  /// Choix d'une marque (`p-cat`), `null` pour « Toutes les marques ».
  void choisirMarque(String? marque) => state = state.copyWith(marque: marque);

  /// Choix d'un niveau de stock (`p-stock`), `null` pour « Tous les stocks ».
  void choisirStock(NiveauStock? stock) => state = state.copyWith(stock: stock);

  void basculerPromo() => state = state.copyWith(promo: !state.promo);
  void basculerAvant() => state = state.copyWith(avant: !state.avant);
  void basculerKit() => state = state.copyWith(kit: !state.kit);
  void basculerPem() => state = state.copyWith(pem: !state.pem);

  /// « Réinitialiser » (`p-reset`) : remet le stock et les interrupteurs à zéro. Comme dans la maquette, la marque
  /// choisie et le texte de recherche sont conservés.
  void reinitialiser() => state = state.copyWith(
    stock: null,
    promo: false,
    avant: false,
    kit: false,
    pem: false,
  );
}

final filtresCatalogueProvider =
    NotifierProvider<FiltresCatalogueNotifier, FiltresCatalogue>(
      FiltresCatalogueNotifier.new,
    );

/// Produits du référentiel qui passent la recherche et les filtres, dans l'ordre de la maquette
/// (catalogue, kits, produits PEM).
final produitsFiltresProvider = Provider<List<Produit>>((ref) {
  final f = ref.watch(filtresCatalogueProvider);
  ref.watch(
    catalogueProvider,
  ); // se recalcule quand le catalogue réel est chargé ou rafraîchi
  return tousProduits().where(f.accepte).toList();
});
