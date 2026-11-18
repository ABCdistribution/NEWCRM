import '../models/models.dart';

/// Activité du mois du promoteur connecté (`GET /performances/me`).
class PerformanceMoi {
  const PerformanceMoi({
    required this.ca,
    required this.cible,
    required this.visites,
    required this.commandes,
  });

  final double ca;

  /// Objectif mensuel en euros, 0 si le CRM n'en a pas pour ce portefeuille.
  final double cible;
  final int visites;
  final int commandes;
}

PerformanceMoi? _performance;

void definirPerformanceServeur(PerformanceMoi? p) => _performance = p;

PerformanceMoi? performanceServeur() => _performance;

double _nombre(Object? v) => v is num ? v.toDouble() : 0;

/// Performances à partir de la réponse de l'API ; nulle si le compte n'a pas de code représentant.
PerformanceMoi? performanceDepuisJson(Map<String, dynamic> j) {
  if (j['noRepr'] == true) return null;
  final kpis = j['kpis'];
  final objectif = j['objectif'];
  if (kpis is! Map<String, dynamic>) return null;
  return PerformanceMoi(
    ca: _nombre(kpis['ca']),
    cible: objectif is Map ? _nombre(objectif['cible']) : 0,
    visites: _nombre(kpis['visites']).toInt(),
    commandes: _nombre(kpis['commandes']).toInt(),
  );
}

List<Alerte>? _notifications;

/// Notifications non lues du CRM, présentées comme des alertes (nul en démonstration).
void definirNotificationsServeur(List<Alerte>? l) => _notifications = l;

List<Alerte> notificationsServeur() => _notifications ?? const [];

/// Alerte à partir d'une notification de l'API (`GET /notifications/me`) ; null si déjà lue ou sans titre.
Alerte? alerteDepuisNotification(Map<String, dynamic> j) {
  if (j['luAt'] != null) return null;
  final titre = j['titre'];
  if (titre is! String || titre.trim().isEmpty) return null;
  final message = j['message'];
  final emetteur = j['emetteur'];
  final de = emetteur is Map && emetteur['displayName'] is String
      ? '${emetteur['displayName']} · '
      : '';
  return Alerte(
    niveau: NiveauAlerte.haut,
    icone: '💬',
    titre: titre.trim(),
    classe: '',
    detail: '$de${message is String ? message.trim() : ''}',
    rang: 5,
  );
}
