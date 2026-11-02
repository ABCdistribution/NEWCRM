import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/role.dart';
import '../core/config.dart';
import '../core/providers.dart';
import 'pilot/pilot_accueil_page.dart';
import 'pilot/pilot_planning_page.dart';
import 'providers.dart';

/// Met à jour la copie locale depuis le serveur, puis rafraîchit les écrans concernés. Les écrans lisent toujours
/// la base du téléphone (instantané) ; c'est ici que le réseau est sollicité. Chaque méthode est silencieuse :
/// sans réseau, la copie existante reste en place. Elles renvoient vrai si le réseau a répondu.
class MiseAJourLocale {
  MiseAJourLocale(this._ref);

  final Ref _ref;

  String? get _userId => _ref.read(currentUserIdProvider);

  Future<bool> _etape(Future<void> Function(String userId) f) async {
    final userId = _userId;
    if (userId == null) return false;
    try {
      await f(userId);
      return true;
    } on Object {
      return false; // hors ligne ou refus du serveur : la copie existante reste en place
    }
  }

  Future<bool> tournee() => _etape((userId) async {
        await _ref.read(tourneeRepositoryProvider).load(userId, DateTime.now());
        _ref.invalidate(tourneeProvider);
      });

  Future<bool> objectif() => _etape((userId) async {
        await chargerObjectifReseau(_ref, userId);
        _ref.invalidate(objectifMoisProvider);
      });

  Future<bool> questionnaire() => _etape((userId) async {
        await chargerQuestionnaireReseau(_ref, userId);
        _ref.invalidate(questionnaireProvider);
      });

  Future<bool> magasins() => _etape((userId) async {
        await _ref.read(magasinRepositoryProvider).loadAll(userId);
        _ref.invalidate(magasinsProvider);
      });

  Future<bool> produits() => _etape((userId) async {
        await _ref.read(produitRepositoryProvider).loadAll(userId);
        _ref.invalidate(produitsProvider);
      });

  Future<bool> pilot() => _etape((userId) async {
        await _ref.read(pilotRepositoryProvider).load(userId, DateTime.now());
        _ref.invalidate(pilotAccueilProvider);
      });

  Future<bool> prospection() => _etape((userId) async {
        await chargerCompteursProspectionReseau(_ref, userId);
        _ref.invalidate(compteursProspectionProvider);
      });

  /// Fiche et historique de chaque magasin, pour les consulter hors ligne sans les avoir ouverts. Quelques requêtes
  /// en parallèle ; s'arrête dès que le réseau lâche. [progression] reçoit (faits, total).
  Future<void> fichesMagasins({void Function(int fait, int total)? progression}) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final magasins = _ref.read(magasinRepositoryProvider);
      final liste = (await magasins.local(userId))?.value ?? const [];
      var suivant = 0, fait = 0, echecs = 0;
      Future<void> ouvrier() async {
        while (echecs < 5 && suivant < liste.length) {
          final m = liste[suivant++];
          final ok = await magasins.precharger(userId, m.id, sauf: const Duration(hours: 12));
          echecs = ok ? 0 : echecs + 1;
          progression?.call(++fait, liste.length);
        }
      }

      await Future.wait([for (var i = 0; i < 4; i++) ouvrier()]);
    } on Object {
      // silencieux
    }
  }
}

final miseAJourLocaleProvider = Provider<MiseAJourLocale>(MiseAJourLocale.new);

/// Avancement du chargement des données de l'application.
class EtatPrechargement {
  const EtatPrechargement({
    this.verifie = false,
    this.premierChargement = false,
    this.termine = false,
    this.echec = false,
    this.etape = '',
    this.fait = 0,
    this.total = 1,
    this.fichesFaites = 0,
    this.fichesTotal = 0,
  });

  /// Vrai une fois qu'on sait si le téléphone avait déjà des données.
  final bool verifie;

  /// Aucune donnée sur le téléphone : l'application ne peut rien afficher avant ce premier chargement.
  final bool premierChargement;
  final bool termine;

  /// Le réseau a manqué pendant le premier chargement : rien à afficher, il faut réessayer.
  final bool echec;
  final String etape;
  final int fait;
  final int total;
  final int fichesFaites;
  final int fichesTotal;

  /// L'écran de chargement n'apparaît qu'au tout premier lancement ; ensuite la mise à jour se fait en arrière-plan.
  bool get bloquant => !verifie || (premierChargement && !termine);

  EtatPrechargement copie({
    bool? verifie,
    bool? premierChargement,
    bool? termine,
    bool? echec,
    String? etape,
    int? fait,
    int? total,
    int? fichesFaites,
    int? fichesTotal,
  }) =>
      EtatPrechargement(
        verifie: verifie ?? this.verifie,
        premierChargement: premierChargement ?? this.premierChargement,
        termine: termine ?? this.termine,
        echec: echec ?? this.echec,
        etape: etape ?? this.etape,
        fait: fait ?? this.fait,
        total: total ?? this.total,
        fichesFaites: fichesFaites ?? this.fichesFaites,
        fichesTotal: fichesTotal ?? this.fichesTotal,
      );
}

/// Lancé à l'ouverture de l'application et à la connexion (observé par l'écran principal) : charge TOUTE la base
/// locale (tournée, questionnaire, objectifs, magasins, produits, pilotage, puis fiches de tous les magasins) pour
/// que l'application soit utilisable sans réseau.
class PrechargementController extends Notifier<EtatPrechargement> {
  @override
  EtatPrechargement build() {
    final userId = ref.watch(currentUserIdProvider);
    if (userId != null) Future.microtask(() => lancer(userId));
    return const EtatPrechargement();
  }

  Future<void> lancer([String? userId]) async {
    userId ??= ref.read(currentUserIdProvider);
    if (userId == null) return;
    // Connexion de développement (sans vrai jeton) : le serveur refuserait tout, on ne bloque pas l'interface.
    if (ref.read(sessionProvider).value?.token == AppConfig.devToken) {
      state = const EtatPrechargement(verifie: true, termine: true);
      return;
    }
    final cache = ref.read(cacheRepositoryProvider);
    final aDesDonnees = await cache.get(userId, 'magasins') != null && await cache.get(userId, 'produits') != null;
    if (!ref.mounted) return;
    state = EtatPrechargement(verifie: true, premierChargement: !aDesDonnees);

    final maj = ref.read(miseAJourLocaleProvider);
    final role = ref.read(currentRoleProvider);
    final pilot = role?.canSwitchSpace ?? false;
    final etapes = <(String, Future<bool> Function())>[
      ('Tournée du jour', maj.tournee),
      ('Questionnaire de visite', maj.questionnaire),
      ('Objectifs du mois', maj.objectif),
      ('Magasins', maj.magasins),
      ('Produits', maj.produits),
      if (pilot) ('Pilotage', maj.pilot),
      if (pilot) ('Prospection', maj.prospection),
    ];
    var reussies = 0;
    for (var i = 0; i < etapes.length; i++) {
      if (!ref.mounted) return;
      state = state.copie(etape: etapes[i].$1, fait: i, total: etapes.length);
      if (await etapes[i].$2()) reussies++;
    }
    if (!ref.mounted) return;
    // Premier chargement sans aucune réponse du serveur : il n'y a rien à afficher.
    final vide = state.premierChargement && reussies == 0;
    state = state.copie(termine: !vide, echec: vide, fait: etapes.length);
    if (vide) return;

    await maj.fichesMagasins(progression: (f, t) {
      if (ref.mounted) state = state.copie(fichesFaites: f, fichesTotal: t);
    });
  }
}

final prechargementProvider = NotifierProvider<PrechargementController, EtatPrechargement>(PrechargementController.new);
