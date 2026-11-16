import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'boutons.dart';
import 'formulaires.dart';

/// Ouvre une feuille basse modale (`.voile` + `.feuille`) au-dessus de tout l'écran, barre de navigation comprise.
///
/// Le builder renvoie le contenu, en général une `FeuilleBase`. Fermer : `Navigator.of(context).pop(valeur)`.
///
/// ```dart
/// showAppSheet<void>(context, builder: (_) => FeuilleBase(titre: 'Filtres', children: [...]));
/// ```
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.voile,
    elevation: 0,
    builder: builder,
  );
}

/// Contenu d'une feuille basse (`.feuille`) : coins hauts arrondis à 24, poignée grise, titre, 92 % de hauteur max.
class FeuilleBase extends StatelessWidget {
  const FeuilleBase({
    super.key,
    this.titre,
    this.titreDroite,
    required this.children,
  });

  /// Titre de la feuille (17 px) ; nul = pas de titre.
  final String? titre;

  /// Élément à droite du titre (pastille de compteur…).
  final Widget? titreDroite;
  final List<Widget> children;

  /// Marge basse du titre (`.feuille h3{margin:0 0 10px}`), fusionnée avec la marge haute du premier élément quand
  /// celui-ci en a une (`.titre-filtre`, `.np-section` : 14 px) : en CSS la plus grande des deux l'emporte, elles ne
  /// s'additionnent pas.
  double get _margeBasTitre {
    final Widget? premier = children.isEmpty ? null : children.first;
    final double haute = switch (premier) {
      final AMargeHaute m => m.margeHaute,
      _ => 0,
    };
    return haute >= 10 ? 0 : 10 - haute;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            20 + mq.viewInsets.bottom + mq.padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (titre != null)
                Padding(
                  padding: EdgeInsets.only(bottom: _margeBasTitre),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(titre!, style: AppText.titreFeuille),
                      ),
                      if (titreDroite != null) ...[
                        const SizedBox(width: 8),
                        titreDroite!,
                      ],
                    ],
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Ouvre un dialogue centré (`.dialogue`) sur voile sombre.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: AppColors.voile,
    builder: builder,
  );
}

/// Contenu d'un dialogue (`.dialogue`) : carte blanche de rayon 22, marges latérales de 22.
class DialogueBase extends StatelessWidget {
  const DialogueBase({super.key, required this.titre, required this.children});

  final String titre;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(titre, style: AppText.titreDialogue),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Texte de dialogue (`.dialogue p` : 14 px, gris foncé, interligne 1,45).
class TexteDialogue extends StatelessWidget {
  const TexteDialogue(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      texte,
      style: AppText.t(14, c: const Color(0xFF374151), h: 1.45),
    ),
  );
}

/// Dialogue de confirmation « Annuler / OK » ; renvoie `true` si l'utilisateur confirme.
///
/// ```dart
/// final ok = await showConfirmation(context, titre: 'Passer en client ?', texte: '…', ok: 'Passer en client');
/// ```
Future<bool?> showConfirmation(
  BuildContext context, {
  required String titre,
  required String texte,
  required String ok,
  String annuler = 'Annuler',
}) {
  return showAppDialog<bool>(
    context,
    builder: (ctx) => DialogueBase(
      titre: titre,
      children: [
        TexteDialogue(texte),
        Rangee(
          children: [
            AppBouton(
              annuler,
              petit: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            AppBouton(
              ok,
              petit: true,
              variante: VarianteBouton.plein,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ],
    ),
  );
}
