import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage d'un secret (abstraction pour les tests ; en production : coffre sécurisé Android).
abstract interface class StockageSecret {
  Future<String?> lire(String nom);
  Future<void> ecrire(String nom, String valeur);
}

/// Implémentation de production : `flutter_secure_storage` (Android Keystore).
class StockageSecretSysteme implements StockageSecret {
  const StockageSecretSysteme([this._stockage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _stockage;

  @override
  Future<String?> lire(String nom) => _stockage.read(key: nom);

  @override
  Future<void> ecrire(String nom, String valeur) =>
      _stockage.write(key: nom, value: valeur);
}

/// Clé de chiffrement de la base locale : 32 octets aléatoires créés au premier lancement, gardés dans le coffre
/// sécurisé de l'appareil, jamais dans un fichier ni dans les préférences.
class CleBase {
  const CleBase(this._stockage);

  final StockageSecret _stockage;

  static const nomSecret = 'crm_base_locale_cle';

  /// Clé en hexadécimal (64 caractères) ; la crée si elle n'existe pas encore.
  Future<String> obtenir() async {
    final existante = await _stockage.lire(nomSecret);
    if (existante != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(existante)) {
      return existante;
    }
    final alea = Random.secure();
    final cle = List.generate(
      32,
      (_) => alea.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _stockage.ecrire(nomSecret, cle);
    return cle;
  }
}
