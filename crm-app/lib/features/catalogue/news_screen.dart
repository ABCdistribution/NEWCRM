import 'package:flutter/material.dart';

import '../../core/nav/nav.dart';
import '../../core/theme/theme.dart';
import '../../core/ui/ui.dart';
import 'data/news_serveur.dart';

/// Onglet « News » (tous les rôles, menu « + »). Maquette : `salesNews` l.1048-1050.
///
/// Les informations du siège : titre, texte (tous les paragraphes à la suite) et date de publication. Un appui ouvre
/// le détail en feuille basse.
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final news = newsActuelles();
    return PageUnivers(
      entete: AppEntete(
        titre: 'News',
        tailleTitre: 21,
        sous: '${news.length} informations du siège',
      ),
      enfants: [
        if (news.isEmpty) const Vide('Aucune actualité.'),
        for (final x in news)
          AppCarte(
            onTap: () => AppRoutes.detailNews(context, x.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(x.titre, style: AppText.titreCarte),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    x.texte.join(' '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.t(13, c: AppColors.muted),
                  ),
                ),
                Pied(x.date),
              ],
            ),
          ),
      ],
    );
  }
}
