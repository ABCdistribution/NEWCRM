/// État du formulaire « Nouveau prospect » (maquette : `S.fp` et `S.fpErr`).
///
/// Il disparaît avec l'écran : chaque ouverture repart d'un formulaire vide (`nouveau-prospect` : `S.fp = { etape: 'NOUVEAU' }`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/erreur_api.dart';
import '../../../core/logic/id_apk.dart';
import '../../../core/sync/catalogue_provider.dart';
import '../logic/nouveau_prospect.dart';

/// Champs saisis et messages d'erreur affichés sous les champs.
class EtatNouveauProspect {
  const EtatNouveauProspect({
    this.brouillon = const BrouillonProspect(),
    this.erreurs = const {},
    this.envoi = false,
    this.erreurApi,
  });

  final BrouillonProspect brouillon;

  /// Message par champ (`enseigne`, `raison`, `ville`, `cp`, `tel`, `email`, `proba`, `pot`).
  final Map<String, String> erreurs;

  /// Création en cours d'envoi au CRM : le bouton est désactivé.
  final bool envoi;

  /// Message de l'API quand la création a échoué (le formulaire reste ouvert).
  final String? erreurApi;

  EtatNouveauProspect avec({
    BrouillonProspect? brouillon,
    Map<String, String>? erreurs,
    bool? envoi,
    String? erreurApi,
    bool effacerErreurApi = false,
  }) => EtatNouveauProspect(
    brouillon: brouillon ?? this.brouillon,
    erreurs: erreurs ?? this.erreurs,
    envoi: envoi ?? this.envoi,
    erreurApi: effacerErreurApi ? null : (erreurApi ?? this.erreurApi),
  );
}

class NouveauProspectNotifier extends Notifier<EtatNouveauProspect> {
  /// Identifiant d'idempotence de la soumission : tiré au premier envoi, gardé pour les nouveaux essais.
  String? _idApk;

  @override
  EtatNouveauProspect build() => const EtatNouveauProspect();

  /// Remplace le brouillon par sa version modifiée (les erreurs restent affichées jusqu'à la prochaine validation).
  void maj(BrouillonProspect Function(BrouillonProspect b) f) =>
      state = state.avec(brouillon: f(state.brouillon));

  /// Valide le brouillon, affiche les erreurs et dit s'il est valide (`np-creer`).
  bool valider() {
    final erreurs = validerProspect(state.brouillon);
    state = state.avec(erreurs: erreurs);
    return erreurs.isEmpty;
  }

  /// Connecté : `POST /prospects/apk` (idempotent par `idApk`). Vrai si le CRM a créé le prospect ; sinon le message de
  /// l'API est dans `erreurApi` et le formulaire reste ouvert.
  Future<bool> envoyer() async {
    if (state.envoi) return false;
    final idApk = _idApk ??= genererIdApkUuid();
    final corps = corpsProspect(state.brouillon, idApk: idApk);
    final api = ref.read(apiEcritureProvider);
    state = state.avec(envoi: true, effacerErreurApi: true);
    try {
      await api.envoyer('POST', '/prospects/apk', corps: corps);
    } on ErreurApi catch (e) {
      if (ref.mounted) {
        state = state.avec(envoi: false, erreurApi: messageErreurProspect(e));
      }
      return false;
    } catch (_) {
      if (ref.mounted) {
        state = state.avec(
          envoi: false,
          erreurApi: const ErreurApi(TypeErreurApi.inattendue).message,
        );
      }
      return false;
    }
    if (ref.mounted) state = state.avec(envoi: false);
    return true;
  }
}

final nouveauProspectProvider =
    NotifierProvider.autoDispose<NouveauProspectNotifier, EtatNouveauProspect>(
      NouveauProspectNotifier.new,
    );
