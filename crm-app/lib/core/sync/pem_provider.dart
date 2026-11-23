import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/pem_demo.dart';
import '../data/pem_serveur.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import '../logic/logic.dart';
import '../models/models.dart';
import 'catalogue_provider.dart';
import 'domaines_provider.dart';
import 'sync_domaine.dart';

/// Appels immédiats sur une proposition de visite PEM : l'API répond, puis l'état local est mis à jour. Une erreur
/// ([ErreurApi]) porte le message en français de l'API.
abstract interface class ActionsPem {
  /// Accepte la proposition, à `date` (`aaaa-mm-jj`, entre aujourd'hui et +14 jours) ou à la date proposée.
  Future<PropositionPem> accepter(String id, {String? date});

  /// Reporte la proposition à `date` (entre demain et +14 jours), avec un motif facultatif.
  Future<PropositionPem> reporter(String id, {String? motif, String? date});
}

/// Propositions de visite PEM faites au promoteur (`GET /pem/propositions`) : copie locale chiffrée lue d'abord (hors
/// connexion), puis version fraîche ; chargées en arrière-plan. Réservées au promoteur (COMMERCIAL).
///
/// Accepter et reporter sont des appels immédiats : la réponse de l'API remplace la proposition dans la copie locale.
/// Les lignes de planning créées par le CRM à l'acceptation arrivent par la synchro du planning, relancée ensuite.
class PropositionsPemNotifier extends SynchroDomaineNotifier
    implements ActionsPem {
  @override
  String get domaine => 'pem_propositions';

  @override
  bool get refusTolere => true;

  /// Lignes JSON (propositions de l'API) de la copie en mémoire.
  List<Map<String, dynamic>> _lignes = [];

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) {
    _lignes = lignes == null ? [] : List.of(lignes);
    definirPropositionsPemServeur(
      lignes == null
          ? null
          : [for (final j in lignes) ?propositionPemDepuisJson(j)],
    );
  }

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) async {
    if (ref.read(sessionProvider)?.roleApi != 'COMMERCIAL') return 0;
    return SyncDomaine(api, base, domaine).telecharger(
      '/pem/propositions',
      maxLignes: 500,
      progression: progression,
    );
  }

  AppDatabase? get _baseLocale {
    try {
      return ref.read(baseLocaleProvider);
    } catch (_) {
      return null;
    }
  }

  static String _chemin(String id) =>
      '/pem/propositions/${Uri.encodeComponent(id)}';

  /// Range la proposition renvoyée par l'API (complétée par ce qu'on en savait si la réponse est partielle) et publie
  /// la liste ; rafraîchit ensuite le planning, que le CRM a pu modifier.
  Future<PropositionPem> _memoriser(String id, Object? reponse) async {
    if (reponse is! Map<String, dynamic>) {
      throw const ErreurApi(TypeErreurApi.inattendue);
    }
    final ancienne = _lignes.where((l) => l['id'] == id).firstOrNull;
    final json = <String, dynamic>{...?ancienne, ...reponse, 'id': id};
    final proposition = propositionPemDepuisJson(json);
    if (proposition == null) throw const ErreurApi(TypeErreurApi.inattendue);
    _lignes = [
      for (final l in _lignes)
        if (l['id'] != id) l,
      json,
    ];
    await _baseLocale?.ecrireEnregistrement(domaine, id, jsonEncode(json));
    if (ref.mounted) {
      appliquer(_lignes);
      state = state.avec(nb: _lignes.length);
      unawaited(ref.read(planningSynchroProvider.notifier).rafraichir());
    }
    return proposition;
  }

  @override
  Future<PropositionPem> accepter(String id, {String? date}) async =>
      _memoriser(
        id,
        await ref
            .read(apiEcritureProvider)
            .envoyer('POST', '${_chemin(id)}/accepter', corps: {'date': ?date}),
      );

  @override
  Future<PropositionPem> reporter(
    String id, {
    String? motif,
    String? date,
  }) async => _memoriser(
    id,
    await ref
        .read(apiEcritureProvider)
        .envoyer(
          'POST',
          '${_chemin(id)}/reporter',
          corps: {
            if (motif != null && motif.trim().isNotEmpty) 'motif': motif.trim(),
            'date': ?date,
          },
        ),
  );
}

final propositionsPemSynchroProvider =
    NotifierProvider<PropositionsPemNotifier, EtatSynchro>(
      PropositionsPemNotifier.new,
    );

/// Propositions de la démonstration : acceptées et reportées localement, sans réseau.
class PropositionsPemDemoNotifier extends Notifier<List<PropositionPem>>
    implements ActionsPem {
  @override
  List<PropositionPem> build() => propositionsPemDemo;

  PropositionPem _trouver(String id) {
    final p = state.where((x) => x.id == id).firstOrNull;
    if (p == null) {
      throw const ErreurApi(TypeErreurApi.inattendue, statut: 404);
    }
    return p;
  }

  PropositionPem _ranger(PropositionPem p) {
    state = [
      for (final x in state)
        if (x.id == p.id) p else x,
    ];
    return p;
  }

  static ErreurApi _horsFenetre(String debut) => ErreurApi(
    TypeErreurApi.inattendue,
    statut: 400,
    detail:
        'La date doit être comprise entre $debut et dans $joursFenetrePem jours.',
  );

  @override
  Future<PropositionPem> accepter(String id, {String? date}) async {
    final p = _trouver(id);
    final jour = lireJourIso(date);
    if (date != null &&
        (jour == null ||
            !dansFenetre(jour, fenetreAcceptation(DemoTemps.aujourdhui)))) {
      throw _horsFenetre("aujourd'hui");
    }
    return _ranger(accepterLocalement(p, date: date));
  }

  @override
  Future<PropositionPem> reporter(
    String id, {
    String? motif,
    String? date,
  }) async {
    final p = _trouver(id);
    if (!p.reportable) {
      throw const ErreurApi(
        TypeErreurApi.inattendue,
        statut: 409,
        detail: messageObligatoire,
      );
    }
    final jour = lireJourIso(date);
    if (date != null &&
        (jour == null ||
            !dansFenetre(jour, fenetreReport(DemoTemps.aujourdhui)))) {
      throw _horsFenetre('demain');
    }
    return _ranger(reporterLocalement(p, motif: motif, date: date));
  }
}

final propositionsPemDemoProvider =
    NotifierProvider<PropositionsPemDemoNotifier, List<PropositionPem>>(
      PropositionsPemDemoNotifier.new,
    );

/// Propositions de visite PEM à traiter (proposées ou acceptées), de la date la plus proche à la plus lointaine :
/// celles du CRM pour un promoteur connecté, celles de la démonstration sinon.
final propositionsPemProvider = Provider<List<PropositionPem>>((ref) {
  if (ref.watch(sessionProvider) == null) {
    return propositionsOuvertes(ref.watch(propositionsPemDemoProvider));
  }
  ref.watch(propositionsPemSynchroProvider);
  return propositionsOuvertes(propositionsPemServeur() ?? const []);
});

/// Accepter / reporter : appels à l'API connecté, simulation locale en démonstration.
final actionsPemProvider = Provider<ActionsPem>(
  (ref) => ref.watch(sessionProvider) == null
      ? ref.read(propositionsPemDemoProvider.notifier)
      : ref.read(propositionsPemSynchroProvider.notifier),
);
