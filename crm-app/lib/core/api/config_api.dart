/// Adresse de l'API du CRM. Se change à la compilation : `--dart-define=API_URL=http://192.168.x.x:4000`.
///
/// Par défaut : serveur de développement interne (HTTP, réseau de l'entreprise). Un build release exige HTTPS
/// (Android bloque le HTTP en clair) : l'adresse de production sera fournie par `API_URL`.
abstract final class ConfigApi {
  static const url = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.10.139:4000',
  );
}
