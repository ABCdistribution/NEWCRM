import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logic/logic.dart';
import '../../core/sync/planning_equipe_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/rapports_demo.dart';
import 'state/planning_state.dart';
import 'widgets/ecarts_liste.dart';

/// Ouvre la feuille « Détail du rapport ». Maquette : modale `rapport-detail` l.1839-1844.
/// Appelée par `AppRoutes.detailRapport(context, numSemaine)`.
Future<void> ouvrirDetailRapport(BuildContext context, int numSemaine) =>
    showAppSheet<void>(
      context,
      builder: (_) => RapportDetailSheet(numSemaine: numSemaine),
    );

/// Feuille « Détail du rapport » : titre « Semaine 45 · 2 – 6 novembre », « Prévu N · Réalisé N (x %) » en violet,
/// puis la liste des écarts (ou « Aucun écart : tout s'est passé comme prévu. »).
///
/// La semaine 45 montre la comparaison en direct de la prévision et du planning ; les semaines 44 à 41 leur rapport.
class RapportDetailSheet extends ConsumerWidget {
  const RapportDetailSheet({super.key, required this.numSemaine});

  /// Numéro de la semaine (45 = en cours, 44 à 41 = validées).
  final int numSemaine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = context.univers;
    final enCours = numSemaine == DemoTemps.semaineCourante;
    final ecarts = ref.watch(ecartsSemaineProvider);
    final String titre;
    final String? chiffres;
    final Widget liste;
    if (enCours) {
      titre = 'Semaine $numSemaine · ${DemoTemps.semaineLibelle}';
      if (ecarts != null) {
        chiffres =
            'Prévu ${ecarts.prevues} · Réalisé ${ecarts.realisees} (${ecarts.pct} %)';
        liste = EcartsListe(ecarts.lignes);
      } else {
        chiffres = null;
        liste = const Vide(
          "Prévision non renseignée cette semaine : il n'y a pas de comparaison possible.",
        );
      }
    } else if (DemoTemps.reel) {
      // Rapport d'une semaine passée du CRM : prévision et tournée réalisée chargées à l'ouverture.
      final r = ref
          .watch(rapportsPrecedentsProvider)
          .where((x) => x.numero == numSemaine)
          .firstOrNull;
      if (r == null || r.lundi == null) {
        titre = 'Semaine $numSemaine';
        chiffres = null;
        liste = const Vide('Aucun rapport pour cette semaine.');
      } else {
        titre = 'Semaine ${r.numero} · ${r.periode}';
        final detail = ref.watch(rapportPersonnelProvider(r.lundi!));
        final e = detail.value?.ecarts;
        if (detail.value == null) {
          chiffres = null;
          liste = Vide(
            detail.isLoading
                ? 'Chargement du rapport…'
                : 'Rapport indisponible : réseau coupé et aucune copie locale.',
          );
        } else if (e == null) {
          chiffres = null;
          liste = const Vide(
            "Prévision non renseignée cette semaine : il n'y a pas de comparaison possible.",
          );
        } else {
          chiffres = 'Prévu ${e.prevues} · Réalisé ${e.realisees} (${e.pct} %)';
          liste = EcartsListe(e.lignes);
        }
      }
    } else {
      final r = rapportsDemo.where((x) => x.numero == numSemaine).firstOrNull;
      if (r == null) {
        titre = 'Semaine $numSemaine';
        chiffres = null;
        liste = const Vide('Aucun rapport pour cette semaine.');
      } else {
        titre = 'Semaine ${r.numero} · ${r.periode}';
        chiffres = 'Prévu ${r.prevues} · Réalisé ${r.visites} (${r.pct} %)';
        liste = r.ecarts.isEmpty
            ? const Vide("Aucun écart : tout s'est passé comme prévu.")
            : EcartsListe(r.ecarts);
      }
    }
    return FeuilleBase(
      titre: titre,
      children: [
        if (chiffres != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              chiffres,
              style: AppText.t(16, w: FontWeight.w700, c: u.violet),
            ),
          ),
        liste,
      ],
    );
  }
}
