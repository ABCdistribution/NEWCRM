import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/features/catalogue/data/news_demo.dart';
import 'package:crm_app/features/catalogue/news_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_catalogue.dart';

/// Onglet « News » : `salesNews` l.1048-1050 de la maquette ; données `NEWS` l.1042-1047.
void main() {
  group('Données NEWS', () {
    test('4 news, textes recopiés en entier', () {
      expect(newsDemo.map((n) => n.id), ['n1', 'n2', 'n3', 'n4']);
      expect(newsDemo.map((n) => n.texte.length), [3, 2, 2, 2]);
      expect(newsDemo.map((n) => n.date), [
        '26/05/2026',
        '06/05/2026',
        '11/03/2026',
        '10/03/2026',
      ]);
      expect(newsDemo[0].titre, 'Nouveautés HQ Mai');
      expect(
        newsDemo[1].titre,
        "JLD MANUCURE - RUPTURE PAE JUSQU'A FIN MAI 2026",
      );
      expect(newsDemo[2].titre, 'CRAVATE BUCCODENTAIRE APOTEKE DISPONIBLE');
      expect(
        newsDemo[3].titre,
        'LES MASQUES COREENS ET LA CRAVATE HQ SONT DE NOUVEAU EN STOCK !',
      );
      // Premier et dernier mot de chaque texte.
      expect(newsDemo[0].texte.first, 'Bonjour à tous,');
      expect(newsDemo[0].texte.last, '- Mas…');
      expect(
        newsDemo[1].texte.first,
        'Rupture sur les nouvelles références PAE JLD',
      );
      expect(
        newsDemo[1].texte.last,
        '- Anciennes références à commander : 21244212…',
      );
      expect(
        newsDemo[2].texte.last,
        "L'ensemble des références buccodentaire APOTEKE est de nouveau disponible (grat…",
      );
      expect(
        newsDemo[3].texte.last,
        'Le masque Collagène HQ Made in Corée est de nouveau en stock ainsi que la crava…',
      );
    });

    test('newsParId retrouve une news, nulle si inconnue', () {
      expect(
        newsParId('n3')?.titre,
        'CRAVATE BUCCODENTAIRE APOTEKE DISPONIBLE',
      );
      expect(newsParId('n9'), isNull);
    });
  });

  for (final role in Role.values) {
    testWidgets('News pour ${role.profil.libelle} : entête et 4 cartes', (
      tester,
    ) async {
      await ouvrirOngletPlus(tester, role, OngletApp.news);
      expect(find.text('News'), findsWidgets);
      expect(find.text('4 informations du siège'), findsOneWidget);
      for (final n in newsDemo) {
        expect(find.text(n.titre), findsOneWidget, reason: n.id);
        // Le texte de la carte réunit tous les paragraphes, séparés par une espace.
        expect(find.text(n.texte.join(' ')), findsOneWidget, reason: n.id);
        expect(find.text(n.date), findsOneWidget, reason: n.id);
      }
      expect(
        find.text(
          'Bonjour à tous, Je vous informe que les 3 nouveautés HQ suivantes sont disponibles : - Mas…',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'un appui sur une carte ouvre le détail : titre, date, paragraphes',
      (tester) async {
        await ouvrirOngletPlus(tester, role, OngletApp.news);
        await toucher(tester, find.text('Nouveautés HQ Mai'));
        // Le titre figure sur la carte et en tête de la feuille.
        expect(find.text('Nouveautés HQ Mai'), findsNWidgets(2));
        expect(find.text('26/05/2026'), findsNWidgets(2));
        expect(find.text('Bonjour à tous,'), findsOneWidget);
        expect(
          find.text(
            'Je vous informe que les 3 nouveautés HQ suivantes sont disponibles :',
          ),
          findsOneWidget,
        );
        expect(find.text('- Mas…'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('chaque news s’ouvre : un paragraphe par ligne du texte', (
    tester,
  ) async {
    await ouvrirOngletPlus(tester, Role.promoteur, OngletApp.news);
    for (final n in newsDemo) {
      await toucher(tester, find.text(n.titre).first);
      expect(find.text(n.titre), findsNWidgets(2), reason: n.id);
      for (final t in n.texte) {
        expect(find.text(t), findsOneWidget, reason: '${n.id} : $t');
      }
      await tester.tapAt(const Offset(195, 20)); // le voile ferme la feuille
      await tester.pumpAndSettle();
      expect(find.text(n.titre), findsOneWidget, reason: n.id);
    }
  });

  testWidgets('le texte de la carte est gris 13 px, la date en pied 11,5 px', (
    tester,
  ) async {
    await pumpEcran(tester, const NewsScreen(), role: Role.cs);
    final texte = tester.widget<Text>(
      find.text(
        'Rupture sur les nouvelles références PAE JLD - Anciennes références à commander : 21244212…',
      ),
    );
    expect(texte.style?.fontSize, 13);
    expect(texte.style?.color, AppColors.muted);
    final date = tester.widget<Text>(find.text('06/05/2026'));
    expect(date.style?.fontSize, 11.5);
  });
}
