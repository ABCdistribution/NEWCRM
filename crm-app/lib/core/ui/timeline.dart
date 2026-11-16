import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Un événement de timeline (`.tl-ev`) : icône ronde, titre, date à droite, détail.
class TimelineItem {
  const TimelineItem({
    required this.titre,
    this.detail,
    this.date,
    this.icone = '•',
    this.fondIcone = const Color(0xFFEEF0F8),
    this.couleurIcone,
    this.onTap,
    this.trailing,
  });

  final String titre;
  final String? detail;
  final String? date;

  /// Emoji ou caractère affiché dans le rond.
  final String icone;
  final Color fondIcone;
  final Color? couleurIcone;
  final VoidCallback? onTap;

  /// Widget à la place de la date (ex. pastille de statut).
  final Widget? trailing;
}

/// Carte de timeline verticale (`.tl`) : pastilles reliées par un trait gris.
///
/// ```dart
/// Timeline([TimelineItem(icone: '📞', titre: 'Appel', date: '14 oct.', detail: 'RDV obtenu')])
/// ```
class Timeline extends StatelessWidget {
  const Timeline(this.items, {super.key});
  final List<TimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: u.ombreCarte,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            _Evenement(items[i], dernier: i == items.length - 1),
        ],
      ),
    );
  }
}

class _Evenement extends StatelessWidget {
  const _Evenement(this.item, {required this.dernier});

  final TimelineItem item;
  final bool dernier;

  @override
  Widget build(BuildContext context) {
    final contenu = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.fondIcone,
              shape: BoxShape.circle,
            ),
            child: Text(item.icone, style: AppText.t(15, c: item.couleurIcone)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.titre,
                        style: AppText.t(14, w: FontWeight.w700),
                      ),
                    ),
                    if (item.trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: item.trailing!,
                      )
                    else if (item.date != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.date!,
                          softWrap: false,
                          style: AppText.t(12, c: AppColors.muted),
                        ),
                      ),
                  ],
                ),
                if (item.detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.detail!,
                      style: AppText.t(12.5, c: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final avecTrait = Stack(
      children: [
        contenu,
        if (!dernier)
          Positioned(
            left: 15,
            top: 34,
            bottom: 2,
            child: Container(width: 2, color: AppColors.ligne),
          ),
      ],
    );
    if (item.onTap == null) return avecTrait;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: avecTrait,
    );
  }
}
