import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Valeurs du thème relues dans le CSS de la maquette (`demo-appli.html` l.7-308).
void main() {
  test('couleurs de :root', () {
    expect(AppColors.fond, const Color(0xFFF1F3FB)); // --fond
    expect(AppColors.texte, const Color(0xFF111827)); // --texte
    expect(AppColors.muted, const Color(0xFF6B7280)); // --muted
    expect(AppColors.ok, const Color(0xFF059669)); // --ok
    expect(AppColors.warn, const Color(0xFFD97706)); // --warn
    expect(AppColors.alert, const Color(0xFFDC2626)); // --alert
    expect(AppColors.ligne, const Color(0xFFE5E7EF)); // --ligne
    expect(AppColors.voile, const Color(0x77000000)); // .voile #0007
    expect(
      AppColors.violetTeinte,
      const Color(0x1F6545C5),
    ); // .p-violet #6545C51f
  });

  test('palette « sales » (.ecran.u-sales)', () {
    const u = UniversPalette.sales;
    expect(u.acc, const Color(0xFF1F7AEA));
    expect(u.acc2, const Color(0xFF65B8FD));
    expect(u.halo, const Color(0x6165B8FD)); // rgba(101,184,253,.38)
    expect(u.encre, const Color(0xFF0B2545));
    expect(u.encre2, const Color(0xFF2E1B56));
    expect(u.bleu, const Color(0xFF1F7AEA));
    expect(
      u.violet,
      const Color(0xFF6545C5),
    ); // --violet de :root, non surchargé
    expect(u.violetFonce, const Color(0xFF4B2FA0));
    expect(u.fondCouleurs, const [
      Color(0xFF65B8FD),
      Color(0xFF8CCBFE),
      Color(0xFFCBE6FF),
      Color(0xFFEEF7FF),
      Color(0xFFFAFDFF),
      Color(0xFFFFFFFF),
    ]);
    expect(UniversPalette.fondArrets, const [0, 0.12, 0.28, 0.46, 0.66, 1]);
  });

  test('palette « pilot » (.ecran.u-pilot)', () {
    const u = UniversPalette.pilot;
    expect(u.acc, const Color(0xFF7A56E6));
    expect(u.acc2, const Color(0xFFB396FB));
    expect(u.halo, const Color(0x6BB396FB)); // rgba(179,150,251,.42)
    expect(u.encre, const Color(0xFF241447));
    expect(u.encre2, const Color(0xFF2E1B56));
    expect(u.bleu, const Color(0xFF1D4ED8)); // --bleu de :root, non surchargé
    expect(u.violet, const Color(0xFF7A56E6));
    expect(u.violetFonce, const Color(0xFF5B3CC4));
    expect(u.fondCouleurs, const [
      Color(0xFFB396FB),
      Color(0xFFC6B0FC),
      Color(0xFFE1D6FE),
      Color(0xFFF3EEFF),
      Color(0xFFFBF9FF),
      Color(0xFFFFFFFF),
    ]);
  });

  test('dégradé à 135° : l’angle reste de 45° quelle que soit la forme', () {
    final g = DegradeCss(colors: const [Color(0xFF65B8FD), Color(0xFF1F7AEA)]);
    // Carré : d’un coin à l’autre.
    final (d1, f1) = g.extremites(const Rect.fromLTWH(0, 0, 100, 100));
    expect(d1.dx, closeTo(0, 1e-9));
    expect(d1.dy, closeTo(0, 1e-9));
    expect(f1.dx, closeTo(100, 1e-9));
    expect(f1.dy, closeTo(100, 1e-9));
    // Rectangle large (un bouton) : la ligne de dégradé garde la pente 1, les coins prennent 0 % et 100 %.
    final (d2, f2) = g.extremites(const Rect.fromLTWH(0, 0, 300, 40));
    expect((f2.dx - d2.dx), closeTo(f2.dy - d2.dy, 1e-9));
    expect(d2.dx, closeTo((300 - 40) / 4, 1e-9)); // (w - h) / 4
    expect(f2.dx, closeTo((3 * 300 + 40) / 4, 1e-9)); // (3w + h) / 4
  });

  testWidgets('pastille violette : fond #6545C5 à 12 % dans les deux univers', (
    tester,
  ) async {
    for (final role in [Role.promoteur, Role.cs]) {
      await pumpEcran(
        tester,
        const Scaffold(
          body: Pastille('Prochain', variante: VariantePastille.violet),
        ),
        role: role,
      );
      final deco =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(Pastille),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(deco.color, AppColors.violetTeinte, reason: role.name);
      final texte = tester.widget<Text>(find.text('Prochain'));
      expect(
        texte.style!.color,
        role.univers == Univers.sales
            ? const Color(0xFF6545C5)
            : const Color(0xFF7A56E6),
      );
    }
  });

  testWidgets(
    'barre de navigation : 68 px, coins hauts à 24, « + » rond de 46',
    (tester) async {
      expect(hauteurNav, 68);
      await pumpEcran(
        tester,
        Scaffold(
          bottomNavigationBar: AppNavBar(
            onglets: const [],
            actif: OngletApp.accueil,
            onSelect: (_) {},
            plusActif: false,
            plusOuvert: false,
            onPlus: () {},
          ),
        ),
        role: Role.promoteur,
      );
      final barre = tester.getSize(find.byType(AppNavBar));
      expect(barre.height, 68);
      final rond = tester.getSize(
        find.descendant(
          of: find.byType(AppNavBar),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
      );
      expect(rond, const Size(46, 46));
    },
  );
}
