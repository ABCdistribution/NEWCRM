import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'role.dart';

/// Utilisateur connecté, tel que renvoyé par `POST /auth/login`.
class SessionUser {
  const SessionUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.email,
  });

  final String id;
  final String username;
  final String displayName;
  final String? email;
  final Role role;

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        id: j['id'] as String,
        username: j['username'] as String,
        displayName: (j['displayName'] as String?) ?? (j['username'] as String),
        email: j['email'] as String?,
        role: Role.fromApi(j['role'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'email': email,
        'role': role.api,
      };
}

/// Session locale : jeton + utilisateur + date de dernière authentification réussie.
class Session {
  const Session({required this.token, required this.user, required this.authenticatedAt});

  final String token;
  final SessionUser user;
  final DateTime authenticatedAt;

  /// La lecture hors ligne reste autorisée pendant [window] après la dernière authentification (CDC §6.2).
  bool isWithinOfflineWindow(DateTime now, Duration window) => now.difference(authenticatedAt) <= window;

  Map<String, dynamic> toJson() => {
        'token': token,
        'user': user.toJson(),
        'authenticatedAt': authenticatedAt.toIso8601String(),
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        token: j['token'] as String,
        user: SessionUser.fromJson(j['user'] as Map<String, dynamic>),
        authenticatedAt: DateTime.parse(j['authenticatedAt'] as String),
      );
}

/// Stockage de la session. Le jeton n'est jamais écrit en clair : espace sécurisé du système (Keystore).
abstract class SessionStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();

  /// Identifiant propre à cette installation (supervision des téléphones, CDC §5).
  Future<String> installId();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;
  static const _kSession = 'session';
  static const _kInstall = 'install_id';

  @override
  Future<Session?> read() async {
    final raw = await _s.read(key: _kSession);
    if (raw == null) return null;
    try {
      return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await clear(); // contenu illisible : on repart propre plutôt que de planter au démarrage
      return null;
    }
  }

  @override
  Future<void> write(Session session) => _s.write(key: _kSession, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _s.delete(key: _kSession);

  @override
  Future<String> installId() async {
    final existing = await _s.read(key: _kInstall);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _s.write(key: _kInstall, value: id);
    return id;
  }
}
