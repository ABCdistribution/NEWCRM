import 'dart:io';

import 'package:crm_app/core/db/app_database.dart';
import 'package:crm_app/core/db/base_provider.dart';
import 'package:crm_app/core/db/ouverture_base.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/photos_visite_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_visites.dart';
import 'visite_etapes_test.dart' show fermerKilometrage, suivant, visite;

const _cle = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

/// Appareil photo factice : chaque prise dépile une réponse (octets, null = annulée, ou une erreur).
class _CaptureurFactice implements CaptureurPhoto {
  final List<Object?> prises = [];
  List<int>? perdue;

  @override
  Future<List<int>?> prendre() async {
    final r = prises.removeAt(0);
    if (r is Exception) throw r;
    return r as List<int>?;
  }

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
  late _CaptureurFactice appareil;

  /// Laisse la base (vrai temps) avancer, en faisant tourner la zone simulée du test.
  Future<void> attendreBase(WidgetTester tester, [int fois = 8]) async {
    for (var i = 0; i < fois; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<List<PhotoVisiteLocale>> photosEnBase(
    WidgetTester tester,
    String id,
  ) async => (await tester.runAsync(() => base.photosDeVisite(id)))!;

  Future<String> ouvrir(
    WidgetTester tester, {
    Future<void> Function(AppDatabase base, _CaptureurFactice appareil)? avant,
  }) async {
    await tester.runAsync(() async {
      dossier = Directory.systemTemp.createTempSync('crm_photo_unique_test_');
      base = await ouvrirBaseChiffree(
        fichier: File('${dossier.path}/crm.db'),
        cleHex: _cle,
      );
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await base.close();
        dossier.deleteSync(recursive: true);
      });
    });
    appareil = _CaptureurFactice();
    if (avant != null) await tester.runAsync(() => avant(base, appareil));
    final id = await demarrerVisiteChez(
      tester,
      Role.promoteur,
      'm1',
      overrides: [
        baseLocaleProvider.overrideWithValue(base),
        captureurPhotoProvider.overrideWithValue(appareil),
      ],
    );
    await fermerKilometrage(tester);
    return id;
  }

  Future<void> toucherPhoto(WidgetTester tester, String libelle) async {
    await tester.tap(find.text(libelle));
    await tester.pump();
    await attendreBase(tester);
    await tester.pumpAndSettle();
  }

  group('une seule photo par étape', () {
    testWidgets('prendre puis reprendre : une photo, le compteur reste à 1', (
      tester,
    ) async {
      final id = await ouvrir(tester);
      appareil.prises.addAll([
        [0xFF, 0xD8, 1],
        [0xFF, 0xD8, 2],
      ]);

      await toucherPhoto(tester, '📷 Prendre une photo');
      expect(visite(tester, id).photos[EtapeDph.arrivee], 1);
      expect(find.text('📷 Reprendre la photo'), findsOneWidget);
      expect(find.text('📷 Prendre une photo'), findsNothing);
      expect(find.text('Aucune photo pour cette étape.'), findsNothing);
      var lignes = await photosEnBase(tester, id);
      expect(lignes.single.octets, [0xFF, 0xD8, 1]);
      final premiere = lignes.single.id;

      await toucherPhoto(tester, '📷 Reprendre la photo');
      expect(visite(tester, id).photos[EtapeDph.arrivee], 1);
      lignes = await photosEnBase(tester, id);
      expect(lignes, hasLength(1));
      expect(lignes.single.octets, [0xFF, 0xD8, 2]);
      expect(lignes.single.id, isNot(premiere));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('prise annulée ou en échec : l\'ancienne photo est conservée', (
      tester,
    ) async {
      final id = await ouvrir(tester);
      appareil.prises.addAll([
        [0xFF, 0xD8, 1],
        null,
        Exception('caméra'),
      ]);
      await toucherPhoto(tester, '📷 Prendre une photo');

      await toucherPhoto(tester, '📷 Reprendre la photo');
      expect(visite(tester, id).photos[EtapeDph.arrivee], 1);
      expect((await photosEnBase(tester, id)).single.octets, [0xFF, 0xD8, 1]);

      await toucherPhoto(tester, '📷 Reprendre la photo');
      expect(visite(tester, id).photos[EtapeDph.arrivee], 1);
      expect((await photosEnBase(tester, id)).single.octets, [0xFF, 0xD8, 1]);
      expect(find.text('📷 Reprendre la photo'), findsOneWidget);
      await attendreToast(tester);
    });

    testWidgets('supprimer remet l\'étape à zéro et bloque « Suivant »', (
      tester,
    ) async {
      final id = await ouvrir(tester);
      appareil.prises.add([0xFF, 0xD8, 1]);
      await toucherPhoto(tester, '📷 Prendre une photo');
      expect(visite(tester, id).photos[EtapeDph.arrivee], 1);

      await tester.tap(find.text('✕'));
      await tester.pump();
      await attendreBase(tester);
      await tester.pumpAndSettle();
      expect(visite(tester, id).photos[EtapeDph.arrivee], 0);
      expect(await photosEnBase(tester, id), isEmpty);
      expect(find.text('📷 Prendre une photo'), findsOneWidget);
      expect(find.text('Aucune photo pour cette étape.'), findsOneWidget);

      await suivant(tester);
      expect(find.text("Prenez la photo d'arrivée sur site."), findsOneWidget);
      await attendreToast(tester);
    });

    testWidgets('photo récupérée après fermeture d’Android : elle remplace', (
      tester,
    ) async {
      final id = await ouvrir(
        tester,
        avant: (base, appareil) async {
          await base.ajouterPhotoVisite('v218093', 'arrivee', [0xFF, 0xD8, 1]);
          appareil.perdue = [0xFF, 0xD8, 7];
        },
      );
      await attendreBase(tester);
      await tester.pumpAndSettle();

      expect(id, 'v218093');
      expect(visite(tester, id).photos[EtapeDph.arrivee], 1);
      final lignes = await photosEnBase(tester, id);
      expect(lignes, hasLength(1));
      expect(lignes.single.octets, [0xFF, 0xD8, 7]);
    });
  });
}
