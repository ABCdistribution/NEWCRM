import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/erreur_api.dart';
import '../db/cle_base.dart';
import '../logic/dates.dart';
import '../state/state.dart';
import 'auth_api.dart';
import 'utilisateur.dart';

/// Session enregistrée dans le coffre sécurisé de l'appareil (jeton et utilisateur).
class StockageSession {
  const StockageSession(this._stockage);

  final StockageSecret _stockage;

  static const nomSecret = 'crm_session';

  Future<void> sauver(ReponseConnexion reponse) => _stockage.ecrire(
    nomSecret,
    jsonEncode({
      'jeton': reponse.jeton,
      'utilisateur': reponse.utilisateur.toJson(),
    }),
  );

  /// Utilisateur de la session enregistrée, ou null (absente, effacée ou illisible).
  Future<Utilisateur?> lire() async {
    final brut = await _stockage.lire(nomSecret);
    if (brut == null || brut.isEmpty) return null;
    try {
      final j = jsonDecode(brut) as Map<String, dynamic>;
      final u = Utilisateur.fromJson(j['utilisateur'] as Map<String, dynamic>);
      return u.role == null || j['jeton'] is! String ? null : u;
    } catch (_) {
      return null;
    }
  }

  /// Jeton de la session enregistrée, ou null.
  Future<String?> jeton() async {
    final brut = await _stockage.lire(nomSecret);
    if (brut == null || brut.isEmpty) return null;
    try {
      final j = jsonDecode(brut) as Map<String, dynamic>;
      return j['jeton'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> effacer() => _stockage.ecrire(nomSecret, '');
}

final authApiProvider = Provider<AuthApi>((ref) => AuthApiHttp());
final stockageSessionProvider = Provider<StockageSession>(
  (ref) => const StockageSession(StockageSecretSysteme()),
);

/// Utilisateur connecté, ou null (pas de session, ou mode démonstration).
///
/// La session survit au redémarrage de l'application (lue au lancement, sans réseau). Se connecter fixe aussi le
/// profil ([roleProvider]) d'après le rôle de l'API.
class SessionNotifier extends Notifier<Utilisateur?> {
  SessionNotifier([this._initiale]);

  final Utilisateur? _initiale;

  @override
  Utilisateur? build() {
    // Connecté au CRM : la date du jour est la vraie (la démonstration reste figée au 4 novembre).
    DemoTemps.reel = _initiale != null;
    return _initiale;
  }

  /// Connecte l'utilisateur à l'API (Active Directory). Lève [ErreurApi] en cas d'échec.
  Future<void> connecter(String identifiant, String motDePasse) async {
    final reponse = await ref
        .read(authApiProvider)
        .connecter(identifiant.trim(), motDePasse);
    final role = reponse.utilisateur.role;
    if (role == null) throw const ErreurApi(TypeErreurApi.refuse);
    await ref.read(stockageSessionProvider).sauver(reponse);
    ref.read(attenteConnexionProvider.notifier).demander();
    DemoTemps.reel = true;
    state = reponse.utilisateur;
    ref.read(roleProvider.notifier).choisir(role);
  }

  /// Ferme la session : efface le jeton enregistré et revient à l'écran de connexion.
  Future<void> deconnecter() async {
    await ref.read(stockageSessionProvider).effacer();
    DemoTemps.reel = false;
    state = null;
    ref.read(modeDemoProvider.notifier).sortir();
    ref.read(roleProvider.notifier).reinitialiser();
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Utilisateur?>(
  SessionNotifier.new,
);

/// Profils de démonstration accessibles depuis l'écran de connexion (builds de développement seulement).
class ModeDemoNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void entrer() => state = true;
  void sortir() => state = false;
}

final modeDemoProvider = NotifierProvider<ModeDemoNotifier, bool>(
  ModeDemoNotifier.new,
);

/// Vrai juste après une connexion : l'application attend la fin du téléchargement des données avant de s'ouvrir,
/// même si une copie locale existe déjà. Au simple relancement de l'application (session enregistrée) ce n'est pas le
/// cas : elle s'ouvre tout de suite sur les données locales.
class AttenteConnexionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void demander() => state = true;
  void terminer() => state = false;
}

final attenteConnexionProvider =
    NotifierProvider<AttenteConnexionNotifier, bool>(
      AttenteConnexionNotifier.new,
    );
