/// Adresse de l'API du CRM. Se change à la compilation : `--dart-define=API_URL=http://192.168.x.x:4000`.
///
/// Par défaut : le serveur de staging, en HTTP sur le port 80 (donc sans port dans l'adresse). Android bloque le HTTP en
/// clair sauf pour ce domaine, autorisé dans `android/app/src/main/res/xml/network_security_config.xml` : une autre adresse
/// en HTTP ne fonctionne qu'en build debug.
abstract final class ConfigApi {
  static const url = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://staging.abcosmetique.com',
  );
}
