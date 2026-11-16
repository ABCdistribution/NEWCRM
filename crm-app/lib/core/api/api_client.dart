import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'config_api.dart';
import 'erreur_api.dart';

/// Lecture authentifiée de l'API (abstraction : faux en test).
abstract interface class ApiLecture {
  /// `GET {chemin}?{query}` : renvoie le JSON décodé. Lève [ErreurApi].
  Future<Object?> get(String chemin, {Map<String, String>? query});
}

/// Téléchargement authentifié d'un fichier (photo de profil).
abstract interface class ApiOctets {
  /// `GET {chemin}` : octets de la réponse, ou null si le fichier n'existe pas (404). Lève [ErreurApi].
  Future<List<int>?> octets(String chemin);
}

/// Client HTTP de l'API du CRM : jeton en `Authorization: Bearer`, sans dépendance externe.
class ApiClient implements ApiLecture, ApiOctets {
  ApiClient({required this._jeton, String? urlBase, HttpClient? client})
    : _urlBase = urlBase ?? ConfigApi.url,
      _client =
          client ??
          (HttpClient()..connectionTimeout = const Duration(seconds: 8));

  final Future<String?> Function() _jeton;
  final String _urlBase;
  final HttpClient _client;

  static const delaiReponse = Duration(seconds: 30);

  static const _tailleMax = 2 * 1024 * 1024;

  @override
  Future<List<int>?> octets(String chemin) async {
    final jeton = await _jeton();
    if (jeton == null || jeton.isEmpty) {
      throw const ErreurApi(TypeErreurApi.sessionExpiree);
    }
    try {
      final requete = await _client.getUrl(Uri.parse('$_urlBase$chemin'));
      requete.headers.set(HttpHeaders.authorizationHeader, 'Bearer $jeton');
      final reponse = await requete.close().timeout(delaiReponse);
      final statut = reponse.statusCode;
      if (statut == 404) {
        await reponse.drain<void>();
        return null;
      }
      if (statut != 200) {
        await reponse.drain<void>();
        throw switch (statut) {
          401 => ErreurApi(TypeErreurApi.sessionExpiree, statut: statut),
          403 => ErreurApi(TypeErreurApi.refuse, statut: statut),
          >= 500 => ErreurApi(TypeErreurApi.serveur, statut: statut),
          _ => ErreurApi(TypeErreurApi.inattendue, statut: statut),
        };
      }
      final tampon = BytesBuilder(copy: false);
      await for (final morceau in reponse.timeout(delaiReponse)) {
        tampon.add(morceau);
        if (tampon.length > _tailleMax) {
          throw const ErreurApi(TypeErreurApi.inattendue);
        }
      }
      return tampon.takeBytes();
    } on ErreurApi {
      rethrow;
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

  @override
  Future<Object?> get(String chemin, {Map<String, String>? query}) async {
    final jeton = await _jeton();
    if (jeton == null || jeton.isEmpty) {
      throw const ErreurApi(TypeErreurApi.sessionExpiree);
    }
    final uri = Uri.parse('$_urlBase$chemin').replace(queryParameters: query);
    try {
      final requete = await _client.getUrl(uri);
      requete.headers.set(HttpHeaders.authorizationHeader, 'Bearer $jeton');
      requete.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final reponse = await requete.close().timeout(delaiReponse);
      final corps = await reponse
          .transform(utf8.decoder)
          .join()
          .timeout(delaiReponse);
      final statut = reponse.statusCode;
      if (statut == 200) return jsonDecode(corps);
      throw switch (statut) {
        401 => ErreurApi(TypeErreurApi.sessionExpiree, statut: statut),
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
