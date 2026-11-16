import '../models/models.dart';

/// Utilisateur connecté (réponse de `POST /auth/login`).
class Utilisateur {
  const Utilisateur({
    required this.id,
    required this.identifiant,
    required this.nomAffiche,
    required this.email,
    required this.roleApi,
  });

  final String id;
  final String identifiant;

  /// Nom complet venu de l'Active Directory (`displayName`).
  final String nomAffiche;
  final String? email;

  /// Rôle côté API : COMMERCIAL, CHEF_SECTEUR, DIRECTEUR_REGIONAL, DIRECTION, ADMIN, ADV, MARKETING.
  final String roleApi;

  factory Utilisateur.fromJson(Map<String, dynamic> j) => Utilisateur(
    id: '${j['id']}',
    identifiant: '${j['username'] ?? ''}',
    nomAffiche: '${j['displayName'] ?? j['username'] ?? ''}'.trim(),
    email: j['email'] as String?,
    roleApi: '${j['role']}',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': identifiant,
    'displayName': nomAffiche,
    'email': email,
    'role': roleApi,
  };

  /// Profil mobile correspondant au rôle de l'API, ou null si ce rôle n'a pas d'accès mobile.
  /// Promoteur = COMMERCIAL ; ADMIN et DIRECTION ont la vue du directeur ; ADV et MARKETING : pas d'accès.
  Role? get role => switch (roleApi) {
    'COMMERCIAL' => Role.promoteur,
    'CHEF_SECTEUR' => Role.cs,
    'DIRECTEUR_REGIONAL' || 'DIRECTION' || 'ADMIN' => Role.dir,
    _ => null,
  };

  List<String> get _mots =>
      nomAffiche.split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();

  /// Prénom pour « Bonjour … » : premier mot qui n'est pas entièrement en majuscules (l'AD écrit « NOM Prénom »
  /// ou « Prénom NOM »), sinon le premier mot.
  String get prenom {
    final mots = _mots;
    if (mots.isEmpty) return identifiant;
    return mots.firstWhere(
      (m) => m != m.toUpperCase(),
      orElse: () => mots.first,
    );
  }

  /// Deux initiales (premiers caractères des deux premiers mots).
  String get initiales {
    final mots = _mots;
    if (mots.isEmpty) {
      return identifiant.isEmpty ? '?' : identifiant[0].toUpperCase();
    }
    return mots.take(2).map((m) => m[0].toUpperCase()).join();
  }
}

/// Réponse de `POST /auth/login`.
class ReponseConnexion {
  const ReponseConnexion({required this.jeton, required this.utilisateur});

  final String jeton;
  final Utilisateur utilisateur;
}
