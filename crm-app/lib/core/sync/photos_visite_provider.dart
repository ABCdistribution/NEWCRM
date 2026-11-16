import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/base_provider.dart';

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

  /// Enregistre une photo de l'étape ; faux si la base n'est pas disponible.
  Future<bool> ajouter(String etape, List<int> octets) async {
    final base = _base;
    if (base == null) return false;
    await base.ajouterPhotoVisite(visiteId, etape, octets);
    await _charger();
    return true;
  }

  Future<void> supprimer(int id) async {
    final base = _base;
    if (base == null) return;
    await base.supprimerPhotoVisite(id);
    await _charger();
  }
}

final photosVisiteProvider =
    NotifierProvider.family<
      PhotosVisiteNotifier,
      List<PhotoVisiteLocale>,
      String
    >(PhotosVisiteNotifier.new);
