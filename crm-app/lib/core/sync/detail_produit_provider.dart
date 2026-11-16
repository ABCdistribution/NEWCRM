import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/detail_produit.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import 'catalogue_provider.dart';

const _domaineProduit = 'fiche_produit';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Détail d'un article du CRM (tarifs, stock exact, promotions, remplaçants), chargé à l'ouverture de sa fiche :
/// la copie locale d'abord (hors connexion), puis la version fraîche (`GET /articles/:id`).
///
/// Les produits de démonstration (identifiants non UUID) n'ont pas de détail.
final detailProduitProvider = StreamProvider.family<DetailProduit?, String>((
  ref,
  id,
) async* {
  if (!_uuid.hasMatch(id)) return;
  AppDatabase? base;
  try {
    base = ref.read(baseLocaleProvider);
  } catch (_) {}
  if (base != null) {
    final brut = await base.enregistrement(_domaineProduit, id);
    if (brut != null) {
      try {
        final j = jsonDecode(brut);
        if (j is Map<String, dynamic>) yield detailProduitDepuisJson(j);
      } catch (_) {}
    }
  }
  try {
    final reponse = await ref
        .read(apiClientProvider)
        .get('/articles/${Uri.encodeComponent(id)}');
    if (reponse is! Map<String, dynamic>) return;
    if (base != null) {
      await base.ecrireEnregistrement(_domaineProduit, id, jsonEncode(reponse));
    }
    yield detailProduitDepuisJson(reponse);
  } on ErreurApi catch (e) {
    if (e.type == TypeErreurApi.sessionExpiree) {
      await ref.read(sessionProvider.notifier).deconnecter();
    }
  }
});
