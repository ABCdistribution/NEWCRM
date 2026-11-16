import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/news_serveur.dart';

/// Ouvre la feuille « News ». Maquette : modale `news` l.1854-1857 et `NEWS` l.1042-1047.
/// Appelée par `AppRoutes.detailNews(context, newsId)`.
Future<void> ouvrirDetailNews(BuildContext context, String newsId) =>
    showAppSheet<void>(
      context,
      builder: (_) => NewsDetailSheet(newsId: newsId),
    );

/// Feuille « News » : titre de la news, date, paragraphes du texte.
class NewsDetailSheet extends StatelessWidget {
  const NewsDetailSheet({super.key, required this.newsId});

  /// Identifiant de la news (« n1 » à « n4 »).
  final String newsId;

  @override
  Widget build(BuildContext context) {
    final x = newsParIdActuelle(newsId);
    if (x == null) return const FeuilleBase(children: []);
    return FeuilleBase(
      titre: x.titre,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(x.date, style: AppText.t(12.5, c: AppColors.muted)),
        ),
        for (final t in x.texte)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(t, style: AppText.t(14.5)),
          ),
      ],
    );
  }
}
