/// Adresse de l'API du CRM. Se change à la compilation : `--dart-define=API_URL=http://192.168.x.x:4000`.
///
/// Par défaut : l'API du serveur de staging, en HTTPS derrière le reverse proxy (sous-domaine dédié, sans port dans
/// l'adresse). Android bloque le HTTP en clair (`android/app/src/main/res/xml/network_security_config.xml`) : une adresse
/// en HTTP ne fonctionne qu'en build debug.
abstract final class ConfigApi {
  static const url = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api-staging.abcosmetique.com',
  );
}
