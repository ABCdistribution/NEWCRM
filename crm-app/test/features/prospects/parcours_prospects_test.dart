import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/prospects_screen.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Parcours de bout en bout dans l'application complète : les actions du lot se reflètent dans les autres écrans.
Future<void> _ouvrirOnglet(WidgetTester tester, Role role) async {
  await lancerApp(tester, role);
  await tester.tap(
    find.descendant(
      of: find.byType(AppNavBar),
      matching: find.text('Prospects'),
    ),
  );
  await tester.pumpAndSettle();
}

ProviderContainer _store(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ShellScreen, skipOffstage: false)),
);

Future<void> _toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

void main() {
  testWidgets(
    'chef de secteur : un prospect perdu quitte les alertes de la cloche',
    (tester) async {
      await _ouvrirOnglet(tester, Role.cs);
      final alertesAvant = _store(tester).read(alertesProvider).length;
      await tester.tap(find.text('👥 Tout le secteur'));
      await tester.pumpAndSettle();
      expect(
        find.text('12 points de vente · potentiel 1140 k€/an'),
        findsOneWidget,
      );

      // Fiche de Carrefour HM – Cergy (contacté, sans RDV : une alerte « à contacter »).
      await _toucher(tester, find.text('Carrefour HM – Cergy'));
      await tester.pumpAndSettle();
      expect(find.text('Prospect · À contacter'), findsOneWidget);
      await tester.tap(find.text("Changer d'étape"));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(FeuilleBase),
          matching: find.text('Perdu'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Prospect · Perdu'), findsOneWidget);

      // Retour à la liste : le prospect est « Perdu » (pastille grise) et l'alerte a disparu.
      await tester.tap(find.byType(BoutonRetour));
      await tester.pumpAndSettle();
      expect(find.byType(ProspectsScreen), findsOneWidget);
      await _toucher(tester, find.text('Carrefour HM – Cergy'));
      await tester.pumpAndSettle();
      expect(find.text('Prospect · Perdu'), findsOneWidget);
      await tester.tap(find.byType(BoutonRetour));
      await tester.pumpAndSettle();
      expect(find.text('Perdu'), findsOneWidget); // pastille grise de la carte
      expect(_store(tester).read(alertesProvider).length, alertesAvant - 1);
      expect(
        find.text('12 points de vente · potentiel 1140 k€/an'),
        findsOneWidget,
      ); // un prospect perdu reste dans la vue et dans le total
    },
  );

  testWidgets(
    'directeur : passer un prospect en client le met dans « Référencé »',
    (tester) async {
      await _ouvrirOnglet(tester, Role.dir);
      await tester.tap(find.text('👥 Tous les prospects'));
      await tester.pumpAndSettle();
      await _toucher(tester, find.text('Auchan – Rouen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passer en client'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Passer en client'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byType(BoutonRetour));
      await tester.pumpAndSettle();
      // Les tuiles comptent désormais 9 / 4 / 8 / 2 (au lieu de 9 / 5 / 8 / 1).
      final compteurs = [
        for (final g in ['À contacter', 'RDV pris', 'En négo', 'Référencé'])
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byKey(ValueKey('compteur-$g')),
                  matching: find.byType(Text),
                ),
              )
              .data,
      ];
      expect(compteurs, ['9', '4', '8', '2']);
    },
  );

  testWidgets(
    'la fiche se rouvre sur la timeline et le retour ramène à la liste',
    (tester) async {
      await _ouvrirOnglet(tester, Role.cs);
      await tester.tap(find.text('Super U – Versailles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Magasins'));
      await tester.pumpAndSettle();
      expect(find.text("Magasins de l'enseigne"), findsOneWidget);
      await tester.tap(find.byType(BoutonRetour));
      await tester.pumpAndSettle();
      expect(find.byType(ProspectsScreen), findsOneWidget);
      await tester.tap(find.text('Super U – Versailles'));
      await tester.pumpAndSettle();
      expect(find.text('Timeline de prospection'), findsOneWidget);
      expect(find.text("Magasins de l'enseigne"), findsNothing);
    },
  );
}
