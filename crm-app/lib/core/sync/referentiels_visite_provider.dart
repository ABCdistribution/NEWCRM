import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/indispensables_demo.dart';
import '../data/pem_demo.dart';
import '../data/referentiels_visite.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import '../state/state.dart';
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

/// Produits indispensables de l'enseigne d'un magasin (`GET /produits-indispensables/client/:id`), copie locale puis
/// version fraîche ; vide sans enseigne, sans liste, hors ligne sans copie. Magasin de démonstration : liste fictive.
final produitsIndispensablesProvider =
    StreamProvider.family<List<ProduitIndispensable>, String>((ref, magasinId) {
      final m = ref.read(magasinParIdProvider(magasinId));
      if (m != null && !m.reel) {
        return Stream.value(indispensablesDemo[magasinId] ?? const []);
      }
      return _liste(
        ref,
        'indispensables_$magasinId',
        '/produits-indispensables/client/${Uri.encodeComponent(magasinId)}',
        indispensablesDepuisJson,
      );
    });

/// Promotions en cours et à venir (`GET /promos?actives=1&avenir=1`), pour le briefing d'ouverture d'une visite.
final promosBriefingProvider = StreamProvider<List<PromoOp>>(
  (ref) => _liste(
    ref,
    'promos_briefing',
    '/promos?actives=1&avenir=1',
    promosOpDepuisJson,
  ),
);

/// Articles PEM à vérifier lors d'une visite PEM (`GET /pem/articles`) : copie locale d'abord (hors connexion), puis
/// version fraîche, sans bruit en cas d'échec. Démonstration : quelques articles du catalogue fictif.
final articlesPemProvider = StreamProvider<List<ArticlePem>>((ref) {
  if (ref.watch(sessionProvider) == null) return Stream.value(articlesPemDemo);
  return _liste(ref, 'articles_pem', '/pem/articles', articlesPemDepuisJson);
});
