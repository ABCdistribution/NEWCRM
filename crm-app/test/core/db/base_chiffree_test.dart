import 'dart:io';

import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/cle_base.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _StockageMemoire implements StockageSecret {
  final Map<String, String> valeurs = {};

  @override
  Future<String?> lire(String nom) async => valeurs[nom];

  @override
  Future<void> ecrire(String nom, String valeur) async => valeurs[nom] = valeur;
}

void main() {
  late Directory dossier;
  late File fichier;
  const cle =
      '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

  setUp(() {
    dossier = Directory.systemTemp.createTempSync('crm_base_test_');
    fichier = File('${dossier.path}/crm.db');
  });

  tearDown(() => dossier.deleteSync(recursive: true));

  test(
    'la base est créée avec sa date de création et survit à une réouverture',
    () async {
      final base = await ouvrirBaseChiffree(fichier: fichier, cleHex: cle);
      final creeeLe = await base.meta(AppDatabase.cleCreeeLe);
      expect(creeeLe, isNotNull);
      await base.ecrireMeta('exemple', 'valeur');
      await base.close();

      final rouverte = await ouvrirBaseChiffree(fichier: fichier, cleHex: cle);
      expect(await rouverte.meta('exemple'), 'valeur');
      expect(
        await rouverte.meta(AppDatabase.cleCreeeLe),
        creeeLe,
      ); // pas recréée
      await rouverte.close();
    },
  );

  test(
    "le fichier est réellement chiffré : pas d'en-tête SQLite, aucune donnée lisible",
    () async {
      final base = await ouvrirBaseChiffree(fichier: fichier, cleHex: cle);
      await base.ecrireMeta('secret', 'texte-tres-reconnaissable-12345');
      await base.close();

      final octets = fichier.readAsBytesSync();
      expect(octets.length, greaterThan(1000));
      expect(String.fromCharCodes(octets.take(15)), isNot('SQLite format 3'));
      expect(
        String.fromCharCodes(octets),
        isNot(contains('texte-tres-reconnaissable-12345')),
      );
    },
  );

  test("une mauvaise clé n'ouvre pas la base", () async {
    final base = await ouvrirBaseChiffree(fichier: fichier, cleHex: cle);
    await base.close();
    const autreCle =
        'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';
    await expectLater(
      ouvrirBaseChiffree(fichier: fichier, cleHex: autreCle),
      throwsA(anything),
    );
  });

  test(
    'la clé est créée une seule fois (64 hexadécimaux) puis relue à l\'identique',
    () async {
      final stockage = _StockageMemoire();
      final premiere = await CleBase(stockage).obtenir();
      expect(premiere, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(await CleBase(stockage).obtenir(), premiere);
      final autre = await CleBase(_StockageMemoire()).obtenir();
      expect(autre, isNot(premiere));
    },
  );
}
