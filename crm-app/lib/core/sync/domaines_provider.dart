import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/activite_serveur.dart';
import '../data/commandes_serveur.dart';
import '../data/equipe_serveur.dart';
import '../data/planning_serveur.dart';
import '../logic/dates.dart';
import '../models/models.dart';
import '../data/prospects_serveur.dart';
import '../data/visites_serveur.dart';
import '../../features/catalogue/data/news_serveur.dart';
import '../../features/commandes/logic/attente_crm.dart';
import '../db/base_provider.dart';
import '../db/app_database.dart';
import '../api/api_client.dart';
import 'catalogue_provider.dart';
import 'pages_api.dart';
import 'pem_provider.dart';
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

/// Commandes mises en attente par le promoteur dans le CRM (`GET /commandes/apk?statut=EN_ATTENTE`), avec leur détail
/// (lignes, e-mail du client) : lisibles hors connexion. Réservé au promoteur (COMMERCIAL), seul à pouvoir les modifier.
///
/// Écritures en direct : créer, modifier, valider, supprimer une commande en attente et l'envoyer par mail ; chaque
/// écriture met à jour la copie locale avec la réponse de l'API. Les visites terminées et les commandes validées sans
/// passer par l'attente partent par la file d'envoi (`core/envoi`).
class CommandesAttenteNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'commandes_attente';

  @override
  bool get refusTolere => true;

  /// Lignes JSON (détails de l'API) de la copie en mémoire.
  List<Map<String, dynamic>> _lignes = [];

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) {
    _lignes = lignes == null ? [] : List.of(lignes);
    definirAttentesServeur(
      lignes == null
          ? null
          : [for (final j in lignes) ?commandeAttenteDepuisJson(j)],
    );
  }

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) async {
    if (ref.read(sessionProvider)?.roleApi != 'COMMERCIAL') return 0;
    final liste = await lireToutesLesPages(
      api,
      '/commandes/apk',
      query: {'statut': 'EN_ATTENTE'},
      maxLignes: 200,
      progression: progression,
    );
    final ids = [
      for (final b in liste)
        if (b is Map<String, dynamic> && b['id'] is String) b['id'] as String,
    ];
    final details = <Object?>[];
    for (var i = 0; i < ids.length; i += 5) {
      details.addAll(
        await Future.wait([
          for (final id in ids.skip(i).take(5)) _detail(api, id),
        ]),
      );
    }
    return SyncDomaine(api, base, domaine).enregistrer(details);
  }

  /// Détail d'une commande ; null si elle a été supprimée ou validée entre la liste et le détail (404).
  static Future<Object?> _detail(ApiLecture api, String id) async {
    try {
      return await api.get(_chemin(id));
    } on ErreurApi catch (e) {
      if (e.statut == 404) return null;
      rethrow;
    }
  }

  AppDatabase? get _baseLocale {
    try {
      return ref.read(baseLocaleProvider);
    } catch (_) {
      return null;
    }
  }

  static String _chemin(String id) =>
      '/commandes/apk/${Uri.encodeComponent(id)}';

  /// Copie locale et liste affichée remises à jour après une écriture.
  void _publier() {
    if (!ref.mounted) return;
    appliquer(_lignes);
    state = state.avec(nb: _lignes.length);
  }

  /// Range le détail renvoyé par l'API ; renvoie la commande, ou lève [ErreurApi] si la réponse est illisible.
  Future<CommandeAttenteCrm> _memoriser(Object? detail) async {
    final commande = detail is Map<String, dynamic>
        ? commandeAttenteDepuisJson(detail)
        : null;
    if (commande == null) throw const ErreurApi(TypeErreurApi.inattendue);
    final json = detail as Map<String, dynamic>;
    _lignes = [
      for (final l in _lignes)
        if (l['id'] != commande.id) l,
      json,
    ];
    await _baseLocale?.ecrireEnregistrement(
      domaine,
      commande.id,
      jsonEncode(json),
    );
    _publier();
    return commande;
  }

  Future<void> _oublier(String id) async {
    _lignes = [
      for (final l in _lignes)
        if (l['id'] != id) l,
    ];
    await _baseLocale?.supprimerEnregistrement(domaine, id);
    _publier();
  }

  /// `POST /commandes/apk` (idempotent par `idCommandeApk`) puis lecture du détail.
  Future<CommandeAttenteCrm> creer(Map<String, Object?> corps) async {
    final r = await ref
        .read(apiEcritureProvider)
        .envoyer('POST', '/commandes/apk', corps: corps);
    final id = r is Map ? r['id'] : null;
    if (id is! String) throw const ErreurApi(TypeErreurApi.inattendue);
    return _memoriser(await ref.read(apiClientProvider).get(_chemin(id)));
  }

  /// `PATCH /commandes/apk/:id`.
  Future<CommandeAttenteCrm> modifier(
    String id,
    Map<String, Object?> corps,
  ) async => _memoriser(
    await ref
        .read(apiEcritureProvider)
        .envoyer('PATCH', _chemin(id), corps: corps),
  );

  /// `POST /commandes/apk/:id/valider` : la commande quitte la liste.
  Future<void> valider(String id) async {
    await ref
        .read(apiEcritureProvider)
        .envoyer('POST', '${_chemin(id)}/valider');
    await _oublier(id);
  }

  /// `DELETE /commandes/apk/:id` ; une commande déjà supprimée côté CRM (404) disparaît aussi de la liste.
  Future<void> supprimer(String id) async {
    try {
      await ref.read(apiEcritureProvider).envoyer('DELETE', _chemin(id));
    } on ErreurApi catch (e) {
      if (e.statut != 404) rethrow;
    }
    await _oublier(id);
  }

  /// `POST /commandes/apk/:id/envoyer-mail` : la commande reste en attente.
  Future<CommandeAttenteCrm> envoyerMail(String id, String email) async =>
      _memoriser(
        await ref
            .read(apiEcritureProvider)
            .envoyer(
              'POST',
              '${_chemin(id)}/envoyer-mail',
              corps: {'email': email},
            ),
      );
}

final commandesAttenteSynchroProvider =
    NotifierProvider<CommandesAttenteNotifier, EtatSynchro>(
      CommandesAttenteNotifier.new,
    );

/// Vrai pour un promoteur connecté : ses commandes en attente sont celles du CRM (sinon l'attente locale de démo).
final attenteCrmActiveProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider.select((u) => u?.roleApi)) == 'COMMERCIAL',
);

/// Commandes en attente du promoteur connecté, de la plus récente à la plus ancienne.
final attentesCrmProvider = Provider<List<CommandeAttenteCrm>>((ref) {
  ref.watch(commandesAttenteSynchroProvider);
  return trierAttentes(attentesServeur() ?? const []);
});

/// Visites des 60 derniers jours dans le périmètre de l'utilisateur (`GET /visites` : les siennes pour un promoteur,
/// celles de son équipe pour l'encadrement).
class VisitesNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'visites';

  @override
  bool get refusTolere => true;

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) {
    if (lignes == null) {
      definirVisitesServeur();
      return;
    }
    final moi = ref.read(sessionProvider);
    final r = visitesDepuisJson(
      lignes,
      moiId: moi?.id,
      moiNom: moi?.nomAffiche ?? '',
    );
    definirVisitesServeur(miennes: r.miennes, autres: r.autres);
  }

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) {
    final depuis = DateTime.now().subtract(const Duration(days: 60));
    return SyncDomaine(api, base, domaine).telecharger(
      '/visites',
      query: {
        'dateDepuis':
            '${depuis.year}-${depuis.month.toString().padLeft(2, '0')}-${depuis.day.toString().padLeft(2, '0')}',
      },
      maxLignes: 1500,
      cleTaille: 'limit',
      progression: progression,
    );
  }
}

final visitesSynchroProvider = NotifierProvider<VisitesNotifier, EtatSynchro>(
  VisitesNotifier.new,
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

/// Rôles API qui tiennent une tournée personnelle (`/tournees`) et ont un rapport d'activité hebdomadaire.
const _rolesTournee = {
  'CHEF_SECTEUR',
  'DIRECTEUR_REGIONAL',
  'DIRECTION',
  'ADMIN',
};

/// Planning de l'utilisateur sur quelques semaines autour de la semaine courante : ses visites planifiées pour un
/// promoteur (`GET /plannings`), sa tournée personnelle pour l'encadrement (`GET /tournees/me`).
class PlanningSynchroNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'planning';

  @override
  bool get refusTolere => true;

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) => definirPlanningServeur(
    lignes == null ? null : planningDepuisJson(lignes, DemoTemps.lundi),
  );

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) async {
    final moi = ref.read(sessionProvider);
    if (moi == null) return 0;
    final f = fenetrePlanning(DemoTemps.lundi);
    final String src;
    final Object? reponse;
    if (moi.roleApi == 'COMMERCIAL') {
      src = 'planning';
      reponse = await api.get(
        '/plannings',
        query: {'promoteurId': moi.id, 'debut': f.debut, 'fin': f.fin},
      );
    } else if (_rolesTournee.contains(moi.roleApi)) {
      src = 'tournee';
      reponse = await api.get(
        '/tournees/me',
        query: {'debut': f.debut, 'fin': f.fin},
      );
    } else {
      return 0;
    }
    if (reponse is! List) throw const ErreurApi(TypeErreurApi.inattendue);
    return SyncDomaine(api, base, domaine).enregistrer([
      for (final b in reponse)
        if (b is Map<String, dynamic>) {...b, '_src': src},
    ]);
  }
}

final planningSynchroProvider =
    NotifierProvider<PlanningSynchroNotifier, EtatSynchro>(
      PlanningSynchroNotifier.new,
    );

/// Rapport d'activité de la semaine courante et historique de « Mes rapports » (chef de secteur, directeur régional,
/// direction) : état de la semaine (`GET /tournees/semaine`), prévision enregistrée (`/tournees/semaine/prevue`) et
/// historique (`/tournees/historique`).
class RapportsSynchroNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'rapports';

  @override
  bool get refusTolere => true;

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) => definirRapportsServeur(
    lignes == null || lignes.isEmpty
        ? null
        : rapportsDepuisJson(lignes.first, DemoTemps.lundi),
  );

  @override
  Future<int> telecharger(
    ApiLecture api,
    AppDatabase base,
    void Function(int, int) progression,
  ) async {
    if (!_rolesTournee.contains(ref.read(sessionProvider)?.roleApi)) return 0;
    final lundi = isoJour(DemoTemps.lundi);
    final semaine = await api.get(
      '/tournees/semaine',
      query: {'semaine': lundi},
    );
    final prevue = await api.get(
      '/tournees/semaine/prevue',
      query: {'semaine': lundi},
    );
    final historique = await api.get('/tournees/historique');
    if (semaine is! Map<String, dynamic>) {
      throw const ErreurApi(TypeErreurApi.inattendue);
    }
    return SyncDomaine(api, base, domaine).enregistrer([
      {
        'id': 'courant',
        'semaine': semaine,
        'prevue': prevue,
        'historique': historique,
      },
    ]);
  }
}

final rapportsSynchroProvider =
    NotifierProvider<RapportsSynchroNotifier, EtatSynchro>(
      RapportsSynchroNotifier.new,
    );

/// Notifications non lues de l'utilisateur (`GET /notifications/me`), affichées dans la cloche d'alertes.
class NotificationsNotifier extends SynchroDomaineNotifier {
  @override
  String get domaine => 'notifications';

  /// Dernière boîte de réception connue (objet de l'API) : sert à retirer les notifications lues de la copie locale.
  Map<String, dynamic>? _courant;

  @override
  void appliquer(List<Map<String, dynamic>>? lignes) {
    if (lignes == null) {
      _courant = null;
      definirNotificationsServeur(null);
      return;
    }
    _courant = lignes.isEmpty ? null : lignes.first;
    final items = _courant?['items'];
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

  /// `PATCH /notifications/:id/lu` ; une notification déjà disparue du CRM (404) quitte aussi la liste.
  Future<void> marquerLue(String id) async {
    try {
      await ref
          .read(apiEcritureProvider)
          .envoyer('PATCH', '/notifications/${Uri.encodeComponent(id)}/lu');
    } on ErreurApi catch (e) {
      if (e.statut != 404) rethrow;
    }
    await _retirer({id});
  }

  /// `POST /notifications/lu-tout`.
  Future<void> toutMarquerLu() async {
    await ref
        .read(apiEcritureProvider)
        .envoyer('POST', '/notifications/lu-tout');
    await _retirer(null);
  }

  /// Marque comme lues (dans la copie locale et dans la cloche) les notifications `ids`, ou toutes si `ids` est nul.
  Future<void> _retirer(Set<String>? ids) async {
    final courant = _courant;
    if (courant == null || !ref.mounted) return;
    final items = courant['items'];
    final maintenant = DateTime.now().toUtc().toIso8601String();
    final mis = <String, dynamic>{
      ...courant,
      'items': [
        if (items is List)
          for (final j in items)
            if (j is Map<String, dynamic> &&
                j['luAt'] == null &&
                (ids == null || ids.contains(j['id'])))
              {...j, 'luAt': maintenant}
            else
              j,
      ],
    };
    try {
      await ref
          .read(baseLocaleProvider)
          .ecrireEnregistrement(domaine, 'courant', jsonEncode(mis));
    } catch (_) {
      // Sans base locale (tests, démonstration) la cloche est tout de même mise à jour.
    }
    if (!ref.mounted) return;
    appliquer([mis]);
    // La cloche se recalcule quand l'état de synchronisation change.
    state = state.avec(majLe: DateTime.now());
  }
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
    ('Visites', ref.watch(visitesSynchroProvider)),
    ('Prospects', ref.watch(prospectsSynchroProvider)),
    ('Actualités', ref.watch(newsProvider)),
    ('Équipe', ref.watch(equipeProvider)),
    ('Activité', ref.watch(performanceProvider)),
    ('Planning', ref.watch(planningSynchroProvider)),
    ('Rapports', ref.watch(rapportsSynchroProvider)),
    ('Notifications', ref.watch(notificationsSynchroProvider)),
  ],
);

/// Relance le téléchargement de tous les jeux de données.
void rafraichirTout(WidgetRef ref) {
  ref.read(catalogueProvider.notifier).rafraichir();
  ref.read(clientsProvider.notifier).rafraichir();
  ref.read(commandesProvider.notifier).rafraichir();
  ref.read(commandesAttenteSynchroProvider.notifier).rafraichir();
  ref.read(visitesSynchroProvider.notifier).rafraichir();
  ref.read(propositionsPemSynchroProvider.notifier).rafraichir();
  ref.read(prospectsSynchroProvider.notifier).rafraichir();
  ref.read(newsProvider.notifier).rafraichir();
  ref.read(equipeProvider.notifier).rafraichir();
  ref.read(performanceProvider.notifier).rafraichir();
  ref.read(planningSynchroProvider.notifier).rafraichir();
  ref.read(rapportsSynchroProvider.notifier).rafraichir();
  ref.read(notificationsSynchroProvider.notifier).rafraichir();
}
