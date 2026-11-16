import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/fiche_client.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import 'catalogue_provider.dart';

const _domaineFiche = 'fiche_client';

FicheClient? _depuisCache(String id, String? brut) {
  if (brut == null) return null;
  try {
    final j = jsonDecode(brut);
    if (j is! Map<String, dynamic> || j['detail'] is! Map<String, dynamic>) {
      return null;
    }
    final h = j['historique'];
    return ficheClientDepuisJson(
      id,
      j['detail'] as Map<String, dynamic>,
      h is Map<String, dynamic> ? h : null,
    );
  } catch (_) {
    return null;
  }
}

/// Fiche détaillée d'un client du CRM, chargée à l'ouverture : la copie locale d'abord (hors connexion), puis la
/// version fraîche (`GET /clients/:id` et `/clients/:id/historique`). Réseau coupé : la copie locale reste.
final ficheClientProvider = StreamProvider.family<FicheClient?, String>((
  ref,
  id,
) async* {
  AppDatabase? base;
  try {
    base = ref.read(baseLocaleProvider);
  } catch (_) {}
  if (base != null) {
    final copie = _depuisCache(
      id,
      await base.enregistrement(_domaineFiche, id),
    );
    if (copie != null) yield copie;
  }
  final api = ref.read(apiClientProvider);
  final chemin = '/clients/${Uri.encodeComponent(id)}';
  try {
    final detail = await api.get(chemin);
    if (detail is! Map<String, dynamic>) return;
    Object? historique;
    try {
      historique = await api.get('$chemin/historique');
    } on ErreurApi catch (e) {
      // Le marketing n'a pas accès à l'historique : la fiche se passe de commandes et de visites.
      if (e.type != TypeErreurApi.refuse) rethrow;
    }
    final h = historique is Map<String, dynamic> ? historique : null;
    if (base != null) {
      await base.ecrireEnregistrement(
        _domaineFiche,
        id,
        jsonEncode({'detail': detail, 'historique': h}),
      );
    }
    yield ficheClientDepuisJson(id, detail, h);
  } on ErreurApi catch (e) {
    if (e.type == TypeErreurApi.sessionExpiree) {
      await ref.read(sessionProvider.notifier).deconnecter();
    }
  }
});
