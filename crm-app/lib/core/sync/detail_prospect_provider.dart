import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/detail_prospect.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import 'catalogue_provider.dart';

const _domaineProspect = 'fiche_prospect';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

DetailProspect? _depuisCache(String? brut) {
  if (brut == null) return null;
  try {
    final j = jsonDecode(brut);
    if (j is! Map<String, dynamic> || j['detail'] is! Map<String, dynamic>) {
      return null;
    }
    final h = j['historique'];
    return detailProspectDepuisJson(
      j['detail'] as Map<String, dynamic>,
      h is Map<String, dynamic> ? h : null,
    );
  } catch (_) {
    return null;
  }
}

/// Contact et historique d'un prospect du CRM, chargés à l'ouverture de sa fiche : la copie locale d'abord (hors
/// connexion), puis la version fraîche. Les prospects de démonstration (identifiants non UUID) n'en ont pas.
final detailProspectProvider = StreamProvider.family<DetailProspect?, String>((
  ref,
  id,
) async* {
  if (!_uuid.hasMatch(id)) return;
  AppDatabase? base;
  try {
    base = ref.read(baseLocaleProvider);
  } catch (_) {}
  if (base != null) {
    final copie = _depuisCache(await base.enregistrement(_domaineProspect, id));
    if (copie != null) yield copie;
  }
  final api = ref.read(apiClientProvider);
  final chemin = '/prospects/${Uri.encodeComponent(id)}';
  try {
    final detail = await api.get(chemin);
    if (detail is! Map<String, dynamic>) return;
    final historique = await api.get('$chemin/historique');
    final h = historique is Map<String, dynamic> ? historique : null;
    if (base != null) {
      await base.ecrireEnregistrement(
        _domaineProspect,
        id,
        jsonEncode({'detail': detail, 'historique': h}),
      );
    }
    yield detailProspectDepuisJson(detail, h);
  } on ErreurApi catch (e) {
    if (e.type == TypeErreurApi.sessionExpiree) {
      await ref.read(sessionProvider.notifier).deconnecter();
    }
  }
});
