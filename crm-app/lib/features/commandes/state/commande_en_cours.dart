import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/data/data.dart';
import '../../../core/models/models.dart';

/// Une ligne du panier : un produit, sa quantité et, le cas échéant, le produit qu'elle remplace
/// (maquette : `{ id, qty, remplace }`).
@immutable
class LigneCommande {
  const LigneCommande(this.produitId, this.qty, {this.remplace});

  final String produitId;
  final int qty;

  /// Identifiant du produit en rupture ou en stock insuffisant que cette ligne remplace.
  final String? remplace;

  LigneCommande avecQuantite(int q) =>
      LigneCommande(produitId, q, remplace: remplace);

  /// Prix HT d'une unité (les produits du catalogue ont tous un prix).
  double get prix => produitParId(produitId)?.prix ?? 0;
}

/// Motif d'une consigne « Ne pas livrer avant » : « Autre » prend le texte saisi, sinon le motif choisi (`motifFinal`).
String motifFinal(String motifPas, String motifAutre) => motifPas == 'Autre'
    ? (motifAutre.trim().isEmpty ? 'Autre' : motifAutre.trim())
    : motifPas;

/// Quantité reprise par un produit de remplacement : le manque de stock s'il y en a un, sinon le colisage
/// du produit remplacé (`besoin` de `modaleRemplacement` et de `cmd-choisir`).
int quantiteReprise(Produit p, LigneCommande? ligne) {
  final int reste = ligne == null
      ? 0
      : math.max<int>(0, ligne.qty - math.max<int>(0, p.qte ?? 0));
  return reste != 0 ? reste : (p.pcb ?? 0);
}

const Object _inchange = Object();

/// Commande en cours de saisie (maquette : `S.cmd`).
@immutable
class CommandeEnCours {
  const CommandeEnCours({
    this.magasinId,
    this.lignes = const [],
    this.cat,
    this.q = '',
    this.note = '',
    this.pas = false,
    this.dateMin = '',
    this.motifPas = '',
    this.motifAutre = '',
    this.deAttente,
    this.depuisVisite,
    this.masquer = false,
    this.jeton,
  });

  /// Client de la commande ; nul à l'étape « choisissez le client ».
  final String? magasinId;
  final List<LigneCommande> lignes;

  /// Marque filtrée dans le catalogue (nul = toutes les marques).
  final String? cat;

  /// Texte de la recherche de produit.
  final String q;

  /// Remarque pour l'ADV.
  final String note;

  /// Consigne « Ne pas livrer avant » activée, sa date (`aaaa-mm-jj`) et son motif.
  final bool pas;
  final String dateMin;
  final String motifPas;
  final String motifAutre;

  /// Rang de la commande en attente reprise (`fromAttente`).
  final int? deAttente;

  /// Visite d'où part la commande (`depuisVisite`).
  final String? depuisVisite;

  /// Masquer les produits en rupture dans le catalogue.
  final bool masquer;

  /// Identifie l'écran de prise de commande qui a démarré cette commande (voir `PriseCommandeScreen`).
  final Object? jeton;

  LigneCommande? ligne(String produitId) {
    for (final l in lignes) {
      if (l.produitId == produitId) return l;
    }
    return null;
  }

  /// Nombre d'articles (`nbArticles`).
  int get nbArticles => lignes.fold(0, (t, l) => t + l.qty);

  /// Total HT (`totalCmd`).
  double get total => lignes.fold(0.0, (t, l) => t + l.qty * l.prix);

  /// Nombre de filtres actifs de la recherche de produit (marque, masquer les ruptures).
  int get nbFiltres => (cat != null ? 1 : 0) + (masquer ? 1 : 0);

  /// La consigne « ne pas livrer avant » est-elle complète ? (`d.dateMin && d.motifPas`).
  bool get consigneComplete => dateMin.isNotEmpty && motifPas.isNotEmpty;

  CommandeEnCours copyWith({
    Object? magasinId = _inchange,
    List<LigneCommande>? lignes,
    Object? cat = _inchange,
    String? q,
    String? note,
    bool? pas,
    String? dateMin,
    String? motifPas,
    String? motifAutre,
    bool? masquer,
  }) {
    return CommandeEnCours(
      magasinId: identical(magasinId, _inchange)
          ? this.magasinId
          : magasinId as String?,
      lignes: lignes ?? this.lignes,
      cat: identical(cat, _inchange) ? this.cat : cat as String?,
      q: q ?? this.q,
      note: note ?? this.note,
      pas: pas ?? this.pas,
      dateMin: dateMin ?? this.dateMin,
      motifPas: motifPas ?? this.motifPas,
      motifAutre: motifAutre ?? this.motifAutre,
      deAttente: deAttente,
      depuisVisite: depuisVisite,
      masquer: masquer ?? this.masquer,
      jeton: jeton,
    );
  }
}

/// Commande mise de côté, non envoyée (maquette : une entrée de `S.attente`).
@immutable
class CommandeEnAttente {
  const CommandeEnAttente({
    required this.magasinId,
    required this.lignes,
    required this.date,
    this.pas = false,
    this.dateMin = '',
    this.motifPas = '',
    this.motifAutre = '',
    this.note = '',
  });

  final String magasinId;
  final List<LigneCommande> lignes;

  /// « 3 nov. 17:40 ».
  final String date;
  final bool pas;
  final String dateMin;
  final String motifPas;
  final String motifAutre;
  final String note;

  int get nbArticles => lignes.fold(0, (t, l) => t + l.qty);
  double get total => lignes.fold(0.0, (t, l) => t + l.qty * l.prix);
}
