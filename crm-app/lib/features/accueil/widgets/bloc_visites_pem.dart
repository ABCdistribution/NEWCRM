import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/nav/nav.dart';
import '../../../core/state/state.dart';
import '../../../core/sync/pem_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import 'feuille_pem.dart';

/// Rubrique « Visites PEM » de l'accueil du promoteur : une carte par proposition ouverte. Rien n'est affiché sans
/// proposition. Une proposition dont la visite est déjà faite sur le téléphone n'y figure plus (elle est dans « Visites »).
class BlocVisitesPem extends ConsumerWidget {
  const BlocVisitesPem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(crmProvider);
    final cartes = <(PropositionPem, bool)>[];
    for (final p in ref.watch(propositionsPemProvider)) {
      final v = visitePemDe(etat.visites, p.id);
      if (v == null) {
        cartes.add((p, false));
      } else if (v.etat == EtatVisite.brouillon) {
        cartes.add((p, true));
      }
    }
    if (cartes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TitreLigne('Visites PEM', taille: 16, margeHaut: 18),
        for (final (p, brouillon) in cartes)
          _CartePem(
            proposition: p,
            nomClient: etat.magasinParId(p.clientId)?.nom ?? p.clientNom,
            classe: etat.classeMagasin(p.clientId).isEmpty
                ? p.clientClasse
                : etat.classeMagasin(p.clientId),
            brouillon: brouillon,
          ),
      ],
    );
  }
}

class _CartePem extends StatelessWidget {
  const _CartePem({
    required this.proposition,
    required this.nomClient,
    required this.classe,
    required this.brouillon,
  });

  final PropositionPem proposition;
  final String nomClient;
  final String classe;

  /// Une visite PEM de cette proposition est déjà commencée sur le téléphone.
  final bool brouillon;

  Future<void> _traiter(BuildContext context, {required bool report}) async {
    final p = proposition;
    final r = report
        ? await ouvrirReporterPem(context, p, nomClient)
        : await ouvrirAccepterPem(context, p, nomClient);
    if (r == null || !context.mounted) return;
    // Le libellé d'une date finit déjà par un point quand le mois est abrégé (« 9 nov. »).
    final date = libelleDatePem(
      r.dateProposee,
    ).replaceFirst(RegExp(r'\.$'), '');
    AppToast.show(
      context,
      report
          ? (r.obligatoire
                ? 'Visite PEM reportée au $date. Elle est maintenant obligatoire.'
                : 'Visite PEM reportée au $date.')
          : 'Visite PEM acceptée pour le $date.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = proposition;
    final acceptee = p.statut == StatutPem.acceptee;
    return AppCarte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppLigne(
            alignement: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NomMagasin(nomClient, classe: classe),
                    const SizedBox(height: 3),
                    Text(
                      '${acceptee ? 'Prévue le' : 'Proposée pour le'} ${libelleDatePem(p.dateProposee)}',
                      style: AppText.sousCarte,
                    ),
                  ],
                ),
              ),
              if (p.obligatoire)
                const Pastille('Obligatoire', variante: VariantePastille.rouge)
              else if (!acceptee)
                Pastille(libelleReports(p), variante: VariantePastille.jaune),
            ],
          ),
          const SizedBox(height: 12),
          if (acceptee)
            AppBouton(
              brouillon ? 'Reprendre la visite PEM' : 'Démarrer la visite PEM',
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: () =>
                  AppRoutes.demarrerVisitePem(context, p.clientId, p.id),
            )
          else
            Rangee(
              children: [
                AppBouton(
                  'Accepter',
                  petit: true,
                  variante: VarianteBouton.plein,
                  onPressed: () => _traiter(context, report: false),
                ),
                if (p.reportable)
                  AppBouton(
                    'Reporter',
                    petit: true,
                    variante: VarianteBouton.clair,
                    onPressed: () => _traiter(context, report: true),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
