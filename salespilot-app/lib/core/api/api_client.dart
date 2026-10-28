import 'package:dio/dio.dart';

import '../config.dart';

/// Crée le client HTTP : jeton, version de l'application et identifiant d'installation sur chaque requête.
/// [onUnauthorized] est appelé sur un 401 d'une route protégée (session expirée).
Dio buildDio({
  required String? Function() token,
  required Future<String> Function() installId,
  required void Function() onUnauthorized,
  String? baseUrl,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 60), // envoi des photos
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final t = token();
        if (t != null) options.headers['Authorization'] = 'Bearer $t';
        options.headers['x-app-version'] = AppConfig.appVersion;
        options.headers['x-install-id'] = await installId();
        handler.next(options);
      },
      onError: (e, handler) {
        // Un 401 sur le login lui-même est un mauvais mot de passe, pas une session expirée.
        if (e.response?.statusCode == 401 && !e.requestOptions.path.endsWith('/auth/login')) {
          onUnauthorized();
        }
        handler.next(e);
      },
    ),
  );
  return dio;
}

/// Message d'erreur lisible, en français, pour l'utilisateur.
String errorMessage(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List && m.isNotEmpty ? m.first.toString() : m.toString();
    }
    if (status == null) return 'Réseau indisponible. Vos saisies sont conservées sur le téléphone.';
    if (status == 401) return 'Identifiants invalides ou session expirée.';
    if (status == 503) return 'Annuaire Active Directory injoignable. Réessayez plus tard.';
    if (status >= 500) return 'Le serveur rencontre un problème ($status). Réessayez plus tard.';
    return 'Erreur ($status).';
  }
  return error.toString();
}
