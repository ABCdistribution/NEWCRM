import 'dart:async';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/envoi/corps_activite.dart';
import 'package:crm_app/core/envoi/envoi_provider.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';

/// Un appel d'écriture reçu : méthode, chemin et corps JSON.
typedef AppelEcriture = ({String methode, String chemin, Object? corps});

/// Faux `ApiEcriture` : enregistre les appels, peut échouer (une erreur par appel, dans l'ordre) ou rester en attente.
class FauxEcriture implements ApiEcriture {
  final List<AppelEcriture> appels = [];

  /// Erreurs des prochains appels, dans l'ordre (null : l'appel passe).
  final List<ErreurApi?> pannes = [];

  /// Si posé, les appels attendent sa fin (envoi « en cours »).
  Completer<void>? attente;

  /// Corps de la réponse en cas de succès.
  Object? reponse = const {'id': 'x'};

  /// Corps JSON de l'appel `i`.
  Map<String, Object?> corps(int i) =>
      Map<String, Object?>.from(appels[i].corps! as Map);

  @override
  Future<Object?> envoyer(
    String methode,
    String chemin, {
    Object? corps,
  }) async {
    appels.add((methode: methode, chemin: chemin, corps: corps));
    final a = attente;
    if (a != null) await a.future;
    if (pannes.isNotEmpty) {
      final p = pannes.removeAt(0);
      if (p != null) throw p;
    }
    return reponse;
  }
}

/// Planning synchronisé factice : compte les rafraîchissements, sans réseau ni base.
class PlanningSynchroFaux extends PlanningSynchroNotifier {
  int rafraichis = 0;

  @override
  EtatSynchro build() => const EtatSynchro();

  @override
  Future<void> rafraichir() async => rafraichis++;
}

/// Prospects synchronisés factices : compte les rafraîchissements.
class ProspectsSynchroFaux extends ProspectsNotifier {
  int rafraichis = 0;

  @override
  EtatSynchro build() => const EtatSynchro();

  @override
  Future<void> rafraichir() async => rafraichis++;
}

/// Clients synchronisés factices : compte les rafraîchissements.
class ClientsSynchroFaux extends ClientsNotifier {
  int rafraichis = 0;

  @override
  EtatSynchro build() => const EtatSynchro();

  @override
  Future<void> rafraichir() async => rafraichis++;
}

/// File d'envoi factice : garde les écritures d'activité (note, appel, e-mail) rangées, sans base ni réseau.
class FauxEnvoi extends EnvoiNotifier {
  final List<RequeteActivite> activites = [];

  /// Faux : la file n'est pas utilisable (pas de base), l'appelant garde son comportement d'avant.
  bool indisponible = false;

  @override
  EtatFileEnvoi build() => const EtatFileEnvoi();

  @override
  Future<bool> enfilerActivite(RequeteActivite r) async {
    if (indisponible) return false;
    activites.add(r);
    return true;
  }
}
