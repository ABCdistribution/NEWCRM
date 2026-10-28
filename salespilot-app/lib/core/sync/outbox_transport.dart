import 'dart:convert';

import 'package:dio/dio.dart';

import '../db/app_database.dart';

/// Résultat d'une tentative d'envoi d'un élément de la file.
sealed class SendResult {
  const SendResult();
}

/// Reçu et confirmé par le serveur (y compris « déjà synchronisé » : un doublon reconnu est un succès).
class Sent extends SendResult {
  const Sent({this.serverId});
  final String? serverId;
}

/// Échec temporaire (réseau, serveur indisponible) : on réessaiera plus tard.
class RetryLater extends SendResult {
  const RetryLater(this.reason);
  final String reason;
}

/// Refus définitif du serveur : l'élément reste en erreur avec ce motif.
class Rejected extends SendResult {
  const Rejected(this.reason);
  final String reason;
}

/// Session expirée : l'envoi s'arrête sans rien perdre, il reprendra après reconnexion.
class Unauthorized extends SendResult {
  const Unauthorized();
}

/// Envoie un élément de la file. Séparé du moteur pour être remplaçable dans les tests.
abstract class OutboxTransport {
  /// [parentServerId] : identifiant serveur du parent, requis pour les éléments dépendants (photo).
  Future<SendResult> send(OutboxItem item, {String? parentServerId});
}

/// Types d'éléments de la file.
abstract final class OutboxKind {
  static const visite = 'visite';
  static const visiteCommerciale = 'visite_commerciale';
  static const photo = 'photo';
  static const commande = 'commande';
  static const note = 'note';
}

/// Transport réel : traduit chaque type d'élément en requête vers l'API et classe les erreurs.
class HttpOutboxTransport implements OutboxTransport {
  HttpOutboxTransport(this._dio);

  final Dio _dio;

  @override
  Future<SendResult> send(OutboxItem item, {String? parentServerId}) async {
    try {
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;
      final Response<dynamic> res;
      switch (item.kind) {
        case OutboxKind.visite:
          res = await _dio.post('/visites', data: payload);
        case OutboxKind.visiteCommerciale:
          final clientId = payload['clientId'] as String;
          res = await _dio.post('/clients/$clientId/visites-commerciales', data: payload..remove('clientId'));
        case OutboxKind.commande:
          res = await _dio.post('/commandes/apk', data: payload);
        case OutboxKind.note:
          final clientId = payload['clientId'] as String;
          res = await _dio.post('/clients/$clientId/notes', data: payload..remove('clientId'));
        case OutboxKind.photo:
          if (parentServerId == null || item.filePath == null) {
            return const Rejected('Photo sans visite confirmée ou sans fichier local.');
          }
          final form = FormData.fromMap({
            'idApk': item.idApk,
            'photo': await MultipartFile.fromFile(item.filePath!, filename: '${item.idApk}.jpg'),
          });
          res = await _dio.post('/visites/$parentServerId/photos', data: form);
        default:
          return Rejected('Type d\'envoi inconnu : ${item.kind}');
      }
      final body = res.data;
      final id = body is Map ? body['id']?.toString() : null;
      return Sent(serverId: id);
    } on DioException catch (e) {
      return classify(e);
    } on Object catch (e) {
      // Erreur locale imprévue (fichier absent, JSON invalide) : réessayer ne changera rien.
      return Rejected('Erreur locale : $e');
    }
  }

  /// Classe une erreur HTTP. Public pour être testé.
  static SendResult classify(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) return RetryLater(e.message ?? 'Réseau indisponible'); // coupure, délai dépassé
    if (status == 401) return const Unauthorized();
    if (status == 408 || status == 425 || status == 429 || status >= 500) {
      return RetryLater('Serveur indisponible ($status)');
    }
    return Rejected(_message(e.response?.data) ?? 'Refusé par le serveur ($status)');
  }

  static String? _message(Object? data) {
    if (data is Map) {
      final m = data['message'];
      if (m is List && m.isNotEmpty) return m.first.toString();
      if (m != null) return m.toString();
    }
    return null;
  }
}
