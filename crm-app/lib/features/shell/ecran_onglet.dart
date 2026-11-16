import 'package:flutter/widgets.dart';

import '../../core/models/models.dart';
import '../../core/nav/onglets.dart';
import '../accueil/accueil_screen.dart';
import '../catalogue/catalogue_screen.dart';
import '../catalogue/news_screen.dart';
import '../clients/clients_screen.dart';
import '../commandes/commandes_screen.dart';
import '../equipe/equipe_screen.dart';
import '../equipe/secteur_screen.dart';
import '../planning/mes_rapports_screen.dart';
import '../planning/planning_screen.dart';
import '../prospects/prospects_screen.dart';
import '../visites/visites_screen.dart';

/// L'écran de chaque onglet. Chaque écran lit lui-même le rôle pour adapter son affichage.
Widget ecranPourOnglet(OngletApp onglet) => switch (onglet) {
  OngletApp.accueil => const AccueilScreen(),
  OngletApp.visites => const VisitesScreen(),
  OngletApp.commandes => const CommandesScreen(),
  OngletApp.clients => const ClientsScreen(),
  OngletApp.prospects => const ProspectsScreen(),
  OngletApp.planning => const PlanningScreen(),
  OngletApp.catalogue => const CatalogueScreen(),
  OngletApp.news => const NewsScreen(),
  OngletApp.rapports => const MesRapportsScreen(),
  OngletApp.equipe => const EquipeScreen(),
  OngletApp.secteurVisites => const SecteurScreen(genre: GenreSecteur.visites),
  OngletApp.secteurCommandes => const SecteurScreen(
    genre: GenreSecteur.commandes,
  ),
};
