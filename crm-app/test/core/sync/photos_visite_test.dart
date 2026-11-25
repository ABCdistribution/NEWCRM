import 'dart:io';

import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/sync/photos_visite_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

void main() {
  late Directory dossier;
  late AppDatabase base;

  setUp(() async {
    dossier = Directory.systemTemp.createTempSync('crm_photos_visite_test_');
    base = await ouvrirBaseChiffree(
      fichier: File('${dossier.path}/crm.db'),
      cleHex: _cle,
    );
  });

  tearDown(() async {
    await base.close();
    dossier.deleteSync(recursive: true);
  });

  ProviderContainer conteneur({bool avecBase = true}) {
    final c = ProviderContainer(
      overrides: [if (avecBase) baseLocaleProvider.overrideWithValue(base)],
    );
    addTearDown(c.dispose);
    c.listen(photosVisiteProvider('v1'), (_, _) {});
    return c;
  }

  group('une seule photo par étape', () {
    test('reprendre remplace l\'ancienne photo de l\'étape', () async {
      final c = conteneur();
      final n = c.read(photosVisiteProvider('v1').notifier);
      expect(await n.remplacer('arrivee', [1, 1]), isTrue);
      expect(await n.remplacer('arrivee', [2, 2]), isTrue);
      final photos = c.read(photosVisiteProvider('v1'));
      expect(photos, hasLength(1));
      expect(photos.single.etape, 'arrivee');
      expect(photos.single.octets, [2, 2]);
      expect(await base.photosDeVisite('v1'), hasLength(1));
    });

    test('les étapes et les visites sont indépendantes', () async {
      final c = conteneur();
      final n = c.read(photosVisiteProvider('v1').notifier);
      await n.remplacer('arrivee', [1]);
      await n.remplacer('rayonArrivee', [2]);
      await n.remplacer('arrivee', [3]);
      await base.ajouterPhotoVisite('v2', 'arrivee', [9]);
      final photos = c.read(photosVisiteProvider('v1'));
      expect(photos.map((p) => (p.etape, p.octets.first)).toSet(), {
        ('arrivee', 3),
        ('rayonArrivee', 2),
      });
      expect(await base.photosDeVisite('v2'), hasLength(1));
    });

    test('supprimer remet l\'étape à zéro photo', () async {
      final c = conteneur();
      final n = c.read(photosVisiteProvider('v1').notifier);
      await n.remplacer('arrivee', [1]);
      await n.remplacer('rayonArrivee', [2]);
      await n.supprimer('arrivee');
      expect(c.read(photosVisiteProvider('v1')).map((p) => p.etape), [
        'rayonArrivee',
      ]);
    });

    test(
      'supprimer efface aussi les doublons d\'un ancien brouillon',
      () async {
        await base.ajouterPhotoVisite('v1', 'arrivee', [1]);
        await base.ajouterPhotoVisite('v1', 'arrivee', [2]);
        final c = conteneur();
        await c.read(photosVisiteProvider('v1').notifier).supprimer('arrivee');
        expect(await base.photosDeVisite('v1'), isEmpty);
      },
    );

    test(
      'reprendre nettoie aussi les doublons d\'un ancien brouillon',
      () async {
        await base.ajouterPhotoVisite('v1', 'arrivee', [1]);
        await base.ajouterPhotoVisite('v1', 'arrivee', [2]);
        final c = conteneur();
        await c.read(photosVisiteProvider('v1').notifier).remplacer('arrivee', [
          3,
        ]);
        final lignes = await base.photosDeVisite('v1');
        expect(lignes, hasLength(1));
        expect(lignes.single.octets, [3]);
      },
    );

    test('sans base locale : rien n\'est enregistré', () async {
      final c = conteneur(avecBase: false);
      expect(
        await c.read(photosVisiteProvider('v1').notifier).remplacer('arrivee', [
          1,
        ]),
        isFalse,
      );
    });
  });
}
