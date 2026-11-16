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
  const ErreurApi(this.type, {this.statut});

  final TypeErreurApi type;
  final int? statut;

  String get message => switch (type) {
    TypeErreurApi.identifiants => 'Identifiant ou mot de passe incorrect.',
    TypeErreurApi.refuse => "Ce compte n'a pas accès à l'application mobile.",
    TypeErreurApi.reseau => 'Serveur injoignable. Vérifiez votre connexion.',
    TypeErreurApi.serveur =>
      'Le serveur ne répond pas correctement. Réessayez plus tard.',
    TypeErreurApi.sessionExpiree => 'Session expirée. Reconnectez-vous.',
    TypeErreurApi.inattendue => 'Réponse inattendue du serveur.',
  };

  @override
  String toString() => 'ErreurApi($type, $statut)';
}
