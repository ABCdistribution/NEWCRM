/// Configuration de l'application. Les valeurs se changent à la compilation :
/// `flutter run --dart-define=DEV=true` (serveur de dev) ou `--dart-define=API_URL=https://api.exemple.fr`
abstract final class AppConfig {
  /// Mode développement : `--dart-define=DEV=true`. L'API visée est alors le serveur de dev ([devApiUrl]).
  /// Désactivé d'office dans un build release (`dart.vm.product`). Ne donne aucun accès sans Active Directory.
  static const dev = bool.fromEnvironment('DEV') && !bool.fromEnvironment('dart.vm.product');

  /// API du serveur de développement (réseau interne).
  static const devApiUrl = 'http://192.168.10.139:4000';

  static const _apiUrlDefine = String.fromEnvironment('API_URL');

  /// Adresse de l'API : `API_URL` si fourni, sinon le serveur de dev quand `DEV=true`, sinon l'ordinateur hôte
  /// vu depuis l'émulateur Android.
  static const apiUrl = _apiUrlDefine != '' ? _apiUrlDefine : (dev ? devApiUrl : 'http://10.0.2.2:4000');

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
