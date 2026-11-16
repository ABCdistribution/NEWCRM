import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/features/catalogue/news_detail_sheet.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Feuille « News » : modale `news` l.1854-1857 de la maquette.
void main() {
  for (final role in Role.values) {
    testWidgets('AppRoutes.detailNews pour ${role.profil.libelle}', (
      tester,
    ) async {
      await lancerApp(tester, role);
      AppRoutes.detailNews(tester.element(find.byType(ShellScreen)), 'n2');
      await tester.pumpAndSettle();
      expect(
        find.text("JLD MANUCURE - RUPTURE PAE JUSQU'A FIN MAI 2026"),
        findsOneWidget,
      );
      expect(find.text('06/05/2026'), findsOneWidget);
      expect(
        find.text('Rupture sur les nouvelles références PAE JLD'),
        findsOneWidget,
      );
      expect(
        find.text('- Anciennes références à commander : 21244212…'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('styles : date grise 12,5 px, paragraphes 14,5 px', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      const Scaffold(body: NewsDetailSheet(newsId: 'n4')),
      role: Role.dir,
    );
    final date = tester.widget<Text>(find.text('10/03/2026'));
    expect(date.style?.fontSize, 12.5);
    expect(date.style?.color, AppColors.muted);
    final paragraphe = tester.widget<Text>(find.text('Bonjour à tous,'));
    expect(paragraphe.style?.fontSize, 14.5);
    expect(
      find.text(
        'Le masque Collagène HQ Made in Corée est de nouveau en stock ainsi que la crava…',
      ),
      findsOneWidget,
    );
  });

  testWidgets('identifiant inconnu : feuille vide, sans erreur', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      const Scaffold(body: NewsDetailSheet(newsId: 'n9')),
    );
    expect(find.byType(Text), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
