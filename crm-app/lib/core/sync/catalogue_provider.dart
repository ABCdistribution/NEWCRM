import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/data.dart';
import '../data/magasins_serveur.dart';
import '../data/produits_serveur.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import 'sync_catalogue.dart';
import 'sync_clients.dart';

/// Où en est le téléchargement d'un jeu de données (catalogue, clients).
enum PhaseSynchro {
  /// Mode démonstration (pas de session) : les données de la maquette servent.
  demo,

  /// Téléchargement en cours (avec ou sans données déjà en base).
  chargement,

  /// À jour.
  ok,

  /// Serveur injoignable : on garde la dernière copie locale.
  horsLigne,

  /// Échec autre que le réseau.
  erreur,
}

class EtatSynchro {
  const EtatSynchro({
    this.phase = PhaseSynchro.demo,
    this.nb = 0,
    this.majLe,
    this.message,
    this.recus = 0,
    this.total = 0,
  });

  final PhaseSynchro phase;

  /// Nombre de lignes en base locale.
  final int nb;

  /// Date du dernier téléchargement réussi (heure locale).
  final DateTime? majLe;
  final String? message;

  /// Progression du téléchargement en cours : lignes reçues sur total annoncé par le serveur.
  final int recus;
  final int total;

  /// Vrai tant qu'il n'y a aucune donnée locale à afficher : premier téléchargement en cours, ou échec sans copie.
  /// L'application affiche alors l'écran de chargement au lieu de s'ouvrir sur des données vides.
  bool get bloquant =>
      nb == 0 &&
      majLe == null &&
      (phase == PhaseSynchro.chargement ||
          phase == PhaseSynchro.horsLigne ||
          phase == PhaseSynchro.erreur);

  EtatSynchro avec({
    PhaseSynchro? phase,
    int? nb,
    DateTime? majLe,
    String? message,
    int? recus,
    int? total,
  }) => EtatSynchro(
    phase: phase ?? this.phase,
    nb: nb ?? this.nb,
    majLe: majLe ?? this.majLe,
    message: message,
    recus: recus ?? this.recus,
    total: total ?? this.total,
  );
}

final apiClientProvider = Provider<ApiLecture>(
  (ref) => ApiClient(jeton: () => ref.read(stockageSessionProvider).jeton()),
);

/// Écritures JSON sur l'API : commandes, visites (file d'envoi), propositions PEM, notifications.
final apiEcritureProvider = Provider<ApiEcriture>(
  (ref) => ApiClient(jeton: () => ref.read(stockageSessionProvider).jeton()),
);

/// Envoi de fichiers à l'API : les photos des visites (file d'envoi).
final apiFichiersProvider = Provider<ApiFichiers>(
  (ref) => ApiClient(jeton: () => ref.read(stockageSessionProvider).jeton()),
);

/// Jeu de données réel : lu d'abord dans la base locale (instantané, hors connexion), puis rafraîchi depuis le CRM.
///
/// Actif seulement avec une session (utilisateur connecté) ; en démonstration les données de la maquette servent.
/// Une session expirée ramène à la connexion ; le réseau coupé garde la copie locale.
abstract class SynchroNotifier extends Notifier<EtatSynchro> {
  /// Clé de métadonnée de la date du dernier téléchargement.
  String get cleMaj;

  /// Lit la base locale et met les données à disposition de l'application ; renvoie le nombre de lignes.
  Future<int> lireBase(AppDatabase base);

  /// Retire les données réelles (retour à la démonstration).
  void retirer();

  /// Vrai pour un jeu réservé à certains rôles : un refus (403) veut dire « rien à voir », pas une panne.
  bool get refusTolere => false;

  /// Télécharge depuis le CRM et enregistre dans la base ; renvoie le nombre de lignes.
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int recus, int total) progression,
  );

  @override
  EtatSynchro build() {
    final utilisateur = ref.watch(sessionProvider);
    if (utilisateur == null) {
      retirer();
      return const EtatSynchro();
    }
    Future.microtask(_demarrer);
    return const EtatSynchro(phase: PhaseSynchro.chargement);
  }

  /// Base locale, ou null quand elle n'est pas fournie (tests sans base).
  AppDatabase? get _base {
    try {
      return ref.read(baseLocaleProvider);
    } catch (_) {
      return null;
    }
  }

  Future<void> _demarrer() async {
    final base = _base;
    if (base == null) {
      state = const EtatSynchro();
      return;
    }
    await _lire(base);
    await rafraichir();
  }

  Future<void> _lire(AppDatabase base) async {
    final nb = await lireBase(base);
    final maj = await base.meta(cleMaj);
    if (!ref.mounted) return;
    state = state.avec(
      nb: nb,
      majLe: maj == null ? null : DateTime.tryParse(maj)?.toLocal(),
    );
  }

  /// Télécharge depuis le CRM. Le réseau coupé garde la copie locale ; une session expirée ramène à la connexion.
  Future<void> rafraichir() async {
    final base = _base;
    if (base == null || ref.read(sessionProvider) == null) return;
    state = state.avec(phase: PhaseSynchro.chargement);
    try {
      await telecharger(ref.read(apiClientProvider), base, (recus, total) {
        if (ref.mounted) state = state.avec(recus: recus, total: total);
      });
      await _lire(base);
      if (ref.mounted) state = state.avec(phase: PhaseSynchro.ok);
    } on ErreurApi catch (e) {
      if (!ref.mounted) return;
      switch (e.type) {
        case TypeErreurApi.reseau:
          state = state.avec(phase: PhaseSynchro.horsLigne);
        case TypeErreurApi.sessionExpiree:
          await ref.read(sessionProvider.notifier).deconnecter();
        case TypeErreurApi.refuse when refusTolere:
          state = state.avec(phase: PhaseSynchro.ok);
        default:
          state = state.avec(phase: PhaseSynchro.erreur, message: e.message);
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.avec(
          phase: PhaseSynchro.erreur,
          message: const ErreurApi(TypeErreurApi.inattendue).message,
        );
      }
    }
  }
}

/// Catalogue produits (`GET /articles`).
class CatalogueNotifier extends SynchroNotifier {
  @override
  String get cleMaj => AppDatabase.cleCatalogueMajLe;

  @override
  Future<int> lireBase(AppDatabase base) async {
    final lignes = await base.tousLesArticles();
    if (lignes.isNotEmpty) {
      definirCatalogueServeur(lignes.map(produitDepuisArticle).toList());
    }
    return lignes.length;
  }

  @override
  void retirer() => definirCatalogueServeur(null);

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) => SyncCatalogue(api, base).telecharger(progression: progression);
}

/// Clients du périmètre de l'utilisateur (`GET /clients?mes=1`).
class ClientsNotifier extends SynchroNotifier {
  @override
  String get cleMaj => AppDatabase.cleClientsMajLe;

  @override
  Future<int> lireBase(AppDatabase base) async {
    // Une copie locale d'avant ce réglage peut contenir des clients inactifs : on ne les expose pas.
    final lignes = (await base.tousLesClients()).where((c) => c.actif).toList();
    definirClientsServeur(
      lignes.isEmpty ? null : lignes.map(magasinDepuisClient).toList(),
    );
    return lignes.length;
  }

  @override
  void retirer() => definirClientsServeur(null);

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) => SyncClients(api, base).telecharger(progression: progression);
}

final catalogueProvider = NotifierProvider<CatalogueNotifier, EtatSynchro>(
  CatalogueNotifier.new,
);

final clientsProvider = NotifierProvider<ClientsNotifier, EtatSynchro>(
  ClientsNotifier.new,
);

/// L'utilisateur a choisi de continuer sans données (premier téléchargement impossible : pas de réseau).
class ContinuerSansDonneesNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(
      sessionProvider,
    ); // revient à faux à chaque connexion / déconnexion
    return false;
  }

  void continuer() => state = true;
}

final continuerSansDonneesProvider =
    NotifierProvider<ContinuerSansDonneesNotifier, bool>(
      ContinuerSansDonneesNotifier.new,
    );
