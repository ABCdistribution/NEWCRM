/// Configuration de l'application. Les valeurs se changent à la compilation :
/// `flutter run --dart-define=API_URL=https://api.exemple.fr`
abstract final class AppConfig {
  /// Adresse de l'API. Par défaut : l'ordinateur hôte vu depuis l'émulateur Android.
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000');

  /// Connexion de développement sans Active Directory : `--dart-define=DEV_LOGIN=true`. Désactivée d'office dans
  /// un build release (`dart.vm.product`) : elle ne peut pas partir en production. Aucun jeton réel n'est
  /// obtenu, donc les appels à l'API échouent en 401 (ignorés) ; seule l'interface est utilisable.
  static const devLogin = bool.fromEnvironment('DEV_LOGIN') && !bool.fromEnvironment('dart.vm.product');
  static const devToken = 'dev-login-sans-ad';

  /// Version de l'application, envoyée à chaque requête (supervision, version minimale — CDC §5 et §6.5).
  static const appVersion = '0.1.0';

  /// Durée pendant laquelle la lecture hors ligne reste possible après la dernière authentification
  /// réussie (CDC §6.2, proposition à valider). Au-delà, reconnexion obligatoire.
  static const offlineReadWindow = Duration(hours: 72);

  /// Seuils de la pastille d'éléments en attente (CDC §4.3).
  static const pendingWarnAfter = Duration(hours: 24);
  static const pendingAlertAfter = Duration(hours: 48);

  /// Un brouillon plus ancien que ce délai est signalé (CDC §3.4).
  static const staleDraftAfter = Duration(days: 7);
}
