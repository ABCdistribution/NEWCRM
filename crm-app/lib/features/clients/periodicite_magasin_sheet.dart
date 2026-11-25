import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/erreur_api.dart';
import '../../core/sync/catalogue_provider.dart';
import '../../core/sync/fiche_client_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'logic/actions_magasin.dart';

/// Nomenclature des périodicités de visite (`GET /periodicites`), lue à l'ouverture de la feuille.
final periodicitesVisiteProvider =
    FutureProvider.autoDispose<List<PeriodiciteVisite>>((ref) async {
      final json = await ref.read(apiClientProvider).get('/periodicites');
      return periodicitesDepuisJson(json);
    });

/// Ouvre la feuille « Périodicité de visite » d'un magasin ; `courante` : libellé actuel (nul : aucune).
Future<void> ouvrirPeriodiciteMagasin(
  BuildContext context, {
  required String magasinId,
  String? courante,
}) => showAppSheet<void>(
  context,
  builder: (_) =>
      PeriodiciteMagasinSheet(magasinId: magasinId, courante: courante),
);

/// Feuille « Périodicité de visite » : la nomenclature du CRM plus « Aucune », coche sur la valeur actuelle. Choisir une
/// autre valeur l'enregistre en direct (`PATCH /clients/:id/periodicite`, le serveur gagne), relit la fiche et ferme la
/// feuille ; en cas de refus la feuille reste ouverte avec le message de l'API.
class PeriodiciteMagasinSheet extends ConsumerStatefulWidget {
  const PeriodiciteMagasinSheet({
    super.key,
    required this.magasinId,
    this.courante,
  });

  final String magasinId;
  final String? courante;

  @override
  ConsumerState<PeriodiciteMagasinSheet> createState() =>
      _PeriodiciteMagasinSheetState();
}

class _PeriodiciteMagasinSheetState
    extends ConsumerState<PeriodiciteMagasinSheet> {
  bool _envoi = false;
  String? _erreur;

  Future<void> _choisir(String? id) async {
    if (_envoi) return;
    final conteneur = ProviderScope.containerOf(context);
    final api = ref.read(apiEcritureProvider);
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await api.envoyer(
        'PATCH',
        cheminPeriodicite(widget.magasinId),
        corps: corpsPeriodicite(id),
      );
    } on ErreurApi catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreur = messageErreurMagasin(e);
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
    conteneur.invalidate(ficheClientProvider(widget.magasinId));
    if (!mounted) return;
    AppToast.show(context, 'Périodicité enregistrée.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(periodicitesVisiteProvider);
    final courante = widget.courante;
    return FeuilleBase(
      titre: 'Périodicité de visite',
      children: [
        if (_erreur != null) MessageErreur(_erreur!),
        ...switch (liste) {
          AsyncData(:final value) => [
            for (final p in value)
              _Rangee(
                libelle: p.libelle,
                coche: p.libelle == courante,
                onTap: p.libelle == courante ? () {} : () => _choisir(p.id),
              ),
            _Rangee(
              libelle: 'Aucune',
              coche: courante == null,
              onTap: courante == null ? () {} : () => _choisir(null),
            ),
          ],
          AsyncError(:final error) => [
            MessageErreur(
              error is ErreurApi
                  ? messageErreurMagasin(error)
                  : const ErreurApi(TypeErreurApi.inattendue).message,
            ),
          ],
          _ => const [Vide('Chargement…')],
        },
      ],
    );
  }
}

/// Ligne de choix d'une feuille : libellé à gauche, coche à droite, filet dessous.
class _Rangee extends StatelessWidget {
  const _Rangee({
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
