import '../data/commandes_serveur.dart';
import '../data/visites_serveur.dart';
import '../data/data.dart';
import '../data/planning_serveur.dart';
import '../data/prospects_serveur.dart';
import '../logic/logic.dart';
import '../models/models.dart';

/// État partagé des entités métier d'un profil de démonstration (maquette : `S`).
///
/// Il est reconstruit à neuf à chaque changement de profil (`CrmEtat.initial`). Les écrans le lisent
/// via `crmProvider` et le modifient via `ref.read(crmProvider.notifier)`. Pour brancher l'API réelle,
/// c'est `CrmEtat.initial` (ou le notifier) qui change, pas les écrans.
/// Index d'un état, calculé une fois : les listes de clients comptent des milliers de lignes et les écrans cherchent
/// un client par id à chaque ligne affichée.
class _Index {
  _Index(CrmEtat e)
    : parId = {
        for (final liste in [autresClients, e.tousMagasins, e.magasins])
          for (final m in liste) m.id: m,
      },
      idsVisibles = {for (final m in e.magasins) m.id};

  final Map<String, Magasin> parId;
  final Set<String> idsVisibles;
  List<Commande>? commandesVisibles;
  List<Visite>? visitesAutresVisibles;
}

final Expando<_Index> _indexes = Expando<_Index>('CrmEtat');

class CrmEtat {
  const CrmEtat({
    required this.role,
    required this.magasins,
    required this.tousMagasins,
    required this.prospects,
    required this.etapes,
    required this.plansEquipe,
    required this.tournee,
    required this.visites,
    required this.visitesAutres,
    required this.commandes,
    required this.prochainNumVisite,
    this.planningFenetre = const [],
  });

  /// État initial du profil : même filtrage par périmètre que `etatInitial()` de la maquette.
  factory CrmEtat.initial(Role role) {
    final profil = role.profil;
    // Clients réels (déjà limités au périmètre du rôle par le CRM) : ils remplacent ceux de la démonstration, et les
    // étapes, tournées et visites de démo qui s'y rattachent disparaissent avec (aucun lien avec les vrais clients).
    final reels = clientsServeur();
    final magasins = reels ?? magasinsDemo.where((m) => visM(role, m)).toList();
    final tous =
        reels ??
        magasinsDemo
            .where((m) => role == Role.dir || m.secteurId == 's1')
            .toList();
    final prospects =
        prospectsServeur() ??
        prospectsDemo.where((p) => visP(role, p)).toList();
    final idsVisibles = {for (final m in magasins) m.id};
    bool visibleMag(String id) => idsVisibles.contains(id);
    final planning = planningServeur();
    final connecte = DemoTemps.reel;
    bool etapeVisible(EtapePlanning e) => switch (e.cible) {
      CiblePlanning.client => visibleMag(e.ref ?? ''),
      CiblePlanning.prospect => prospects.any((p) => p.id == e.ref),
      _ => true,
    };
    return CrmEtat(
      role: role,
      magasins: magasins,
      tousMagasins: tous,
      prospects: prospects,
      // Connecté : le planning est celui du CRM (vide tant qu'il n'est pas téléchargé), jamais celui de la démonstration.
      etapes: planning != null
          ? planning.semaineCourante
          : connecte
          ? const []
          : etapesDemo.where(etapeVisible).toList(),
      planningFenetre: planning?.etapes ?? const [],
      plansEquipe: connecte
          ? const {}
          : {
              for (final nom in nomsAvecPlanningEquipe())
                nom: planningInitialDe(nom, magasins),
            },
      tournee: planning != null
          ? planning.tournee
          : connecte
          ? const []
          : tourneeDemo.where((t) => visibleMag(t.magasinId)).toList(),
      // Visites réelles du CRM quand elles sont téléchargées ; sinon celles de la démonstration.
      visites:
          visitesMiennesServeur() ??
          visitesDuProfilDemo(
            profil.nom,
          ).where((v) => visibleMag(v.magasinId)).toList(),
      visitesAutres: visitesAutresServeur() ?? visitesAutresDemo,
      commandes: commandesServeur() ?? List.of(commandesDemo),
      prochainNumVisite: premierNumVisiteLibre,
    );
  }

  final Role role;

  /// Clients visibles du profil (`S.magasins`) : portefeuille du promoteur, secteur du chef de secteur, région du directeur.
  final List<Magasin> magasins;

  /// Clients du secteur ou de la région (`S.tousMag`) : sert à « Tous les clients du secteur ».
  final List<Magasin> tousMagasins;

  /// Prospects visibles (aucun pour le promoteur).
  final List<Prospect> prospects;

  /// Planning de la semaine du profil.
  final List<EtapePlanning> etapes;

  /// Planning réel sur toute la fenêtre téléchargée (semaines voisines comprises, `sem` = décalage de semaine) ;
  /// vide en démonstration.
  final List<EtapePlanning> planningFenetre;

  /// Plannings composés par l'encadrement pour un promoteur ou un autre chef de secteur, par nom court.
  /// Le planning de Nadia H. (chef de secteur de la démo) est `etapes`, voir `planDe`.
  final Map<String, List<EtapePlanning>> plansEquipe;

  /// Tournée du jour du promoteur.
  final List<TourneeVisite> tournee;

  /// Visites du profil (brouillons, à envoyer, envoyées), les plus récentes d'abord.
  final List<Visite> visites;

  /// Visites des autres promoteurs (lecture seule), toutes zones ; voir `visitesAutresVisibles`.
  final List<Visite> visitesAutres;

  /// Toutes les commandes, les plus récentes d'abord pour celles créées sur le téléphone.
  final List<Commande> commandes;

  /// Numéro de la prochaine visite créée.
  final int prochainNumVisite;

  /// Nom court du profil courant.
  String get nomProfil => role.profil.nom;

  // ---- Recherches par id -------------------------------------------------

  /// Client par id, dans le portefeuille, puis dans le secteur, puis dans les clients hors région (`getM`).
  Magasin? magasinParId(String id) => _index.parId[id];

  _Index get _index => _indexes[this] ??= _Index(this);

  /// Le client fait-il partie des clients visibles du profil ?
  bool aMagasin(String id) => _index.idsVisibles.contains(id);

  Prospect? prospectParId(String id) {
    for (final p in prospects) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Visite par id, parmi celles du profil puis celles des autres (`getV` et `cr`).
  Visite? visiteParId(String id) {
    for (final v in visites) {
      if (v.id == id) return v;
    }
    for (final v in visitesAutres) {
      if (v.id == id) return v;
    }
    return null;
  }

  Commande? commandeParId(String id) {
    for (final c in commandes) {
      if (c.id == id) return c;
    }
    return null;
  }

  EtapePlanning? etapeParId(String id) {
    for (final e in etapes) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ---- Vues filtrées par périmètre ---------------------------------------

  /// Commandes des clients visibles (`commandesVisibles`).
  List<Commande> get commandesVisibles => _index.commandesVisibles ??= commandes
      .where((c) => aMagasin(c.magasinId))
      .toList();

  /// Visites des autres promoteurs sur les clients visibles.
  List<Visite> get visitesAutresVisibles => _index.visitesAutresVisibles ??=
      visitesAutres.where((v) => aMagasin(v.magasinId)).toList();

  /// Planning d'un nom court : celui du profil si c'est Nadia H., sinon celui composé pour lui (`planOf`).
  List<EtapePlanning> planDe(String nom) => nom == profilsDemo[Role.cs]!.nom
      ? etapes
      : (plansEquipe[nom] ?? const []);

  CrmEtat copyWith({
    List<Magasin>? magasins,
    List<Magasin>? tousMagasins,
    List<Prospect>? prospects,
    List<EtapePlanning>? etapes,
    Map<String, List<EtapePlanning>>? plansEquipe,
    List<TourneeVisite>? tournee,
    List<Visite>? visites,
    List<Visite>? visitesAutres,
    List<Commande>? commandes,
    int? prochainNumVisite,
  }) {
    return CrmEtat(
      role: role,
      magasins: magasins ?? this.magasins,
      tousMagasins: tousMagasins ?? this.tousMagasins,
      prospects: prospects ?? this.prospects,
      etapes: etapes ?? this.etapes,
      planningFenetre: planningFenetre,
      plansEquipe: plansEquipe ?? this.plansEquipe,
      tournee: tournee ?? this.tournee,
      visites: visites ?? this.visites,
      visitesAutres: visitesAutres ?? this.visitesAutres,
      commandes: commandes ?? this.commandes,
      prochainNumVisite: prochainNumVisite ?? this.prochainNumVisite,
    );
  }
}
