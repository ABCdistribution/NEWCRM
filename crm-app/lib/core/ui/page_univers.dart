import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// Hauteur d'une barre fixe posée sous la page par la coquille (la barre de navigation).
///
/// Dans la maquette le dégradé de fond appartient à `.ecran`, qui contient aussi la barre de navigation : il s'étire sur
/// toute la hauteur de l'écran. `UniversFond` lit cette hauteur pour calculer le dégradé comme si la page la contenait,
/// sans le dessiner sous la barre. Posée par `ShellScreen` uniquement : les écrans empilés recouvrent la barre et
/// ont leur propre fond complet.
class FondSousBarre extends InheritedWidget {
  const FondSousBarre({super.key, required this.hauteur, required super.child});

  final double hauteur;

  static double de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FondSousBarre>()?.hauteur ?? 0;

  @override
  bool updateShouldNotify(FondSousBarre old) => hauteur != old.hauteur;
}

/// Fond dégradé vertical de l'univers courant (`.ecran.u-sales` / `.u-pilot`), sans contenu.
class UniversFond extends StatelessWidget {
  const UniversFond({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final dessous = FondSousBarre.de(context);
    if (dessous <= 0) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: context.univers.fond),
        child: child,
      );
    }
    // Le dégradé déborde sous la page (de la hauteur de la barre) puis est coupé à son bord.
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -dessous,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: context.univers.fond),
          ),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

/// Page-type de l'application : fond dégradé, entête et corps qui défilent ensemble, barre basse fixe, FAB.
///
/// Tous les écrans (onglets et écrans empilés) sont construits avec elle.
///
/// ```dart
/// PageUnivers(
///   entete: AppEntete(titre: 'Clients', sous: '10 clients'),
///   enfants: [AppCarte(child: Text('…'))],
///   fab: AppFab(label: '＋ Nouveau prospect', onPressed: () {}),
/// )
/// ```
class PageUnivers extends StatelessWidget {
  const PageUnivers({
    super.key,
    this.entete,
    this.enfants = const [],
    this.corps,
    this.bas,
    this.fab,
    this.paddingCorps = true,
    this.paddingBasFab = false,
  });

  /// Entête (`AppEntete`, `TopbarEcran`…) : défile avec le corps.
  final Widget? entete;

  /// Contenu du corps (`.corps` : marges 16/16/24), empilé verticalement.
  final List<Widget> enfants;

  /// Corps libre à la place de `enfants`.
  final Widget? corps;

  /// Barre basse fixe (`BarreBasse`).
  final Widget? bas;

  /// Bouton flottant (`AppFab`), posé en bas à droite au-dessus de la barre de navigation.
  final Widget? fab;

  /// Applique les marges du corps (désactiver pour un corps pleine largeur).
  final bool paddingCorps;

  /// Réserve 90 px sous le corps pour que le FAB ne masque pas le dernier élément.
  final bool paddingBasFab;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    final contenu =
        corps ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: enfants,
        );
    final defile = SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: haut),
          ?entete,
          paddingCorps
              ? Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    paddingBasFab ? 90 : 24,
                  ),
                  child: contenu,
                )
              : contenu,
        ],
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: UniversFond(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: defile),
                    if (fab != null)
                      Positioned(right: 16, bottom: 14, child: fab!),
                  ],
                ),
              ),
              ?bas,
            ],
          ),
        ),
      ),
    );
  }
}
