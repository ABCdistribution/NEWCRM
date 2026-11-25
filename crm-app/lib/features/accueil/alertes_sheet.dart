import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/erreur_api.dart';
import '../../core/logic/classes.dart';
import '../../core/models/models.dart';
import '../../core/nav/nav.dart';
import '../../core/state/state.dart';
import '../../core/sync/domaines_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';

/// Ouvre la feuille des alertes (la cloche de l'accueil). Maquette : modale `cloche` l.1908-1913.
Future<void> ouvrirAlertes(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const AlertesSheet());

/// Feuille « Alertes » : une carte par alerte (`alertesProvider`), rouge pâle si l'alerte est haute, bleutée sinon ;
/// un appui ferme la feuille et ouvre la fiche du client ou du prospect concerné.
///
/// Le titre est « Alertes » pour le chef de secteur (qui voit aussi les prospects), « Alertes clients » pour les autres.
class AlertesSheet extends ConsumerWidget {
  const AlertesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertes = ref.watch(alertesProvider);
    final role = ref.watch(roleActifProvider);
    return FeuilleBase(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: role == Role.cs ? 'Alertes ' : 'Alertes clients ',
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Pastille('${alertes.length}'),
                ),
              ],
            ),
            style: AppText.titreFeuille,
          ),
        ),
        if (alertes.isEmpty)
          const Vide('Aucune alerte : tout est à jour.')
        else
          for (final a in alertes)
            _CarteAlerte(
              // Une notification du CRM n'a pas de classe : on prend celle du client visé.
              alerte: a.classe.isEmpty && a.magasinId != null
                  ? a.avecClasse(ref.watch(classeMagasinProvider(a.magasinId!)))
                  : a,
              onTap: () => a.estNotification
                  ? _marquerLue(context, ref, a)
                  : _ouvrir(context, a),
            ),
        if (alertes.any((a) => a.estNotification))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppBouton(
              'Tout marquer comme lu',
              variante: VarianteBouton.tonal,
              onPressed: () => _toutMarquerLu(context, ref),
            ),
          ),
        // La marge basse de la dernière alerte et la marge haute du pied se confondent (8 px, pas 16).
        Pied(
          'La fréquence de visite attendue dépend de la classification du client '
          '(A++ : tous les 7 jours, B : 21 jours, D : 35 jours…).',
          margeHaut: alertes.isEmpty ? 8 : 0,
        ),
      ],
    );
  }

  /// Une notification du CRM se marque comme lue d'un appui : elle quitte la cloche.
  Future<void> _marquerLue(
    BuildContext context,
    WidgetRef ref,
    Alerte a,
  ) async {
    final id = a.notificationId;
    if (id == null) return;
    await _tenter(
      context,
      () => ref.read(notificationsSynchroProvider.notifier).marquerLue(id),
    );
  }

  Future<void> _toutMarquerLu(BuildContext context, WidgetRef ref) => _tenter(
    context,
    () => ref.read(notificationsSynchroProvider.notifier).toutMarquerLu(),
  );

  /// Exécute l'écriture ; l'échec (hors ligne, refus) est signalé sans fermer la feuille.
  Future<void> _tenter(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ErreurApi catch (e) {
      if (context.mounted) AppToast.show(context, e.message);
    }
  }

  /// Ferme la feuille puis ouvre la fiche (maquette : actions `alerte-ouvrir` et `fiche-prospect`).
  void _ouvrir(BuildContext context, Alerte a) {
    Navigator.of(context).pop();
    final prospectId = a.prospectId;
    final magasinId = a.magasinId;
    if (prospectId != null) {
      AppRoutes.ficheProspect(context, prospectId);
    } else if (magasinId != null) {
      AppRoutes.ficheMagasin(context, magasinId);
    }
  }
}

/// Une alerte (`.alerte`) : pastille d'emoji, titre et classe, détail, chevron. Liseré gauche de 4 px.
class _CarteAlerte extends StatelessWidget {
  const _CarteAlerte({required this.alerte, required this.onTap});

  final Alerte alerte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final haut = alerte.niveau == NiveauAlerte.haut;
    final lettre = classeValide(alerte.classe);
    final classe = [
      if (alerte.estProspect) 'Prospect',
      if (lettre.isNotEmpty) 'Classe $lettre',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter: FondAlerte(
            fond: haut ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFF),
            lisere: haut ? AppColors.alert : AppColors.compteur,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x11000000),
                        offset: Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(alerte.icone, style: AppText.t(18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            alerte.titre,
                            style: AppText.t(14, w: FontWeight.w700),
                          ),
                          if (classe.isNotEmpty)
                            Pastille(classe, variante: VariantePastille.client),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          alerte.detail,
                          style: AppText.t(12.5, c: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  alerte.estNotification ? '✓' : '›',
                  style: AppText.t(16, c: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fond d'une alerte : rectangle de rayon 16 avec un liseré gauche de 4 px.
///
/// En CSS (`border-left: 4px` avec `border-radius: 16px`) le liseré suit le coin arrondi et s'amincit vers le haut et le
/// bas : le bord intérieur est une ellipse de 12 × 16 px, ce qu'un `Border` Flutter (qui refuse un rayon sur une bordure
/// non uniforme) ne sait pas dessiner.
class FondAlerte extends CustomPainter {
  const FondAlerte({required this.fond, required this.lisere});

  final Color fond;
  final Color lisere;

  @override
  void paint(Canvas canvas, Size size) {
    final exterieur = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final interieur = RRect.fromRectAndCorners(
      Rect.fromLTRB(4, 0, size.width, size.height),
      topLeft: const Radius.elliptical(12, 16),
      bottomLeft: const Radius.elliptical(12, 16),
      topRight: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );
    canvas.drawRRect(exterieur, Paint()..color = fond);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRRect(exterieur),
        Path()..addRRect(interieur),
      ),
      Paint()..color = lisere,
    );
  }

  @override
  bool shouldRepaint(FondAlerte old) =>
      old.fond != fond || old.lisere != lisere;
}
