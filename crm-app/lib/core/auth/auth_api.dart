import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../api/config_api.dart';
import '../api/erreur_api.dart';
import 'utilisateur.dart';

/// Connexion à l'API (abstraction : faux en test).
abstract interface class AuthApi {
  Future<ReponseConnexion> connecter(String identifiant, String motDePasse);
}

/// Connexion réelle : `POST /auth/login` (Active Directory), sans dépendance externe.
class AuthApiHttp implements AuthApi {
  AuthApiHttp({String? urlBase, HttpClient? client})
    : _urlBase = urlBase ?? ConfigApi.url,
      _client =
          client ??
          (HttpClient()..connectionTimeout = const Duration(seconds: 8));

  final String _urlBase;
  final HttpClient _client;

  /// L'annuaire peut être lent : on laisse 20 s à la réponse.
  static const delaiReponse = Duration(seconds: 20);

  @override
  Future<ReponseConnexion> connecter(
    String identifiant,
    String motDePasse,
  ) async {
    try {
      final requete = await _client.postUrl(Uri.parse('$_urlBase/auth/login'));
      requete.headers.contentType = ContentType.json;
      requete.add(
        utf8.encode(
          jsonEncode({'username': identifiant, 'password': motDePasse}),
        ),
      );
      final reponse = await requete.close().timeout(delaiReponse);
      final corps = await reponse
          .transform(utf8.decoder)
          .join()
          .timeout(delaiReponse);
      final statut = reponse.statusCode;
      if (statut == 200 || statut == 201) {
        final json = jsonDecode(corps);
        if (json is! Map<String, dynamic> ||
            json['accessToken'] is! String ||
            json['user'] is! Map<String, dynamic>) {
          throw const ErreurApi(TypeErreurApi.inattendue);
        }
        return ReponseConnexion(
          jeton: json['accessToken'] as String,
          utilisateur: Utilisateur.fromJson(
            json['user'] as Map<String, dynamic>,
          ),
        );
      }
      throw switch (statut) {
        400 || 401 => ErreurApi(TypeErreurApi.identifiants, statut: statut),
        403 => ErreurApi(TypeErreurApi.refuse, statut: statut),
        >= 500 => ErreurApi(TypeErreurApi.serveur, statut: statut),
        _ => ErreurApi(TypeErreurApi.inattendue, statut: statut),
      };
    } on ErreurApi {
      rethrow;
    } on FormatException {
      throw const ErreurApi(TypeErreurApi.inattendue);
    } on TimeoutException {
      throw const ErreurApi(TypeErreurApi.reseau);
    } on SocketException {
      throw const ErreurApi(TypeErreurApi.reseau);
    } on HttpException {
      throw const ErreurApi(TypeErreurApi.reseau);
    } on HandshakeException {
      throw const ErreurApi(TypeErreurApi.reseau);
    }
  }
}
