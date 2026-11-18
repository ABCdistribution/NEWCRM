import '../../../core/data/planning_serveur.dart';
import '../../../core/logic/logic.dart';
import 'equipe_demo.dart';

/// Une semaine du rapport d'un chef de secteur à partir du rapport du CRM (`GET /rapports/:userId`).
///
/// Les écarts sont ceux qui comptent pour le rapport : lignes retirées, déplacées, ajoutées et non réalisées ; les
/// lignes faites comme prévu ou encore à faire n'en sont pas.
SemaineCs semaineCsDepuisRapport(RapportEquipe r) {
  final e = r.ecarts;
  final courante = !r.lundi.isBefore(DemoTemps.lundi);
  final heure = r.valideAt == null
      ? null
      : '${DemoTemps.libelleJour(r.valideAt!)} à ${deuxChiffres(r.valideAt!.hour)}:${deuxChiffres(r.valideAt!.minute)}';
  return SemaineCs(
    n: DemoTemps.numeroSemaine(r.lundi),
    periode: DemoTemps.libellePeriodeSemaine(r.lundi),
    nonRenseignee: r.nonRenseignee,
    enCours: !r.valide && courante,
    nonValide: !r.valide && !courante,
    auto: r.valideAuto,
    prevues: e?.prevues,
    realisees: e?.realisees,
    pct: e?.pct,
    ecarts: [
      if (e != null)
        for (final l in e.lignes)
          if (l.genre != GenreEcart.fait && l.genre != GenreEcart.avenir) l,
    ],
    valide: heure,
    prevision: [
      for (final p in r.prevue ?? const [])
        LignePrevision(joursCourts[p.jour], p.heure, p.titre),
    ],
  );
}

/// Vrai quand le rapport n'a rien à montrer (aucune ligne prévue ni réalisée) : la carte est alors omise.
bool rapportVide(RapportEquipe r) => r.prevue == null && r.realisee.isEmpty;
