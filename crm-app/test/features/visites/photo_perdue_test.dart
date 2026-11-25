import 'dart:io';

import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/photos_visite_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

class _Captureur implements CaptureurPhoto {
  _Captureur({this.perdue});
  List<int>? perdue;

  @override
  Future<List<int>?> prendre() async => null;

  @override
  Future<List<int>?> retrouverPerdue() async {
    final r = perdue;
    perdue = null;
    return r;
  }
}

void main() {
  late Directory dossier;
  late AppDatabase base;

  setUp(() async {
    dossier = Directory.systemTemp.createTempSync('crm_photo_perdue_test_');
    base = await ouvrirBaseChiffree(
      fichier: File('${dossier.path}/crm.db'),
      cleHex: _cle,
    );
  });

  tearDown(() async {
    await base.close();
    dossier.deleteSync(recursive: true);
  });

  RecuperationPhoto recuperation(_Captureur c) {
    final conteneur = ProviderContainer(
      overrides: [
        baseLocaleProvider.overrideWithValue(base),
        captureurPhotoProvider.overrideWithValue(c),
      ],
    );
    addTearDown(conteneur.dispose);
    return conteneur.read(recuperationPhotoProvider);
  }

  group('intention « photo en cours »', () {
    test('mémorisée, relue, effacée', () async {
      expect(await base.photoEnCours(), isNull);
      await base.memoriserPhotoEnCours('v1', 'rayonFin');
      final i = await base.photoEnCours();
      expect(i?.visiteId, 'v1');
      expect(i?.etape, 'rayonFin');
      await base.effacerPhotoEnCours();
      expect(await base.photoEnCours(), isNull);
    });

    test('la dernière prise remplace la précédente', () async {
      await base.memoriserPhotoEnCours('v1', 'arrivee');
      await base.memoriserPhotoEnCours('v2', 'rayonArrivee');
      expect((await base.photoEnCours())?.visiteId, 'v2');
    });
  });

  group('photo retrouvée après la fermeture d\'Android', () {
    test('rattachée à l\'étape mémorisée, pas à une autre', () async {
      await base.memoriserPhotoEnCours('v1', 'rayonFin');
      final r = await recuperation(
        _Captureur(perdue: [7, 7]),
      ).recuperer(visiteExiste: (id) => id == 'v1');
      expect(r?.visiteId, 'v1');
      expect(r?.etape, EtapeDph.rayonFin);
      expect(r?.message, isNull);
      final lignes = await base.photosDeVisite('v1');
      expect(lignes.map((p) => '${p.etape}:${p.octets.toList()}'), [
        'rayonFin:[7, 7]',
      ]);
      expect(await base.photoEnCours(), isNull);
    });

    test('ne remplace que la photo de l\'étape mémorisée', () async {
      await base.ajouterPhotoVisite('v1', 'arrivee', [1]);
      await base.ajouterPhotoVisite('v1', 'rayonFin', [2]);
      await base.memoriserPhotoEnCours('v1', 'rayonFin');
      await recuperation(
        _Captureur(perdue: [9]),
      ).recuperer(visiteExiste: (_) => true);
      final lignes = await base.photosDeVisite('v1');
      expect(lignes.map((p) => '${p.etape}:${p.octets.toList()}').toSet(), {
        'arrivee:[1]',
        'rayonFin:[9]',
      });
    });

    test(
      'visite introuvable : rien rattaché, message, intention effacée',
      () async {
        await base.memoriserPhotoEnCours('v1', 'arrivee');
        final r = await recuperation(
          _Captureur(perdue: [1]),
        ).recuperer(visiteExiste: (_) => false);
        expect(r?.visiteId, isNull);
        expect(r?.message, isNotEmpty);
        expect(await base.photosDeVisite('v1'), isEmpty);
        expect(await base.photoEnCours(), isNull);
      },
    );

    test('intention disparue : rien rattaché, message', () async {
      final r = await recuperation(
        _Captureur(perdue: [1]),
      ).recuperer(visiteExiste: (_) => true);
      expect(r?.message, isNotEmpty);
      expect(await base.photosDeVisite('v1'), isEmpty);
    });

    test('étape qui n\'est pas une photo : rien rattaché', () async {
      await base.memoriserPhotoEnCours('v1', 'colis');
      final r = await recuperation(
        _Captureur(perdue: [1]),
      ).recuperer(visiteExiste: (_) => true);
      expect(r?.message, isNotEmpty);
      expect(await base.photosDeVisite('v1'), isEmpty);
    });

    test('aucune photo retrouvée : l\'intention périmée est effacée', () async {
      await base.memoriserPhotoEnCours('v1', 'arrivee');
      final r = await recuperation(
        _Captureur(),
      ).recuperer(visiteExiste: (_) => true);
      expect(r, isNull);
      expect(await base.photoEnCours(), isNull);
    });
  });
}
