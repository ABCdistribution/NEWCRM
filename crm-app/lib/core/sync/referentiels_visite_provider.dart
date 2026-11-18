import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/referentiels_visite.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import 'catalogue_provider.dart';

const _domaine = 'referentiel_visite';

/// Liste du CRM lue comme les autres fiches : la copie locale d'abord (hors connexion), puis la version fraîche.
/// Sans copie ni réseau (démonstration, tests), la liste reste vide.
Stream<List<T>> _liste<T>(
  Ref ref,
  String cle,
  String chemin,
  List<T> Function(Object? json) lire,
) async* {
  AppDatabase? base;
  try {
    base = ref.read(baseLocaleProvider);
  } catch (_) {}
  if (base != null) {
    final brut = await base.enregistrement(_domaine, cle);
    if (brut != null) {
      try {
        yield lire(jsonDecode(brut));
      } catch (_) {}
    }
  }
  try {
    final reponse = await ref.read(apiClientProvider).get(chemin);
    final liste = reponse is Map ? reponse['data'] : reponse;
    if (liste is! List) return;
    if (base != null) {
      await base.ecrireEnregistrement(_domaine, cle, jsonEncode(liste));
    }
    yield lire(liste);
  } on ErreurApi catch (e) {
    if (e.type == TypeErreurApi.sessionExpiree) {
      await ref.read(sessionProvider.notifier).deconnecter();
    }
  } catch (_) {}
}

/// Questionnaire de fin de visite (`GET /questionnaire`), administré dans le CRM.
final questionnaireProvider = StreamProvider<List<QuestionFin>>(
  (ref) => _liste(ref, 'questionnaire', '/questionnaire', questionsDepuisJson),
);

/// Raisons d'absence de commande (`GET /raisons-absence-commande`), administrées dans le CRM.
final raisonsAbsenceProvider = StreamProvider<List<RaisonAbsence>>(
  (ref) => _liste(
    ref,
    'raisons_absence',
    '/raisons-absence-commande',
    raisonsDepuisJson,
  ),
);

/// Promotions en cours à pointer en rayon (`GET /promos?actives=1`).
final promosOpProvider = StreamProvider<List<PromoOp>>(
  (ref) => _liste(ref, 'promos_op', '/promos?actives=1', promosOpDepuisJson),
);
