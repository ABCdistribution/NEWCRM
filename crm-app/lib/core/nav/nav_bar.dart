import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../ui/app_icons.dart';
import 'onglets.dart';

/// Hauteur de la barre de navigation, sans la zone système (`.nav`).
const double hauteurNav = 68;

/// Barre de navigation basse (`.nav`) : onglets directs et bouton « + » rond (`.plus-btn`).
///
/// Posée par la coquille (`ShellScreen`) ; les lots n'y touchent pas.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.onglets,
    required this.actif,
    required this.onSelect,
    required this.plusActif,
    required this.plusOuvert,
    required this.onPlus,
  });

  final List<OngletApp> onglets;
  final OngletApp actif;
  final ValueChanged<OngletApp> onSelect;

  /// Vrai si l'onglet courant est dans le menu « + » (le bouton est alors en accent).
  final bool plusActif;
  final bool plusOuvert;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final bas = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: hauteurNav + bas,
      padding: EdgeInsets.only(bottom: bas),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: u.ombreNav,
      ),
      child: Row(
        children: [
          for (final o in onglets)
            Expanded(
              child: Semantics(
                button: true,
                selected: o == actif,
                label: o.libelle,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(o),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(
                        o.icone,
                        color: o == actif ? u.acc : AppColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        o.libelle,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: AppText.t(
                          11,
                          w: o == actif ? FontWeight.w700 : FontWeight.w400,
                          c: o == actif ? u.acc : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(
            width: 64,
            child: Semantics(
              button: true,
              label: 'Plus',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onPlus,
                child: Center(
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: u.degradeBouton,
                      shape: BoxShape.circle,
                      boxShadow: u.ombreBouton,
                    ),
                    child: plusOuvert
                        ? Text('×', style: AppText.t(28, c: Colors.white, h: 1))
                        : const AppIcon(
                            AppIcons.plus,
                            size: 26,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu « + » qui s'ouvre vers le haut (`.dropup`) : liste d'onglets dans une bulle blanche à flèche.
class MenuPlus extends StatelessWidget {
  const MenuPlus({
    super.key,
    required this.onglets,
    required this.actif,
    required this.onSelect,
  });

  final List<OngletApp> onglets;
  final OngletApp actif;
  final ValueChanged<OngletApp> onSelect;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 170),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: u.halo,
                  offset: const Offset(0, 12),
                  blurRadius: 32,
                ),
                const BoxShadow(
                  color: Color(0x22000000), // #0002
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final o in onglets)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            AppIcon(o.icone, color: u.acc),
                            const SizedBox(width: 12),
                            Text(
                              o.libelle,
                              style: o == actif
                                  ? AppText.t(15, w: FontWeight.w800, c: u.acc)
                                  : AppText.t(
                                      15,
                                      w: FontWeight.w600,
                                      c: u.encre,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: -7,
            child: Transform.rotate(
              angle: 0.7853981633974483,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
