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

/// Écriture JSON authentifiée (abstraction : faux en test) : commandes, visites, propositions PEM, notifications.
abstract interface class ApiEcriture {
  /// `POST`, `PATCH` ou `DELETE` de `chemin` avec `corps` (JSON) : renvoie le JSON décodé de la réponse (null si elle
  /// est vide). Lève [ErreurApi], dont le message est celui de l'API quand elle en donne un.
  Future<Object?> envoyer(String methode, String chemin, {Object? corps});
}

/// Envoi authentifié d'un fichier (abstraction : faux en test) : les photos de visite, en `multipart/form-data`.
abstract interface class ApiFichiers {
  /// `POST {chemin}` : `octets` dans le champ `champ` (nom `nomFichier`, type `typeMime`) et les `champs` texte en plus.
  /// Renvoie le JSON décodé de la réponse (null si elle est vide). Lève [ErreurApi].
  Future<Object?> televerser(
    String chemin, {
    required String champ,
    required String nomFichier,
    required String typeMime,
    required List<int> octets,
    Map<String, String> champs = const {},
  });
}

/// Téléchargement authentifié d'un fichier (photo de profil).
abstract interface class ApiOctets {
  /// `GET {chemin}` : octets de la réponse, ou null si le fichier n'existe pas (404). Lève [ErreurApi].
  Future<List<int>?> octets(String chemin);
}

/// Client HTTP de l'API du CRM : jeton en `Authorization: Bearer`, sans dépendance externe.
class ApiClient implements ApiLecture, ApiOctets, ApiEcriture, ApiFichiers {
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
  Future<Object?> envoyer(String methode, String chemin, {Object? corps}) =>
      _ecrire(methode, chemin, (requete) {
        if (corps != null) {
          requete.headers.contentType = ContentType.json;
          requete.add(utf8.encode(jsonEncode(corps)));
        }
      });

  @override
  Future<Object?> televerser(
    String chemin, {
    required String champ,
    required String nomFichier,
    required String typeMime,
    required List<int> octets,
    Map<String, String> champs = const {},
  }) {
    final limite =
        'crm-${DateTime.now().microsecondsSinceEpoch}-${octets.length}';
    final corps = corpsMultipart(
      limite: limite,
      champ: champ,
      nomFichier: nomFichier,
      typeMime: typeMime,
      octets: octets,
      champs: champs,
    );
    return _ecrire('POST', chemin, (requete) {
      requete.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': limite},
      );
      requete.contentLength = corps.length;
      requete.add(corps);
    });
  }

  /// Appel d'écriture : `remplir` pose l'en-tête et le corps ; le JSON de la réponse est décodé, une réponse d'erreur
  /// devient une [ErreurApi] (message de l'API gardé).
  Future<Object?> _ecrire(
    String methode,
    String chemin,
    void Function(HttpClientRequest requete) remplir,
  ) async {
    final jeton = await _jeton();
    if (jeton == null || jeton.isEmpty) {
      throw const ErreurApi(TypeErreurApi.sessionExpiree);
    }
    try {
      final requete = await _client.openUrl(
        methode,
        Uri.parse('$_urlBase$chemin'),
      );
      requete.headers.set(HttpHeaders.authorizationHeader, 'Bearer $jeton');
      requete.headers.set(HttpHeaders.acceptHeader, 'application/json');
      remplir(requete);
      final reponse = await requete.close().timeout(delaiReponse);
      final texte = await reponse
          .transform(utf8.decoder)
          .join()
          .timeout(delaiReponse);
      final statut = reponse.statusCode;
      if (statut >= 200 && statut < 300) {
        return texte.trim().isEmpty ? null : jsonDecode(texte);
      }
      throw ErreurApi.depuisReponse(statut, texte);
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

/// Corps `multipart/form-data` : les champs texte, puis le fichier.
List<int> corpsMultipart({
  required String limite,
  required String champ,
  required String nomFichier,
  required String typeMime,
  required List<int> octets,
  Map<String, String> champs = const {},
}) {
  String protege(String v) =>
      v.replaceAll('"', '').replaceAll(RegExp(r'[\r\n]'), ' ');
  final corps = BytesBuilder(copy: false);
  for (final e in champs.entries) {
    corps.add(
      utf8.encode(
        '--$limite\r\n'
        'Content-Disposition: form-data; name="${protege(e.key)}"\r\n\r\n'
        '${e.value}\r\n',
      ),
    );
  }
  corps
    ..add(
      utf8.encode(
        '--$limite\r\n'
        'Content-Disposition: form-data; name="${protege(champ)}"; '
        'filename="${protege(nomFichier)}"\r\n'
        'Content-Type: $typeMime\r\n\r\n',
      ),
    )
    ..add(octets)
    ..add(utf8.encode('\r\n--$limite--\r\n'));
  return corps.takeBytes();
}
