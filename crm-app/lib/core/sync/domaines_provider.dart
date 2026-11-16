import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/activite_serveur.dart';
import '../data/commandes_serveur.dart';
import '../data/equipe_serveur.dart';
import '../models/models.dart';
import '../data/prospects_serveur.dart';
import '../../features/catalogue/data/news_serveur.dart';
import '../db/app_database.dart';
import '../api/api_client.dart';
import 'catalogue_provider.dart';
import 'sync_domaine.dart';

/// Jeu de données secondaire gardé en JSON dans la base locale (commandes, visites, prospects…).
///
/// Même cycle que le catalogue et les clients : lecture locale immédiate, puis téléchargement depuis le CRM.
abstract class SynchroDomaineNotifier extends SynchroNotifier {
  /// Nom du jeu dans la base locale.
  String get domaine;

  @override
  String get cleMaj => AppDatabase.cleMajDomaine(domaine);

  /// Met les lignes lues à la disposition de l'application ; null retire les données réelles (démonstration).
  void appliquer(List<Map<String, dynamic>>? lignes);

  @override
  Future<int> lireBase(AppDatabase base) async {
    final lignes = lignesDecodees(await base.enregistrements(domaine));
    appliquer(lignes);
    return lignes.length;
  }

  @override
  void retirer() => appliquer(null);
}

/// Les 1 000 commandes les plus récentes des 60 derniers jours dans le périmètre de l'utilisateur
/// (`GET /commandes?mes=1`, triées de la plus récente à la plus ancienne par le serveur).
class CommandesNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'commandes';

  @override
  bool get refusTolere => true;

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) => definirCommandesServeur(
    lignes == null ? null : [for (final j in lignes) ?commandeDepuisJson(j)],
  );

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) {
    final depuis = DateTime.now().subtract(const Duration(days: 60));
    return SyncDomaine(api, base, domaine).telecharger(
      '/commandes',
      query: {
        'mes': '1',
        'dateDepuis':
            '${depuis.year}-${depuis.month.toString().padLeft(2, '0')}-${depuis.day.toString().padLeft(2, '0')}',
      },
      maxLignes: 1000,
      progression: progression,
    );
  }
}

final commandesProvider = NotifierProvider<CommandesNotifier, EtatSynchro>(
  CommandesNotifier.new,
);

/// Prospects du périmètre (`GET /prospects`) : chef de secteur, directeur régional, direction. Les autres rôles
/// reçoivent un refus, qui veut dire « aucun prospect ».
class ProspectsNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'prospects';

  @override
  bool get refusTolere => true;

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) => definirProspectsServeur(
    lignes == null ? null : [for (final j in lignes) ?prospectDepuisJson(j)],
  );

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) => SyncDomaine(
    api,
    base,
    domaine,
  ).telecharger('/prospects', progression: progression);
}

final prospectsSynchroProvider =
    NotifierProvider<ProspectsNotifier, EtatSynchro>(ProspectsNotifier.new);

/// Actualités du siège publiées (`GET /news`), visibles par tous les rôles.
class NewsNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'news';

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) => definirNewsServeur(
    lignes == null ? null : [for (final j in lignes) ?newsDepuisJson(j)],
  );

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) => SyncDomaine(api, base, domaine).telecharger(
    '/news',
    cleListe: 'items',
    cleTaille: 'pageSize',
    progression: progression,
  );
}

final newsProvider = NotifierProvider<NewsNotifier, EtatSynchro>(
  NewsNotifier.new,
);

/// Range une réponse unique de l'API (un objet, pas une liste) sous l'identifiant « courant ».
Future<int> _telechargerObjet(
  ApiLecture api,
  AppDatabase base,
  String domaine,
  String chemin, {
  Map<String, String>? query,
}) async {
  final reponse = await api.get(chemin, query: query);
  if (reponse is! Map<String, dynamic>) {
    throw const ErreurApi(TypeErreurApi.inattendue);
  }
  return SyncDomaine(api, base, domaine).enregistrer([
    {...reponse, 'id': 'courant'},
  ]);
}

Map<String, String> _moisCourant() {
  final n = DateTime.now();
  return {'annee': '${n.year}', 'mois': '${n.month}'};
}

/// Équipe du périmètre et activité du mois (`GET /dashboard/carte-equipes`) : chef de secteur, directeur régional,
/// direction. Les promoteurs reçoivent un refus, qui veut dire « pas d'équipe ».
class EquipeNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'equipe';

  @override
  bool get refusTolere => true;

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) {
    if (lignes == null) {
      definirEquipeServeur(null);
      return;
    }
    final equipe = lignes.isEmpty ? null : equipeDepuisJson(lignes.first);
    definirEquipeServeur(
      equipe ??
          const EquipeServeur(
            chefs: [],
            parChef: {},
            total: TotalObjectif(0, 0),
            visites: 0,
            commandes: 0,
          ),
    );
  }

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) => _telechargerObjet(
    api,
    base,
    domaine,
    '/dashboard/carte-equipes',
    query: _moisCourant(),
  );
}

final equipeProvider = NotifierProvider<EquipeNotifier, EtatSynchro>(
  EquipeNotifier.new,
);

/// Activité du mois du promoteur (`GET /performances/me`) : CA, objectif, visites. Seuls les promoteurs la demandent ;
/// l'encadrement lit les totaux de son équipe.
class PerformanceNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'performance';

  @override
  bool get refusTolere => true;

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) =>
      definirPerformanceServeur(
        lignes == null || lignes.isEmpty
            ? null
            : performanceDepuisJson(lignes.first),
      );

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) async {
    if (ref.read(sessionProvider)?.roleApi != 'COMMERCIAL') return 0;
    return _telechargerObjet(
      api,
      base,
      domaine,
      '/performances/me',
      query: _moisCourant(),
    );
  }
}

final performanceProvider = NotifierProvider<PerformanceNotifier, EtatSynchro>(
  PerformanceNotifier.new,
);

/// Notifications non lues de l'utilisateur (`GET /notifications/me`), affichées dans la cloche d'alertes.
class NotificationsNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'notifications';

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) {
    if (lignes == null) {
      definirNotificationsServeur(null);
      return;
    }
    final items = lignes.isEmpty ? null : lignes.first['items'];
    definirNotificationsServeur([
      if (items is List)
        for (final j in items.whereType<Map<String, dynamic>>())
          ?alerteDepuisNotification(j),
    ]);
  }

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) => _telechargerObjet(api, base, domaine, '/notifications/me');
}

final notificationsSynchroProvider =
    NotifierProvider<NotificationsNotifier, EtatSynchro>(
      NotificationsNotifier.new,
    );

/// Tous les jeux de données qui doivent être chargés avant l'ouverture de l'application, avec leur libellé.
final jeuxDeDonneesProvider = Provider<List<(String, EtatSynchro)>>(
  (ref) => [
    ('Catalogue', ref.watch(catalogueProvider)),
    ('Clients', ref.watch(clientsProvider)),
    ('Commandes', ref.watch(commandesProvider)),
    ('Prospects', ref.watch(prospectsSynchroProvider)),
    ('Actualités', ref.watch(newsProvider)),
    ('Équipe', ref.watch(equipeProvider)),
    ('Activité', ref.watch(performanceProvider)),
    ('Notifications', ref.watch(notificationsSynchroProvider)),
  ],
);

/// Relance le téléchargement de tous les jeux de données.
void rafraichirTout(WidgetRef ref) {
  ref.read(catalogueProvider.notifier).rafraichir();
  ref.read(clientsProvider.notifier).rafraichir();
  ref.read(commandesProvider.notifier).rafraichir();
  ref.read(prospectsSynchroProvider.notifier).rafraichir();
  ref.read(newsProvider.notifier).rafraichir();
  ref.read(equipeProvider.notifier).rafraichir();
  ref.read(performanceProvider.notifier).rafraichir();
  ref.read(notificationsSynchroProvider.notifier).rafraichir();
}
