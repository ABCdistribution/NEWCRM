import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data.dart';
import '../../../core/state/state.dart';
import 'commande_en_cours.dart';

/// Commande en cours de saisie (maquette : `S.cmd`). Nulle tant qu'aucune commande n'est démarrée ;
/// elle redevient nulle à la validation ou à la mise en attente, et à chaque changement de profil.
class CommandeEnCoursNotifier extends Notifier<CommandeEnCours?> {
  @override
  CommandeEnCours? build() {
    ref.watch(roleActifProvider);
    return null;
  }

  /// Démarre une commande vide (`startCommande`). `jeton` désigne l'écran qui la démarre.
  void demarrer({String? magasinId, String? visiteId, Object? jeton}) {
    state = CommandeEnCours(
      magasinId: magasinId,
      depuisVisite: visiteId,
      jeton: jeton,
    );
  }

  /// Reprend une commande mise en attente (`att-reprendre`) : recherche et marque remises à zéro.
  void reprendre(CommandeEnAttente a, int rang) {
    state = CommandeEnCours(
      magasinId: a.magasinId,
      lignes: List.of(a.lignes),
      note: a.note,
      pas: a.pas,
      dateMin: a.dateMin,
      motifPas: a.motifPas,
      motifAutre: a.motifAutre,
      deAttente: rang,
    );
  }

  /// Termine la commande (validée ou mise en attente) : `S.cmd = null`.
  void terminer() => state = null;

  void _maj(CommandeEnCours Function(CommandeEnCours c) f) {
    final c = state;
    if (c != null) state = f(c);
  }

  /// Choix du client à l'étape 1 (`cmd-magasin`).
  void choisirMagasin(String id) => _maj((c) => c.copyWith(magasinId: id));

  // ---- Catalogue : recherche et filtres ---------------------------------

  void majRecherche(String q) => _maj((c) => c.copyWith(q: q));

  /// Filtre de marque (`cmd-cat`) ; nul = toutes les marques.
  void choisirMarque(String? cat) => _maj((c) => c.copyWith(cat: cat));

  void basculerMasquer() => _maj((c) => c.copyWith(masquer: !c.masquer));

  /// Réinitialise les filtres (`cmd-reset`).
  void reinitialiserFiltres() =>
      _maj((c) => c.copyWith(cat: null, masquer: false));

  // ---- Lignes ------------------------------------------------------------

  /// `cmd-plus` : ajoute le produit au colisage, ou une unité de plus s'il est déjà dans le panier.
  void ajouter(String produitId) => _maj((c) {
    final l = c.ligne(produitId);
    if (l != null) {
      return c.copyWith(
        lignes: [
          for (final x in c.lignes)
            identical(x, l) ? l.avecQuantite(l.qty + 1) : x,
        ],
      );
    }
    final p = produitParId(produitId);
    return c.copyWith(
      lignes: [...c.lignes, LigneCommande(produitId, p?.pcb ?? 1)],
    );
  });

  /// `cmd-moins` : une unité de moins ; la ligne disparaît à zéro.
  void retirer(String produitId) => _maj((c) {
    final l = c.ligne(produitId);
    if (l == null) return c;
    final q = l.qty - 1;
    return c.copyWith(
      lignes: [
        for (final x in c.lignes)
          if (!identical(x, l)) x else if (q > 0) l.avecQuantite(q),
      ],
    );
  });

  /// `cmd-choisir` : on garde ce qui est disponible du produit `origine`, le reste passe au produit de remplacement.
  void choisirRemplacement(String origine, String remplacement) => _maj((c) {
    final p = produitParId(origine);
    if (p == null) return c;
    final l = c.ligne(origine);
    final reste = l == null ? 0 : math.max(0, l.qty - math.max(0, p.qte ?? 0));
    final besoin = quantiteReprise(p, l);
    var lignes = [
      for (final x in c.lignes)
        if (l != null && reste != 0 && identical(x, l))
          x.avecQuantite(math.max(0, p.qte ?? 0))
        else
          x,
    ].where((x) => x.qty > 0).toList();
    final existante = lignes.where((x) => x.produitId == remplacement);
    if (existante.isNotEmpty) {
      final ex = existante.first;
      lignes = [
        for (final x in lignes)
          identical(x, ex)
              ? LigneCommande(
                  x.produitId,
                  x.qty + besoin,
                  remplace: x.remplace ?? origine,
                )
              : x,
      ];
    } else {
      lignes = [
        ...lignes,
        LigneCommande(remplacement, besoin, remplace: origine),
      ];
    }
    return c.copyWith(lignes: lignes);
  });

  // ---- Panier ------------------------------------------------------------

  void majNote(String note) => _maj((c) => c.copyWith(note: note));

  /// Case « Ne pas livrer avant une date précise » (`cmd-pasavant`). Renvoie vrai si la consigne vient d'être
  /// activée : l'appelant ouvre alors la feuille de saisie.
  bool basculerConsigne() {
    final c = state;
    if (c == null) return false;
    if (c.pas) {
      state = c.copyWith(pas: false, dateMin: '', motifPas: '', motifAutre: '');
      return false;
    }
    state = c.copyWith(pas: true);
    return true;
  }

  void choisirMotif(String motif) => _maj((c) => c.copyWith(motifPas: motif));

  void majDateMin(String iso) => _maj((c) => c.copyWith(dateMin: iso));

  /// `pas-annuler` : une consigne incomplète est abandonnée, une consigne complète est conservée telle que modifiée.
  void annulerConsigne() => _maj(
    (c) => c.consigneComplete
        ? c
        : c.copyWith(pas: false, dateMin: '', motifPas: '', motifAutre: ''),
  );
}

final commandeEnCoursProvider =
    NotifierProvider<CommandeEnCoursNotifier, CommandeEnCours?>(
      CommandeEnCoursNotifier.new,
    );
