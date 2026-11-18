/// État propre au lot planning : phase de la semaine, prévision enregistrée, détail des écarts ouvert
/// (maquette `S.phase`, `S.validee`, `S.prevu`, `S.ecartsOuverts`, `S.aVuPrevision`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data.dart';
import '../../../core/data/planning_serveur.dart';
import '../../../core/sync/domaines_provider.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/state/state.dart';
import '../data/rapports_demo.dart';
import '../logic/logique_planning.dart';

/// Phase de la semaine (`phaseEff`) : saisie de la prévision, rapport en cours, rapport validé (semaine verrouillée).
enum PhasePlanning { prevision, rapport, valide }

/// Prévision enregistrée et réglages d'affichage de la semaine du profil.
@immutable
class PlanningEtat {
  const PlanningEtat({
    required this.phase,
    required this.prevision,
    required this.ecartsOuverts,
    required this.previsionVue,
  });

  final PhasePlanning phase;

  /// Prévision enregistrée lundi (`S.prevu`) ; nulle quand elle n'a pas été renseignée.
  final List<EtapePlanning>? prevision;

  /// Détail « Prévu vs réalisé » déplié (`S.ecartsOuverts`).
  final bool ecartsOuverts;

  /// Une nouvelle semaine à prévoir a déjà été ouverte (`S.aVuPrevision`) : la prévision de démo ne revient plus.
  final bool previsionVue;

  /// Semaine verrouillée : plus aucune ligne n'est modifiable (`verrou`).
  bool get verrouillee => phase == PhasePlanning.valide;

  static const Object _inchange = Object();

  PlanningEtat copyWith({
    PhasePlanning? phase,
    Object? prevision = _inchange,
    bool? ecartsOuverts,
    bool? previsionVue,
  }) {
    return PlanningEtat(
      phase: phase ?? this.phase,
      prevision: identical(prevision, _inchange)
          ? this.prevision
          : prevision as List<EtapePlanning>?,
      ecartsOuverts: ecartsOuverts ?? this.ecartsOuverts,
      previsionVue: previsionVue ?? this.previsionVue,
    );
  }
}

/// Réglages de la semaine, réinitialisés à chaque changement de profil comme le store.
class PlanningNotifier extends Notifier<PlanningEtat> {
  late List<EtapePlanning> _previsionDemo;

  @override
  PlanningEtat build() {
    final initial = CrmEtat.initial(ref.watch(roleActifProvider));
    if (DemoTemps.reel) return _depuisServeur(initial);
    _previsionDemo = previsionDemo(
      initial.etapes,
      magasins: initial.magasins,
      prospects: initial.prospects,
    );
    return PlanningEtat(
      phase: PhasePlanning.rapport,
      prevision: _previsionDemo,
      ecartsOuverts: false,
      previsionVue: false,
    );
  }

  /// Phase et prévision de la semaine courante telles que le CRM les donne (`GET /tournees/semaine` et
  /// `/tournees/semaine/prevue`). Sans rapport téléchargé (promoteur, premier lancement) : rapport en cours, sans
  /// prévision.
  PlanningEtat _depuisServeur(CrmEtat initial) {
    ref.watch(rapportsSynchroProvider.select((e) => (e.nb, e.majLe)));
    ref.watch(planningSynchroProvider.select((e) => (e.nb, e.majLe)));
    _previsionDemo = const [];
    final r = rapportsServeur();
    final s = r?.semaine;
    final prevue = r?.prevue;
    return PlanningEtat(
      phase: s == null
          ? PhasePlanning.rapport
          : s.verrouillee
          ? PhasePlanning.valide
          : s.phaseRapport
          ? PhasePlanning.rapport
          : PhasePlanning.prevision,
      prevision: prevue == null
          ? null
          : rapprocherPrevue(prevue, initial.etapes),
      ecartsOuverts: false,
      previsionVue: true,
    );
  }

  /// Change de phase comme les boutons de la barre « Démo » de la maquette : une nouvelle semaine à prévoir vide la
  /// prévision ; sinon la prévision de démo revient tant qu'aucune semaine à prévoir n'a été ouverte.
  void choisirPhase(PhasePlanning phase) {
    if (phase == PhasePlanning.prevision) {
      state = state.copyWith(phase: phase, prevision: null, previsionVue: true);
    } else if (state.prevision == null && !state.previsionVue) {
      state = state.copyWith(phase: phase, prevision: _previsionDemo);
    } else {
      state = state.copyWith(phase: phase);
    }
  }

  /// Enregistre la prévision : une copie du planning, aucune ligne n'étant encore faite, détail des écarts ouvert.
  void enregistrerPrevision(List<EtapePlanning> etapes) {
    state = state.copyWith(
      prevision: [for (final e in etapes) e.copyWith(fait: false)],
      ecartsOuverts: true,
    );
  }

  /// Déplie ou replie le détail « Prévu vs réalisé » (`toggle-prevue`).
  void basculerEcarts() =>
      state = state.copyWith(ecartsOuverts: !state.ecartsOuverts);
}

final planningProvider = NotifierProvider<PlanningNotifier, PlanningEtat>(
  PlanningNotifier.new,
);

/// Comparaison prévision enregistrée / planning du profil (`calcEcarts`), nulle sans prévision.
final ecartsSemaineProvider = Provider<ResultatEcarts?>((ref) {
  final plan = ref.watch(planningProvider);
  return calculerEcarts(
    prevu: plan.prevision,
    etapes: ref.watch(etapesProvider),
    valide: plan.verrouillee,
  );
});

/// Rapports précédents de « Mes rapports » : les semaines 44 à 41, précédées de la semaine 45 quand elle est validée.
final rapportsPrecedentsProvider = Provider<List<RapportSemaine>>((ref) {
  if (DemoTemps.reel) {
    ref.watch(rapportsSynchroProvider.select((e) => (e.nb, e.majLe)));
    return rapportsReels(rapportsServeur());
  }
  final plan = ref.watch(planningProvider);
  if (!plan.verrouillee) return rapportsDemo;
  return [
    rapportSemaineEnCours(
      etapes: ref.watch(etapesProvider),
      prevision: plan.prevision,
      ecarts: ref.watch(ecartsSemaineProvider),
    ),
    ...rapportsDemo,
  ];
});

/// Semaine affichée par « Mon planning » : décalage par rapport à la semaine courante (0 = courante). La navigation
/// entre semaines n'existe que connecté ; la démonstration reste sur la semaine 45.
class SemainePlanningNotifier extends Notifier<int> {
  /// Semaines proposées avant et après la semaine courante : celles que la synchronisation télécharge.
  static const int avant = 3;
  static const int apres = 5;

  @override
  int build() {
    ref.watch(roleActifProvider);
    return 0;
  }

  void decaler(int delta) => state = (state + delta).clamp(-avant, apres);

  void aujourdhui() => state = 0;
}

final semainePlanningProvider =
    NotifierProvider<SemainePlanningNotifier, int>(SemainePlanningNotifier.new);
