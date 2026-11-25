import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/commandes/state/commande_provider.dart';
import '../auth/session.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import '../db/envois_base.dart';
import '../models/models.dart';
import '../nav/nav.dart';
import '../state/state.dart';
import '../sync/catalogue_provider.dart';
import '../sync/detail_prospect_provider.dart';
import '../sync/domaines_provider.dart';
import '../sync/fiche_client_provider.dart';
import '../sync/journal_contacts_provider.dart';
import '../sync/pem_provider.dart';
import 'corps_activite.dart';
import 'corps_visite.dart';
import 'file_envoi.dart';

/// Une entrée de la file d'envoi refusée par l'API, pour l'affichage.
class EnvoiEnErreur {
  const EnvoiEnErreur({
    required this.id,
    required this.type,
    required this.message,
    this.libelle,
  });

  final int id;

  /// `visite`, `commande` ou `ecriture` ([TypeEnvoi]).
  final String type;
  final String message;

  /// Nom de l'entrée dans les messages (« Note prospect »…), nul : d'après le type.
  final String? libelle;
}

/// État de la file d'envoi de l'utilisateur connecté.
class EtatFileEnvoi {
  const EtatFileEnvoi({
    this.aEnvoyer = 0,
    this.enCours = false,
    this.erreurs = const [],
  });

  /// Entrées pas encore acceptées par le CRM (y compris celle qui part).
  final int aEnvoyer;

  /// Un envoi est en train de partir.
  final bool enCours;

  /// Entrées refusées par l'API : elles ne repartent pas sans relance.
  final List<EnvoiEnErreur> erreurs;

  int get enErreur => erreurs.length;
  bool get vide => aEnvoyer == 0 && erreurs.isEmpty;

  EtatFileEnvoi avec({
    int? aEnvoyer,
    bool? enCours,
    List<EnvoiEnErreur>? erreurs,
  }) => EtatFileEnvoi(
    aEnvoyer: aEnvoyer ?? this.aEnvoyer,
    enCours: enCours ?? this.enCours,
    erreurs: erreurs ?? this.erreurs,
  );
}

/// Délai avant de retenter après un manque de réseau : 15 s, 30 s, 1 min, 2 min, puis 5 min au plus.
Duration delaiReessaiParDefaut(int echecs) =>
    Duration(seconds: math.min(300, 15 * (1 << math.min(echecs - 1, 5))));

/// Délai de reprise selon le nombre d'échecs de suite (remplaçable dans les tests).
final delaiReessaiEnvoiProvider = Provider<Duration Function(int echecs)>(
  (ref) => delaiReessaiParDefaut,
);

/// Reprise de l'application au premier plan : la file repart.
class _Reprise with WidgetsBindingObserver {
  _Reprise(this._surReprise);

  final void Function() _surReprise;

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed) _surReprise();
  }
}

/// File d'envoi vers le CRM, pour un utilisateur connecté (en démonstration : inactive, rien ne part).
///
/// Elle repart au démarrage, à la reprise de l'application, à chaque changement d'onglet et à chaque ajout, puis par
/// reprises espacées (voir [delaiReessaiParDefaut]) tant que le réseau manque. Un seul envoi à la fois.
class EnvoiNotifier extends Notifier<EtatFileEnvoi> {
  Timer? _minuterie;
  bool _enCours = false;
  bool _relance = false;
  int _echecs = 0;

  AppDatabase? get _base {
    try {
      return ref.read(baseLocaleProvider);
    } catch (_) {
      return null;
    }
  }

  String? get _utilisateur => ref.read(sessionProvider)?.id;

  /// Vrai quand une session réelle et la base locale permettent d'utiliser la file.
  bool get actif => _utilisateur != null && _base != null;

  @override
  EtatFileEnvoi build() {
    final utilisateur = ref.watch(sessionProvider)?.id;
    ref.onDispose(() => _minuterie?.cancel());
    if (utilisateur == null || _base == null) return const EtatFileEnvoi();
    final reprise = _Reprise(() => unawaited(declencher()));
    try {
      WidgetsBinding.instance.addObserver(reprise);
      ref.onDispose(() => WidgetsBinding.instance.removeObserver(reprise));
    } catch (_) {
      // Sans moteur Flutter (tests de logique) : pas de reprise automatique.
    }
    ref.listen(ongletProvider, (_, _) {
      if (state.aEnvoyer > 0) unawaited(declencher());
    });
    Future.microtask(() async {
      await _actualiser();
      await declencher();
    });
    return const EtatFileEnvoi();
  }

  FileEnvoi _file(AppDatabase base) => FileEnvoi(
    base: base,
    ecriture: ref.read(apiEcritureProvider),
    fichiers: ref.read(apiFichiersProvider),
  );

  /// Recompte les entrées dans la base.
  Future<void> _actualiser() async {
    final base = _base;
    final utilisateur = _utilisateur;
    if (base == null || utilisateur == null || !ref.mounted) return;
    final lignes = await base.envoisDe(utilisateur);
    if (!ref.mounted) return;
    state = state.avec(
      aEnvoyer: lignes
          .where(
            (e) => e.etat == EtatEnvoi.aEnvoyer || e.etat == EtatEnvoi.enCours,
          )
          .length,
      erreurs: [
        for (final e in lignes)
          if (e.etat == EtatEnvoi.erreur)
            EnvoiEnErreur(
              id: e.id,
              type: e.type,
              message: e.derniereErreur ?? "L'envoi a échoué.",
              libelle: libelleEnvoi(e.type, e.payload),
            ),
      ],
    );
  }

  /// Range une visite terminée dans la file et lance l'envoi. Renvoie faux si la file n'est pas utilisable
  /// (démonstration, pas de base) : l'appelant garde alors son comportement d'avant.
  Future<bool> enfilerVisite(Visite visite) async {
    final base = _base;
    final utilisateur = _utilisateur;
    if (base == null || utilisateur == null) return false;
    final idApk = genererIdVisite();
    await _file(base).enfilerVisite(
      utilisateurId: utilisateur,
      idApk: idApk,
      corps: corpsVisite(visite, idApk: idApk),
      visiteLocaleId: visite.id,
    );
    await _actualiser();
    unawaited(declencher());
    return true;
  }

  /// Range une commande validée (corps de `POST /commandes/apk`, statut `VALIDEE`) dans la file et lance l'envoi.
  Future<bool> enfilerCommande(Map<String, Object?> corps) async {
    final base = _base;
    final utilisateur = _utilisateur;
    if (base == null || utilisateur == null) return false;
    await _file(base).enfilerCommande(utilisateurId: utilisateur, corps: corps);
    await _actualiser();
    unawaited(declencher());
    return true;
  }

  /// Range une écriture d'activité (note, appel, e-mail : voir `corps_activite.dart`) dans la file et lance l'envoi.
  /// Renvoie faux si la file n'est pas utilisable (démonstration, pas de base) : rien n'est envoyé.
  Future<bool> enfilerActivite(RequeteActivite r) async {
    final base = _base;
    final utilisateur = _utilisateur;
    if (base == null || utilisateur == null) return false;
    await _file(base).enfilerEcriture(
      utilisateurId: utilisateur,
      idApk: r.idApk,
      methode: 'POST',
      chemin: r.chemin,
      corps: r.corps,
      cible: r.cible,
      libelle: r.libelle,
    );
    await _actualiser();
    unawaited(declencher());
    return true;
  }

  /// Remet les entrées en erreur à envoyer et relance la file.
  Future<void> relancer() async {
    final base = _base;
    final utilisateur = _utilisateur;
    if (base == null || utilisateur == null) return;
    await base.relancerEnvoisEnErreur(utilisateur);
    _echecs = 0;
    await _actualiser();
    await declencher();
  }

  /// Vide la file maintenant. Sans effet si un passage est déjà en cours (il recommence alors une fois fini).
  Future<void> declencher() async {
    if (_enCours) {
      _relance = true;
      return;
    }
    final base = _base;
    final utilisateur = _utilisateur;
    if (base == null || utilisateur == null || !ref.mounted) return;
    _enCours = true;
    _minuterie?.cancel();
    try {
      do {
        _relance = false;
        state = state.avec(enCours: true);
        final r = await _file(base).vider(utilisateur);
        if (!ref.mounted) return;
        _apresEnvoi(r.envoyes);
        await _actualiser();
        switch (r.issue) {
          case IssueVidage.termine:
            _echecs = 0;
          case IssueVidage.reseau:
            _echecs++;
            _programmerReprise();
          case IssueVidage.sessionExpiree:
            // Retour à la connexion ; la file est gardée et repart à la prochaine connexion de ce compte.
            await ref.read(sessionProvider.notifier).deconnecter();
            return;
        }
        if (!ref.mounted) return;
        if (r.envoyes.isNotEmpty) _rafraichirApres(r.envoyes);
      } while (_relance && ref.mounted && _utilisateur == utilisateur);
    } finally {
      _enCours = false;
      if (ref.mounted) state = state.avec(enCours: false);
    }
  }

  void _programmerReprise() {
    _minuterie?.cancel();
    _minuterie = Timer(
      ref.read(delaiReessaiEnvoiProvider)(_echecs),
      () => unawaited(declencher()),
    );
  }

  /// Les visites envoyées passent en « Envoyée » dans la liste ; la fiche d'un client ou d'un prospect dont une note,
  /// un appel ou un e-mail vient de partir est relue (ainsi que le journal des appels et e-mails du client).
  void _apresEnvoi(List<EnvoiLocal> envoyes) {
    final store = ref.read(crmProvider.notifier);
    for (final e in envoyes) {
      final id = e.refLocale;
      if (e.type == TypeEnvoi.ecriture && id != null) {
        final cible = id.split(':');
        if (cible.length == 2) {
          if (cible[0] == CibleActivite.client.prefixe) {
            ref.invalidate(ficheClientProvider(cible[1]));
            ref.invalidate(journalContactsProvider(cible[1]));
          } else if (cible[0] == CibleActivite.prospect.prefixe) {
            ref.invalidate(detailProspectProvider(cible[1]));
          }
        }
        continue;
      }
      if (e.type != TypeEnvoi.visite || id == null) continue;
      final visite = ref.read(crmProvider).visiteParId(id);
      if (visite != null && visite.etat == EtatVisite.terminee) {
        store.majVisite(id, (v) => v.copyWith(etat: EtatVisite.envoyee));
      }
    }
  }

  /// Quand la file est vide, relit les visites, commandes et propositions PEM du CRM : ce qui vient de partir y figure.
  /// Pas pendant une visite ou une commande en cours de saisie : la relecture remet le store à zéro.
  void _rafraichirApres(List<EnvoiLocal> envoyes) {
    if (state.aEnvoyer > 0 || state.erreurs.isNotEmpty) return;
    final saisie =
        ref
            .read(crmProvider)
            .visites
            .any((v) => v.etat == EtatVisite.brouillon) ||
        ref.read(commandeEnCoursProvider) != null;
    if (saisie) return;
    final visites = envoyes.any((e) => e.type == TypeEnvoi.visite);
    final commandes = envoyes.any((e) => e.type == TypeEnvoi.commande);
    if (visites) {
      unawaited(ref.read(visitesSynchroProvider.notifier).rafraichir());
      // L'API marque « faite » la visite planifiée soldée : le planning relu ne la propose plus pour la suite.
      unawaited(ref.read(planningSynchroProvider.notifier).rafraichir());
      if (ref.read(sessionProvider)?.roleApi == 'COMMERCIAL') {
        unawaited(
          ref.read(propositionsPemSynchroProvider.notifier).rafraichir(),
        );
      }
    }
    if (commandes) {
      unawaited(ref.read(commandesProvider.notifier).rafraichir());
    }
  }
}

final envoiProvider = NotifierProvider<EnvoiNotifier, EtatFileEnvoi>(
  EnvoiNotifier.new,
);
