import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_icons.dart';

/// Variantes de bouton (`.btn`, `.btn.plein`, `.btn.tonal`…).
enum VarianteBouton {
  /// Contour blanc, texte violet (bouton par défaut).
  contour,

  /// Dégradé accent (`.plein`) : action principale.
  plein,

  /// Blanc ombré, texte d'accent (`.tonal`) : action secondaire.
  tonal,

  /// Contour rouge pâle, texte rouge : suppression.
  danger,

  /// Bleu pâle (`.sales-fond`).
  clair,
}

/// Bouton arrondi de la maquette (`.btn`). Hauteur 44 (38 si `petit`), pleine largeur par défaut.
///
/// ```dart
/// AppBouton('Valider', variante: VarianteBouton.plein, onPressed: () {})
/// ```
/// `onPressed: null` = bouton désactivé (opacité 45 %).
class AppBouton extends StatelessWidget {
  const AppBouton(
    this.label, {
    super.key,
    required this.onPressed,
    this.variante = VarianteBouton.contour,
    this.petit = false,
    this.pleineLargeur = true,
    this.paddingH = 18,
  });

  final String label;
  final VoidCallback? onPressed;
  final VarianteBouton variante;
  final bool petit;

  /// Vrai : occupe toute la largeur disponible. Faux : largeur du texte (`flex:none; width:auto`).
  final bool pleineLargeur;
  final double paddingH;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final hauteur = petit ? 38.0 : 44.0;
    final contour = Colors.black.withValues(alpha: 0.08);
    late final Color fond;
    late final Color texte;
    Gradient? degrade;
    Border? bordure = Border.all(color: contour);
    List<BoxShadow>? ombre;
    switch (variante) {
      case VarianteBouton.contour:
        fond = Colors.white;
        texte = u.violet;
      case VarianteBouton.plein:
        fond = u.acc;
        texte = Colors.white;
        degrade = u.degradeBouton;
        bordure = null;
        ombre = u.ombreBouton;
      case VarianteBouton.tonal:
        fond = Colors.white;
        texte = u.acc;
        bordure = null;
        ombre = u.ombreDouce;
      case VarianteBouton.danger:
        fond = Colors.white;
        texte = AppColors.pRougeTexte;
        bordure = Border.all(color: const Color(0xFFE0A4A4));
      case VarianteBouton.clair:
        fond = AppColors.pBleuFond;
        texte = AppColors.pBleuTexte;
    }
    final corps = Container(
      height: hauteur,
      width: pleineLargeur ? double.infinity : null,
      padding: pleineLargeur
          ? null
          : EdgeInsets.symmetric(horizontal: paddingH),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: degrade == null ? fond : null,
        gradient: degrade,
        borderRadius: BorderRadius.circular(999),
        border: bordure,
        boxShadow: ombre,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.t(petit ? 13 : 14, w: FontWeight.w700, c: texte),
      ),
    );
    final actif = onPressed != null;
    return Semantics(
      button: true,
      enabled: actif,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Opacity(opacity: actif ? 1 : 0.45, child: corps),
      ),
    );
  }
}

/// Rangée de boutons de même largeur (`.rangee` : flex, gap 10, enfants égaux).
class Rangee extends StatelessWidget {
  const Rangee({
    super.key,
    required this.children,
    this.gap = 10,
    this.margeHaut = 0,
  });

  final List<Widget> children;
  final double gap;
  final double margeHaut;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(width: gap));
      items.add(Expanded(child: children[i]));
    }
    return Padding(
      padding: EdgeInsets.only(top: margeHaut),
      child: Row(children: items),
    );
  }
}

/// Bouton flottant (`.fab`) : pilule avec libellé (« ＋ Nouveau prospect ») ou rond de 58 px (`rond`).
///
/// À poser dans `PageUnivers(fab: …)` : il se place en bas à droite, au-dessus de la barre de navigation.
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.onPressed,
    this.label,
    this.rond = false,
    this.semantique,
  });

  final VoidCallback onPressed;

  /// Texte de la pilule ; ignoré pour un FAB rond (qui affiche « ＋ »).
  final String? label;
  final bool rond;

  /// Libellé d'accessibilité (obligatoire en pratique pour le FAB rond).
  final String? semantique;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Semantics(
      button: true,
      label: semantique ?? label ?? 'Ajouter',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: rond ? 58 : null,
          height: rond ? 58 : null,
          padding: rond
              ? null
              : const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          alignment: rond ? Alignment.center : null,
          decoration: BoxDecoration(
            gradient: u.degradeBouton,
            borderRadius: BorderRadius.circular(20),
            boxShadow: u.ombreFab,
          ),
          child: rond
              ? const AppIcon(AppIcons.plus, size: 28, color: Colors.white)
              : Text(
                  label ?? '',
                  style: AppText.t(14.5, w: FontWeight.w800, c: Colors.white),
                ),
        ),
      ),
    );
  }
}

/// Barre d'actions fixe en bas d'un écran (`.bas`) : boutons de même largeur sur fond clair.
///
/// `BarreBasse(enfants: [AppBouton(...), AppBouton(...)])` ; `BarreBasse.libre(child:)` pour une
/// mise en page spéciale (texte + bouton). `blanc` = fond blanc (`style="background:#fff"`).
class BarreBasse extends StatelessWidget {
  const BarreBasse({super.key, required this.enfants, this.blanc = false})
    : libre = null;

  const BarreBasse.libre({super.key, required Widget child, this.blanc = false})
    : enfants = const [],
      libre = child;

  final List<Widget> enfants;
  final Widget? libre;
  final bool blanc;

  @override
  Widget build(BuildContext context) {
    final bas = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bas),
      color: blanc ? Colors.white : AppColors.fond,
      child:
          libre ??
          Row(
            children: [
              for (var i = 0; i < enfants.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: enfants[i]),
              ],
            ],
          ),
    );
  }
}

/// Une action de la rangée d'actions d'entête (Appeler, Mail, Itinéraire…).
class ActionRapide {
  const ActionRapide({
    required this.label,
    required this.onTap,
    this.icone,
    this.plein = false,
  });

  final String label;

  /// Nul : action inactive (donnée absente), affichée estompée et sans effet au toucher.
  final VoidCallback? onTap;

  /// Icône SVG (`AppIcons.tel`…) ; nulle pour l'action pleine « ＋ Visite ».
  final String? icone;

  /// Action principale : fond dégradé, texte blanc (`.actions button.plein`).
  final bool plein;
}

/// Rangée d'actions rapides d'un entête de fiche (`.actions`) : 4 boutons côte à côte, ou 6 sur deux rangées (`six`).
class RangeeActions extends StatelessWidget {
  const RangeeActions({super.key, required this.actions, this.six = false});

  final List<ActionRapide> actions;

  /// Trois boutons par rangée (`.actions.six`).
  final bool six;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    Widget bouton(ActionRapide a) {
      final contenu = GestureDetector(
        onTap: a.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 11, 0, 9),
          decoration: BoxDecoration(
            color: a.plein ? null : Colors.white,
            gradient: a.plein ? u.degradeBouton : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: u.ombreDouce,
          ),
          child: a.plein && a.icone == null
              ? Center(
                  child: Text(
                    a.label,
                    style: AppText.t(14, w: FontWeight.w800, c: Colors.white),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (a.icone != null)
                      AppIcon(a.icone!, color: a.plein ? Colors.white : u.acc),
                    const SizedBox(height: 4),
                    Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.t(
                        12.5,
                        w: FontWeight.w700,
                        c: a.plein ? Colors.white : u.acc,
                      ),
                    ),
                  ],
                ),
        ),
      );
      return a.onTap == null ? Opacity(opacity: 0.4, child: contenu) : contenu;
    }

    Widget rangee(List<ActionRapide> l) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < l.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: bouton(l[i])),
          ],
        ],
      ),
    );

    final rangees = <Widget>[];
    if (six) {
      for (var i = 0; i < actions.length; i += 3) {
        if (i > 0) rangees.add(const SizedBox(height: 8));
        rangees.add(
          rangee(
            actions.sublist(i, i + 3 > actions.length ? actions.length : i + 3),
          ),
        );
      }
    } else {
      rangees.add(rangee(actions));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(children: rangees),
    );
  }
}

/// Bouton carré de filtre (`.btn-filtre`) avec compteur de filtres actifs.
class BoutonFiltre extends StatelessWidget {
  const BoutonFiltre({
    super.key,
    required this.onTap,
    this.nbFiltres = 0,
    this.icone = AppIcons.filtre,
    this.taille = 48,
    this.semantique = 'Filtres',
  });

  final VoidCallback onTap;

  /// Nombre de filtres actifs : affiche une pastille d'accent si > 0.
  final int nbFiltres;
  final String icone;
  final double taille;
  final String semantique;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Semantics(
      button: true,
      label: semantique,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: taille,
          height: taille,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: taille,
                height: taille,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(taille >= 48 ? 16 : 13),
                  boxShadow: u.ombreDouce,
                ),
                child: Center(child: AppIcon(icone, color: u.acc)),
              ),
              if (nbFiltres > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: u.acc,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$nbFiltres',
                      style: AppText.t(11, w: FontWeight.w800, c: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton retour carré blanc (`.retour`) : revient à l'écran précédent par défaut.
class BoutonRetour extends StatelessWidget {
  const BoutonRetour({super.key, this.onTap, this.taille = 42});

  /// Action personnalisée ; à défaut `Navigator.pop`.
  final VoidCallback? onTap;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Semantics(
      button: true,
      label: 'Retour',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: Container(
          width: taille,
          height: taille,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: u.ombreRond,
          ),
          child: Text('←', style: AppText.t(13.333, c: u.acc)),
        ),
      ),
    );
  }
}

/// Petit bouton rond blanc de 38 px (`.rond-b`) : flèches de semaine « ‹ » « › », scan « ▦ ».
class RondB extends StatelessWidget {
  const RondB(this.label, {super.key, required this.onTap, this.semantique});

  final String label;
  final VoidCallback onTap;
  final String? semantique;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Semantics(
      button: true,
      label: semantique ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            boxShadow: u.ombreRond,
          ),
          child: Text(label, style: AppText.t(13.333, c: u.acc)),
        ),
      ),
    );
  }
}
