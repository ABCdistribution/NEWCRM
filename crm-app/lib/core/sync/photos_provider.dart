import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/equipe_serveur.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import 'catalogue_provider.dart';
import 'domaines_provider.dart';

/// Photos de profil par identifiant d'utilisateur (octets d'une image JPEG ou PNG).
///
/// Lues d'abord dans la base locale, puis téléchargées en arrière-plan pour l'utilisateur connecté et son équipe
/// (`GET /users/:id/photo`). Elles n'arrêtent jamais l'application : sans photo, l'avatar garde les initiales.
/// Une photo absente du CRM est mémorisée (octets vides) et redemandée au bout de [validite].
class PhotosNotifier extends Notifier<Map<String, Uint8List>> {
  static const validite = Duration(days: 7);

  @override
  Map<String, Uint8List> build() {
    final utilisateur = ref.watch(sessionProvider);
    // Équipe connue : ses photos se téléchargent dès qu'elle est lue.
    ref.watch(equipeProvider.select((e) => (e.nb, e.majLe)));
    if (utilisateur == null) {
      state0 = const {};
      return const {};
    }
    Future.microtask(() => _charger(utilisateur.id));
    return state0;
  }

  /// État conservé d'une reconstruction à l'autre (les photos déjà lues ne disparaissent pas).
  Map<String, Uint8List> state0 = const {};

  AppDatabase? get _base {
    try {
      return ref.read(baseLocaleProvider);
    } catch (_) {
      return null;
    }
  }

  Future<void> _charger(String moi) async {
    final base = _base;
    if (base == null) return;
    final lignes = await base.toutesLesPhotos();
    if (!ref.mounted) return;
    final connues = {for (final l in lignes) l.id: l};
    final lues = <String, Uint8List>{
      for (final l in lignes)
        if (l.octets.isNotEmpty) l.id: l.octets,
    };
    state0 = lues;
    state = lues;

    final lecture = ref.read(apiClientProvider);
    if (lecture is! ApiOctets) return;
    final api = lecture as ApiOctets;
    final ids = <String>{
      moi,
      for (final c in equipeServeur()?.chefs ?? const []) c.id,
      for (final p in promoteursTous())
        if (p.userId != null) p.userId!,
    };
    final limite = DateTime.now().subtract(validite);
    final aTelecharger = [
      for (final id in ids)
        if (connues[id] == null || connues[id]!.majLe.isBefore(limite)) id,
    ];
    for (var i = 0; i < aTelecharger.length; i += 4) {
      final lot = aTelecharger.skip(i).take(4);
      await Future.wait([for (final id in lot) _telecharger(api, base, id)]);
      if (!ref.mounted) return;
    }
  }

  Future<void> _telecharger(ApiOctets api, AppDatabase base, String id) async {
    try {
      final octets = await api.octets(
        '/users/${Uri.encodeComponent(id)}/photo',
      );
      await base.ecrirePhoto(id, octets ?? const []);
      if (!ref.mounted || octets == null || octets.isEmpty) return;
      state0 = {...state0, id: Uint8List.fromList(octets)};
      state = state0;
    } on ErreurApi {
      // Réseau coupé ou refus : la photo sera redemandée au prochain lancement.
    } catch (_) {}
  }
}

final photosProvider = NotifierProvider<PhotosNotifier, Map<String, Uint8List>>(
  PhotosNotifier.new,
);
