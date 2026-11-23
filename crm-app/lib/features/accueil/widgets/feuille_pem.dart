import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/erreur_api.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/sync/pem_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';
import '../../commandes/widgets/champ_date.dart';

/// Ouvre la feuille « Accepter la visite PEM » : date de la visite (aujourd'hui à +14 jours), proposée par défaut.
/// Renvoie la proposition mise à jour par le CRM, ou nul si la feuille est fermée sans valider.
Future<PropositionPem?> ouvrirAccepterPem(
  BuildContext context,
  PropositionPem proposition,
  String nomClient,
) => showAppSheet<PropositionPem>(
  context,
  builder: (_) =>
      FeuillePem(proposition: proposition, nomClient: nomClient, report: false),
);

/// Ouvre la feuille « Reporter la visite PEM » : motif facultatif et nouvelle date (demain à +14 jours), dans une
/// semaine par défaut. Renvoie la proposition mise à jour par le CRM, ou nul si la feuille est fermée sans valider.
Future<PropositionPem?> ouvrirReporterPem(
  BuildContext context,
  PropositionPem proposition,
  String nomClient,
) => showAppSheet<PropositionPem>(
  context,
  builder: (_) =>
      FeuillePem(proposition: proposition, nomClient: nomClient, report: true),
);

/// Feuille d'acceptation ou de report d'une visite PEM. L'appel à l'API se fait ici : en cas d'échec, le message de
/// l'API s'affiche et la feuille reste ouverte.
class FeuillePem extends ConsumerStatefulWidget {
  const FeuillePem({
    super.key,
    required this.proposition,
    required this.nomClient,
    required this.report,
  });

  final PropositionPem proposition;
  final String nomClient;

  /// Vrai pour un report, faux pour une acceptation.
  final bool report;

  @override
  ConsumerState<FeuillePem> createState() => _FeuillePemState();
}

class _FeuillePemState extends ConsumerState<FeuillePem> {
  late final FenetreDates _fenetre = widget.report
      ? fenetreReport(DemoTemps.aujourdhui)
      : fenetreAcceptation(DemoTemps.aujourdhui);

  /// Date choisie (`aaaa-mm-jj`) : la date proposée si elle est acceptable, sinon aujourd'hui ; un report part à +7 jours.
  late String _date = widget.report
      ? jourIso(dateReportParDefaut(DemoTemps.aujourdhui))
      : dateProposeeAcceptable(widget.proposition, DemoTemps.aujourdhui)
      ? widget.proposition.dateProposee
      : jourIso(DemoTemps.aujourdhui);

  String _motif = '';
  bool _occupe = false;

  Future<void> _valider() async {
    if (_occupe) return;
    setState(() => _occupe = true);
    try {
      final actions = ref.read(actionsPemProvider);
      final id = widget.proposition.id;
      final resultat = widget.report
          ? await actions.reporter(id, motif: _motif, date: _date)
          : await actions.accepter(id, date: _date);
      if (mounted) Navigator.of(context).pop(resultat);
    } on ErreurApi catch (e) {
      if (mounted) AppToast.show(context, e.message);
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          const ErreurApi(TypeErreurApi.inattendue).message,
        );
      }
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposition;
    return FeuilleBase(
      titre: widget.report
          ? 'Reporter la visite PEM'
          : 'Accepter la visite PEM',
      children: [
        Text(widget.nomClient, style: AppText.titreCarte),
        const SizedBox(height: 3),
        Text(
          'Proposée pour le ${libelleDatePem(p.dateProposee)}',
          style: AppText.sousCarte,
        ),
        ChampDate(
          label: widget.report ? 'Reporter au *' : 'Date de la visite *',
          valeur: _date,
          min: _fenetre.min,
          max: _fenetre.max,
          margeHaut: 14,
          onChanged: (d) => setState(() => _date = d),
        ),
        if (widget.report)
          ChampTexte(
            label: 'Motif (facultatif)',
            lignes: 3,
            onChanged: (m) => _motif = m,
          ),
        Rangee(
          margeHaut: 6,
          children: [
            AppBouton(
              'Annuler',
              petit: true,
              onPressed: _occupe ? null : () => Navigator.of(context).pop(),
            ),
            AppBouton(
              _occupe ? 'Envoi…' : (widget.report ? 'Reporter' : 'Accepter'),
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: _occupe ? null : _valider,
            ),
          ],
        ),
      ],
    );
  }
}
