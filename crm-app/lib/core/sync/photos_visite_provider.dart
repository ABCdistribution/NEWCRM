import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../db/app_database.dart';
import '../db/base_provider.dart';

/// Appareil photo du téléphone (remplaçable en test).
abstract class CaptureurPhoto {
  /// Ouvre l'appareil photo ; nul si la prise est annulée.
  Future<List<int>?> prendre();

  /// Photo prise juste avant qu'Android ferme l'application, ou nul s'il n'y en a pas.
  Future<List<int>?> retrouverPerdue();
}

class CaptureurCamera implements CaptureurPhoto {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<List<int>?> prendre() async {
    final fichier = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    return fichier?.readAsBytes();
  }

  @override
  Future<List<int>?> retrouverPerdue() async {
    final r = await _picker.retrieveLostData();
    final fichier = r.file;
    if (r.isEmpty || fichier == null) return null;
    return fichier.readAsBytes();
  }
}

final captureurPhotoProvider = Provider<CaptureurPhoto>(
  (ref) => CaptureurCamera(),
);

/// Photos prises pendant une visite, lues et écrites dans la base chiffrée de l'appareil.
class PhotosVisiteNotifier extends Notifier<List<PhotoVisiteLocale>> {
  PhotosVisiteNotifier(this.visiteId);

  final String visiteId;

  AppDatabase? get _base {
    try {
      return ref.read(baseLocaleProvider);
    } catch (_) {
      return null; // pas de base (démonstration, tests)
    }
  }

  @override
  List<PhotoVisiteLocale> build() {
    _charger();
    return const [];
  }

  Future<void> _charger() async {
    final base = _base;
    if (base == null) return;
    final lignes = await base.photosDeVisite(visiteId);
    if (ref.mounted) state = lignes;
  }

  /// Enregistre la photo de l'étape (une seule par étape : elle remplace l'ancienne) ; faux si la base n'est pas
  /// disponible.
  Future<bool> remplacer(String etape, List<int> octets) async {
    final base = _base;
    if (base == null) return false;
    await base.remplacerPhotoVisite(visiteId, etape, octets);
    await _charger();
    return true;
  }

  /// Supprime la photo de l'étape.
  Future<void> supprimer(String etape) async {
    final base = _base;
    if (base == null) return;
    await base.supprimerPhotosEtapeVisite(visiteId, etape);
    await _charger();
  }
}

final photosVisiteProvider =
    NotifierProvider.family<
      PhotosVisiteNotifier,
      List<PhotoVisiteLocale>,
      String
    >(PhotosVisiteNotifier.new);
