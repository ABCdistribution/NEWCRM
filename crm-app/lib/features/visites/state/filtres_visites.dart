import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/state/state.dart';

/// Quelles visites afficher : les miennes ou toutes celles du périmètre (`vf.portee`).
enum PorteeVisites { mes, toutes }

/// Fenêtre de dates des visites (`vf.periode`) : toutes, aujourd'hui ou les 7 derniers jours.
enum PeriodeVisites {
  toutes('Toutes les dates'),
  jour("Aujourd'hui"),
  semaine('7 derniers jours');

  const PeriodeVisites(this.libelle);
  final String libelle;
}

/// Filtres de la liste des visites (maquette : `S.vf = { q, portee, etat, periode }`).
class FiltresVisites {
  const FiltresVisites({
    this.q = '',
    this.portee = PorteeVisites.mes,
    this.etat,
    this.periode = PeriodeVisites.toutes,
  });

  /// Texte recherché dans « client + promoteur ».
  final String q;
  final PorteeVisites portee;

  /// Nul = « Tous les états ».
  final EtatVisite? etat;
  final PeriodeVisites periode;

  /// Nombre de filtres actifs, affiché sur le bouton de filtres (`nbF`) ; la recherche n'en fait pas partie.
  int get nbActifs =>
      (portee != PorteeVisites.mes ? 1 : 0) +
      (etat != null ? 1 : 0) +
      (periode != PeriodeVisites.toutes ? 1 : 0);

  FiltresVisites avecRecherche(String texte) =>
      FiltresVisites(q: texte, portee: portee, etat: etat, periode: periode);

  FiltresVisites avecPortee(PorteeVisites p) =>
      FiltresVisites(q: q, portee: p, etat: etat, periode: periode);

  FiltresVisites avecEtat(EtatVisite? e) =>
      FiltresVisites(q: q, portee: portee, etat: e, periode: periode);

  FiltresVisites avecPeriode(PeriodeVisites p) =>
      FiltresVisites(q: q, portee: portee, etat: etat, periode: p);

  /// Réinitialisation de la feuille : la recherche est conservée (`vf-reset`).
  FiltresVisites reinitialises() => FiltresVisites(q: q);
}

/// Filtres de la liste des visites ; ils reviennent à zéro quand le profil change.
class FiltresVisitesNotifier extends Notifier<FiltresVisites> {
  @override
  FiltresVisites build() {
    ref.watch(roleActifProvider);
    return const FiltresVisites();
  }

  void maj(FiltresVisites Function(FiltresVisites f) transformer) =>
      state = transformer(state);
}

final filtresVisitesProvider =
    NotifierProvider<FiltresVisitesNotifier, FiltresVisites>(
      FiltresVisitesNotifier.new,
    );
