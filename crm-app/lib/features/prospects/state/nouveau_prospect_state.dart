/// État du formulaire « Nouveau prospect » (maquette : `S.fp` et `S.fpErr`).
///
/// Il disparaît avec l'écran : chaque ouverture repart d'un formulaire vide (`nouveau-prospect` : `S.fp = { etape: 'NOUVEAU' }`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/nouveau_prospect.dart';

/// Champs saisis et messages d'erreur affichés sous les champs.
class EtatNouveauProspect {
  const EtatNouveauProspect({
    this.brouillon = const BrouillonProspect(),
    this.erreurs = const {},
  });

  final BrouillonProspect brouillon;

  /// Message par champ (`enseigne`, `raison`, `email`, `proba`, `pot`).
  final Map<String, String> erreurs;
}

class NouveauProspectNotifier extends Notifier<EtatNouveauProspect> {
  @override
  EtatNouveauProspect build() => const EtatNouveauProspect();

  /// Remplace le brouillon par sa version modifiée (les erreurs restent affichées jusqu'à la prochaine validation).
  void maj(BrouillonProspect Function(BrouillonProspect b) f) =>
      state = EtatNouveauProspect(
        brouillon: f(state.brouillon),
        erreurs: state.erreurs,
      );

  /// Valide le brouillon, affiche les erreurs et dit s'il est valide (`np-creer`).
  bool valider() {
    final erreurs = validerProspect(state.brouillon);
    state = EtatNouveauProspect(brouillon: state.brouillon, erreurs: erreurs);
    return erreurs.isEmpty;
  }
}

final nouveauProspectProvider =
    NotifierProvider.autoDispose<NouveauProspectNotifier, EtatNouveauProspect>(
      NouveauProspectNotifier.new,
    );
