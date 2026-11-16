import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role.dart';
import '../state/profil_state.dart';
import '../ui/app_icons.dart';

/// Tous les onglets de l'application (écrans de premier niveau, affichés avec la barre de navigation).
enum OngletApp {
  accueil('Accueil', AppIcons.accueil),
  visites('Visites', AppIcons.pin),
  commandes('Commandes', AppIcons.doc),
  clients('Clients', AppIcons.magasin),
  prospects('Prospects', AppIcons.cible),
  planning('Planning', AppIcons.pin),
  catalogue('Catalogue', AppIcons.cible),
  news('News', AppIcons.doc),
  rapports('Mes rapports', AppIcons.doc),
  equipe('Équipe', AppIcons.equipe),

  /// Visites et commandes du secteur (encadrement) : écrans de l'équipe, distincts des listes du promoteur.
  secteurVisites('Visites', AppIcons.pin),
  secteurCommandes('Commandes', AppIcons.doc);

  const OngletApp(this.libelle, this.icone);

  /// Libellé dans la barre de navigation ou le menu « + ».
  final String libelle;

  /// Icône SVG (`AppIcons`).
  final String icone;
}

/// Contenu de la barre de navigation d'un rôle : onglets directs et menu « + » (`dropup`).
class ConfigNav {
  const ConfigNav({required this.barre, required this.plus});
  final List<OngletApp> barre;
  final List<OngletApp> plus;
}

/// Barre de navigation exacte de la maquette (l.562-581).
ConfigNav configNavPour(Role role) => switch (role) {
  Role.promoteur => const ConfigNav(
    barre: [
      OngletApp.accueil,
      OngletApp.visites,
      OngletApp.commandes,
      OngletApp.clients,
      OngletApp.planning,
    ],
    plus: [OngletApp.catalogue, OngletApp.news],
  ),
  Role.cs => const ConfigNav(
    barre: [
      OngletApp.accueil,
      OngletApp.clients,
      OngletApp.prospects,
      OngletApp.planning,
    ],
    plus: [
      OngletApp.secteurVisites,
      OngletApp.secteurCommandes,
      OngletApp.catalogue,
      OngletApp.news,
      OngletApp.rapports,
      OngletApp.equipe,
    ],
  ),
  Role.dir => const ConfigNav(
    barre: [
      OngletApp.accueil,
      OngletApp.clients,
      OngletApp.prospects,
      OngletApp.planning,
    ],
    plus: [
      OngletApp.catalogue,
      OngletApp.news,
      OngletApp.rapports,
      OngletApp.equipe,
    ],
  ),
};

/// Onglet affiché. Revient à l'accueil à chaque changement de profil.
class OngletNotifier extends Notifier<OngletApp> {
  @override
  OngletApp build() {
    ref.watch(roleActifProvider);
    return OngletApp.accueil;
  }

  void aller(OngletApp onglet) => state = onglet;
}

final ongletProvider = NotifierProvider<OngletNotifier, OngletApp>(
  OngletNotifier.new,
);

/// Menu « + » (dropup) ouvert ou fermé.
class MenuPlusNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(roleActifProvider);
    return false;
  }

  void basculer() => state = !state;
  void fermer() => state = false;
}

final menuPlusOuvertProvider = NotifierProvider<MenuPlusNotifier, bool>(
  MenuPlusNotifier.new,
);
