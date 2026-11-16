/// État propre au lot « équipe » : filtres de « Mon équipe », des listes du secteur et des semaines d'un chef de secteur.
///
/// Comme `S` dans la maquette, chaque filtre garde sa valeur d'un écran à l'autre et retrouve sa valeur par défaut à
/// chaque changement de profil.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/state/state.dart';
import '../data/equipe_demo.dart';
import 'filtres.dart';

/// Filtres de l'onglet « Mon équipe » du directeur (`S.eqf`).
class FiltresEquipeNotifier extends Notifier<FiltresEquipe> {
  @override
  FiltresEquipe build() {
    ref.watch(roleActifProvider);
    return const FiltresEquipe();
  }

  void maj(FiltresEquipe Function(FiltresEquipe) f) => state = f(state);

  /// « Réinitialiser » (`eq-reset`).
  void reinitialiser() => state = const FiltresEquipe();
}

final filtresEquipeProvider =
    NotifierProvider<FiltresEquipeNotifier, FiltresEquipe>(
      FiltresEquipeNotifier.new,
    );

/// Filtres des visites et des commandes du secteur (`S.sec`).
class FiltresSecteurNotifier extends Notifier<FiltresSecteur> {
  @override
  FiltresSecteur build() {
    ref.watch(roleActifProvider);
    return const FiltresSecteur();
  }

  void maj(GenreSecteur genre, FiltreSecteur Function(FiltreSecteur) f) =>
      state = state.avec(genre, f(state.de(genre)));

  /// « Réinitialiser » (`sec-reset`) : ne touche qu'à la liste du genre.
  void reinitialiser(GenreSecteur genre) =>
      state = state.avec(genre, const FiltreSecteur());
}

final filtresSecteurProvider =
    NotifierProvider<FiltresSecteurNotifier, FiltresSecteur>(
      FiltresSecteurNotifier.new,
    );

/// Filtre des semaines d'un chef de secteur (`S.csFiltre`) ; revient à « Toutes les semaines » à l'ouverture de la
/// page d'un chef de secteur (action `equipe-cs`).
class FiltreSemainesNotifier extends Notifier<FiltreSemaines> {
  @override
  FiltreSemaines build() {
    ref.watch(roleActifProvider);
    return FiltreSemaines.toutes;
  }

  void choisir(FiltreSemaines f) => state = f;
}

final filtreSemainesProvider =
    NotifierProvider<FiltreSemainesNotifier, FiltreSemaines>(
      FiltreSemainesNotifier.new,
    );
