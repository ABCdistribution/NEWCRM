import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../db/app_database.dart';
import '../db/base_provider.dart';
import '../models/models.dart';

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

  /// Mémorise, avant d'ouvrir l'appareil photo, l'étape de la photo qui va être prise.
  Future<void> memoriserPriseEnCours(String etape) async {
    try {
      await _base?.memoriserPhotoEnCours(visiteId, etape);
    } catch (_) {}
  }

  /// Efface la photo en cours (enregistrée, annulée ou en échec).
  Future<void> effacerPriseEnCours() async {
    try {
      await _base?.effacerPhotoEnCours();
    } catch (_) {}
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

/// Issue de la récupération d'une photo retrouvée après la fermeture d'Android.
class PhotoRecuperee {
  const PhotoRecuperee.rattachee(String this.visiteId, EtapeDph this.etape)
    : message = null;

  /// Photo retrouvée mais rattachée à aucune étape : `message` est à montrer à l'utilisateur.
  const PhotoRecuperee.perdue(String this.message)
    : visiteId = null,
      etape = null;

  final String? visiteId;
  final EtapeDph? etape;
  final String? message;
}

/// Récupère la photo prise juste avant qu'Android ferme l'application et la rattache à l'étape mémorisée avant
/// l'ouverture de l'appareil photo (visite + étape), non à l'écran qui s'ouvre en premier.
class RecuperationPhoto {
  RecuperationPhoto(this._ref);

  final Ref _ref;

  /// Nul s'il n'y a rien à récupérer. `visiteExiste` dit si la visite mémorisée est encore un brouillon du téléphone.
  /// L'intention mémorisée est effacée une fois la photo rattachée, ou quand il n'y a plus rien à retrouver ; si la
  /// photo ne peut pas être rattachée, l'issue porte un message à montrer.
  Future<PhotoRecuperee?> recuperer({
    required bool Function(String visiteId) visiteExiste,
  }) async {
    AppDatabase? base;
    try {
      base = _ref.read(baseLocaleProvider);
    } catch (_) {}
    List<int>? octets;
    try {
      octets = await _ref.read(captureurPhotoProvider).retrouverPerdue();
    } catch (_) {}
    ({String visiteId, String etape})? intention;
    try {
      intention = await base?.photoEnCours();
    } catch (_) {}
    if (octets == null) {
      // Rien à retrouver : l'intention restante est périmée (prise abandonnée avant la fermeture).
      if (intention != null) await _effacer(base);
      return null;
    }
    if (intention == null) {
      return const PhotoRecuperee.perdue(
        'Photo retrouvée, étape inconnue : non rattachée.',
      );
    }
    final etape = EtapeDph.values
        .where((e) => e.estPhoto && e.cle == intention!.etape)
        .firstOrNull;
    if (etape == null || !visiteExiste(intention.visiteId)) {
      await _effacer(base);
      return const PhotoRecuperee.perdue(
        'Photo retrouvée, visite introuvable : non rattachée.',
      );
    }
    final ok = await _ref
        .read(photosVisiteProvider(intention.visiteId).notifier)
        .remplacer(etape.cle, octets);
    if (!ok) {
      return const PhotoRecuperee.perdue(
        'Photo retrouvée non enregistrée : base locale absente.',
      );
    }
    await _effacer(base);
    return PhotoRecuperee.rattachee(intention.visiteId, etape);
  }

  Future<void> _effacer(AppDatabase? base) async {
    try {
      await base?.effacerPhotoEnCours();
    } catch (_) {}
  }
}

final recuperationPhotoProvider = Provider<RecuperationPhoto>(
  RecuperationPhoto.new,
);
