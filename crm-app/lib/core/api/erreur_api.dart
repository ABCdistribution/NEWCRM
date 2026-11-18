import 'dart:convert';

/// Nature d'un échec d'appel à l'API.
enum TypeErreurApi {
  /// Identifiant ou mot de passe refusé (400 / 401).
  identifiants,

  /// Compte reconnu mais sans accès (403, ou rôle sans profil mobile).
  refuse,

  /// Serveur injoignable, délai dépassé ou connexion coupée.
  reseau,

  /// Le serveur répond par une erreur (5xx).
  serveur,

  /// Jeton refusé ou expiré (401 sur un appel authentifié) : il faut se reconnecter.
  sessionExpiree,

  /// Réponse inattendue.
  inattendue,
}

/// Échec d'un appel à l'API, avec un message prêt à afficher (français).
class ErreurApi implements Exception {
  const ErreurApi(this.type, {this.statut, this.detail});

  /// Erreur d'une écriture (`POST`, `PATCH`, `DELETE`) : le message en français de l'API (`message` du corps JSON)
  /// est gardé tel quel quand il existe.
  factory ErreurApi.depuisReponse(int statut, String corps) {
    final detail = _messageApi(corps);
    return switch (statut) {
      401 => ErreurApi(TypeErreurApi.sessionExpiree, statut: statut),
      403 => ErreurApi(TypeErreurApi.refuse, statut: statut, detail: detail),
      >= 500 => ErreurApi(
        TypeErreurApi.serveur,
        statut: statut,
        detail: statut == 502 || statut == 503 ? detail : null,
      ),
      _ => ErreurApi(TypeErreurApi.inattendue, statut: statut, detail: detail),
    };
  }

  final TypeErreurApi type;
  final int? statut;

  /// Message de l'API à afficher à la place du message générique du type.
  final String? detail;

  String get message =>
      detail ??
      switch (type) {
        TypeErreurApi.identifiants => 'Identifiant ou mot de passe incorrect.',
        TypeErreurApi.refuse =>
          "Ce compte n'a pas accès à l'application mobile.",
        TypeErreurApi.reseau =>
          'Serveur injoignable. Vérifiez votre connexion.',
        TypeErreurApi.serveur =>
          'Le serveur ne répond pas correctement. Réessayez plus tard.',
        TypeErreurApi.sessionExpiree => 'Session expirée. Reconnectez-vous.',
        TypeErreurApi.inattendue => 'Réponse inattendue du serveur.',
      };

  @override
  String toString() => 'ErreurApi($type, $statut)';
}

/// `message` d'une réponse d'erreur NestJS (`{statusCode, message: texte ou liste, error}`), ou null.
String? _messageApi(String corps) {
  try {
    final j = jsonDecode(corps);
    final m = j is Map ? j['message'] : null;
    final texte = m is List ? m.whereType<String>().join(' ') : m;
    return texte is String && texte.trim().isNotEmpty ? texte.trim() : null;
  } catch (_) {
    return null;
  }
}
