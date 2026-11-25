import 'dart:io';

import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/envois_base.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:flutter_test/flutter_test.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

void main() {
  late Directory dossier;
  late File fichier;

  setUp(() {
    dossier = Directory.systemTemp.createTempSync('crm_migration_test_');
    fichier = File('${dossier.path}/crm.db');
  });

  tearDown(() => dossier.deleteSync(recursive: true));

  Future<int> versionSchema(AppDatabase base) async =>
      (await base.customSelect('PRAGMA user_version').getSingle()).read<int>(
        'user_version',
      );

  test('une base neuve est en version 7, avec la file d\'envoi', () async {
    final base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
    expect(await versionSchema(base), 7);
    expect(base.schemaVersion, 7);
    final e = await base.enfilerEnvoi(
      utilisateurId: 'u',
      type: TypeEnvoi.commande,
      cle: 'AbC123xYz9',
      payload: '{}',
    );
    expect(e.etat, EtatEnvoi.aEnvoyer);
    expect(e.essais, 0);
    await base.close();
  });

  test(
    'migration 6 → 7 : les données existantes sont gardées, la file est créée',
    () async {
      // Une base en version 6 : celle d'aujourd'hui sans les deux tables de la file.
      var base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
      await base.ajouterPhotoVisite('v218093', 'arrivee', [1, 2, 3]);
      await base.ecrireMeta('exemple', 'valeur');
      await base.customStatement('DROP TABLE envois_fichiers');
      await base.customStatement('DROP TABLE envois_en_attente');
      await base.customStatement('PRAGMA user_version = 6');
      await base.close();

      base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
      expect(await versionSchema(base), 7);
      expect(await base.meta('exemple'), 'valeur');
      final photos = await base.photosDeVisite('v218093');
      expect(photos, hasLength(1));
      expect(photos.single.octets, [1, 2, 3]);

      // Les tables existent et la file fonctionne, photos rattachées comprises.
      final e = await base.enfilerEnvoi(
        utilisateurId: 'u',
        type: TypeEnvoi.visite,
        cle: 'Vabc',
        payload: '{"idApk":"Vabc"}',
        refLocale: 'v218093',
        photosDe: 'v218093',
      );
      expect(e.etat, EtatEnvoi.aEnvoyer);
      expect(await base.fichiersDeEnvoi(e.id), hasLength(1));
      await base.close();

      // Relue après un redémarrage : la file est toujours là.
      base = await ouvrirBaseChiffree(fichier: fichier, cleHex: _cle);
      expect(await base.envoisDe('u'), hasLength(1));
      await base.close();
    },
  );
}
