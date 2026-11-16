import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'cle_base.dart';

/// Nom du fichier de la base dans le dossier privé de l'application.
const nomFichierBase = 'crm.db';

/// Ouvre (et crée au premier lancement) la base locale chiffrée dans [fichier] avec la clé hexadécimale [cleHex].
///
/// Refuse de s'ouvrir si SQLCipher n'est pas réellement actif (jamais de base en clair par mégarde) ou si la clé
/// ne correspond pas à la base existante.
Future<AppDatabase> ouvrirBaseChiffree({
  required File fichier,
  required String cleHex,
}) async {
  await fichier.parent.create(recursive: true);
  final executor = NativeDatabase.createInBackground(
    fichier,
    setup: (raw) {
      if (raw.select('PRAGMA cipher_version;').isEmpty) {
        throw StateError(
          'SQLCipher indisponible : la base ne peut pas être chiffrée.',
        );
      }
      raw.execute("PRAGMA key = \"x'$cleHex'\";");
      raw.select(
        'SELECT count(*) FROM sqlite_master;',
      ); // échoue si la clé ne déchiffre pas la base
    },
  );
  final base = AppDatabase(executor);
  await base
      .customSelect('SELECT 1')
      .get(); // force l'ouverture et la création du schéma
  return base;
}

/// Ouvre la base locale de l'application : dossier privé de l'application, clé dans le coffre sécurisé.
Future<AppDatabase> ouvrirBaseLocale({
  StockageSecret stockage = const StockageSecretSysteme(),
}) async {
  final dossier = await getApplicationSupportDirectory();
  final cle = await CleBase(stockage).obtenir();
  return ouvrirBaseChiffree(
    fichier: File(p.join(dossier.path, nomFichierBase)),
    cleHex: cle,
  );
}
