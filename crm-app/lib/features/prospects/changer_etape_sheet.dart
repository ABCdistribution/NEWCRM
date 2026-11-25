import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/erreur_api.dart';
import '../../core/envoi/corps_visite.dart';
import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';
import '../../core/sync/catalogue_provider.dart';
import '../../core/sync/detail_prospect_provider.dart';
import '../../core/sync/domaines_provider.dart';
import '../../core/ui/ui.dart';
import 'logic/actions_prospect.dart';

/// Ouvre la feuille « Changer d'étape ». Maquette : modale `feuille-etape` l.1830-1832 et action `etape-vers` l.2028.
/// Appelée par `AppRoutes.changerEtapeProspect(context, prospectId)`.
Future<void> ouvrirChangerEtape(BuildContext context, String prospectId) =>
    showAppSheet<void>(
      context,
      builder: (_) => ChangerEtapeSheet(prospectId: prospectId),
    );

/// Étapes proposées : de « Fiche créée » à « Perdu », sans « Référencé » qui passe par « Passer en client ».
const List<StatutProspect> _etapesProposees = [
  StatutProspect.nouveau,
  StatutProspect.contacte,
  StatutProspect.visite,
  StatutProspect.proposition,
  StatutProspect.negociation,
  StatutProspect.perdu,
];

/// Feuille « Changer d'étape » : six étapes (Fiche créée … Perdu), coche sur l'étape courante. Toucher l'étape courante
/// ne fait rien.
///
/// Démonstration : l'étape et la probabilité changent dans le store local, « Étape → … » s'ajoute à la timeline, la
/// feuille se ferme et « Étape : … » s'affiche. Connecté : l'étape part au CRM (`PATCH /prospects/:id`, le serveur
/// gagne) ; « Perdu » demande d'abord le motif ; en cas de refus la feuille reste ouverte avec le message de l'API ;
/// sinon la fiche et la liste sont relues.
class ChangerEtapeSheet extends ConsumerStatefulWidget {
  const ChangerEtapeSheet({super.key, required this.prospectId});

  /// Prospect concerné.
  final String prospectId;

  @override
  ConsumerState<ChangerEtapeSheet> createState() => _ChangerEtapeSheetState();
}

class _ChangerEtapeSheetState extends ConsumerState<ChangerEtapeSheet> {
  /// « Perdu » choisi : la feuille demande le motif.
  bool _attenteMotif = false;
  bool _envoi = false;
  String? _erreur;

  bool get _versCrm => DemoTemps.reel && estUuid(widget.prospectId);

  void _choisir(StatutProspect courante, StatutProspect s) {
    if (courante == s || _envoi) return;
    if (!_versCrm) {
      ref.read(crmProvider.notifier).changerEtapeProspect(widget.prospectId, s);
      AppToast.show(context, 'Étape : ${s.libelle}.');
      Navigator.of(context).pop();
      return;
    }
    if (s == StatutProspect.perdu) {
      setState(() {
        _attenteMotif = true;
        _erreur = null;
      });
      return;
    }
    unawaited(_envoyer(s));
  }

  /// Connecté : `PATCH /prospects/:id`. Le CRM applique la probabilité par défaut de l'étape.
  Future<void> _envoyer(StatutProspect s, {MotifPerte? motif}) async {
    final conteneur = ProviderScope.containerOf(context);
    final api = ref.read(apiEcritureProvider);
    final id = widget.prospectId;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await api.envoyer(
        'PATCH',
        cheminProspect(id),
        corps: corpsChangementEtape(s, motif: motif),
      );
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = messageErreurActionProspect(e);
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = const ErreurApi(TypeErreurApi.inattendue).message;
      });
      return;
    }
    conteneur.invalidate(detailProspectProvider(id));
    unawaited(conteneur.read(prospectsSynchroProvider.notifier).rafraichir());
    if (!mounted) return;
    AppToast.show(context, 'Étape : ${s.libelle}.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final courante = ref.watch(
      prospectParIdProvider(widget.prospectId).select((p) => p?.statut),
    );
    if (_attenteMotif) {
      return FeuilleBase(
        titre: 'Motif de la perte',
        children: [
          if (_erreur != null) MessageErreur(_erreur!),
          for (final m in MotifPerte.values)
            _RangeeEtape(
              libelle: m.libelle,
              coche: false,
              onTap: _envoi
                  ? () {}
                  : () => unawaited(_envoyer(StatutProspect.perdu, motif: m)),
            ),
        ],
      );
    }
    return FeuilleBase(
      titre: "Changer d'étape",
      children: [
        if (_erreur != null) MessageErreur(_erreur!),
        for (final s in _etapesProposees)
          _RangeeEtape(
            libelle: s.libelle,
            coche: courante == s,
            onTap: () {
              if (courante != null) _choisir(courante, s);
            },
          ),
      ],
    );
  }
}

/// Ligne de choix d'une feuille (`.feuille .ch`) : libellé à gauche, coche à droite, filet dessous.
class _RangeeEtape extends StatelessWidget {
  const _RangeeEtape({
    required this.libelle,
    required this.coche,
    required this.onTap,
  });

  final String libelle;
  final bool coche;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.ligne)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(libelle, style: AppText.t(15)),
            if (coche) Text('✓', style: AppText.t(15)),
          ],
        ),
      ),
    );
  }
}
