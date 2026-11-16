import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

void main() {
  Widget liste(List<int> elements) => SingleChildScrollView(
    child: ListePaginee<int>(
      elements: elements,
      constructeur: (n) => SizedBox(height: 20, child: Text('ligne $n')),
    ),
  );

  testWidgets(
    'seuls les 40 premiers éléments sont construits, « Afficher plus » ajoute les suivants',
    (tester) async {
      await pumpEcran(
        tester,
        Scaffold(body: liste(List.generate(5000, (i) => i))),
        role: Role.promoteur,
      );
      expect(find.textContaining('ligne '), findsNWidgets(40));
      expect(find.text('Afficher plus (4960 restants)'), findsOneWidget);
      await tester.ensureVisible(find.text('Afficher plus (4960 restants)'));
      await tester.tap(find.text('Afficher plus (4960 restants)'));
      await tester.pump();
      expect(find.textContaining('ligne '), findsNWidgets(80));
      expect(find.text('Afficher plus (4920 restants)'), findsOneWidget);
    },
  );

  testWidgets('moins de 40 éléments : tout est affiché, pas de bouton', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      Scaffold(body: liste(List.generate(12, (i) => i))),
      role: Role.promoteur,
    );
    expect(find.textContaining('ligne '), findsNWidgets(12));
    expect(find.textContaining('Afficher plus'), findsNothing);
  });

  testWidgets(
    'un nouveau filtre (autre nombre d\'éléments) revient aux 40 premiers',
    (tester) async {
      await pumpEcran(
        tester,
        Scaffold(body: liste(List.generate(500, (i) => i))),
        role: Role.promoteur,
      );
      await tester.ensureVisible(find.textContaining('Afficher plus'));
      await tester.tap(find.textContaining('Afficher plus'));
      await tester.pump();
      expect(find.textContaining('ligne '), findsNWidgets(80));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: liste(List.generate(300, (i) => i)))),
      );
      await tester.pump();
      expect(find.textContaining('ligne '), findsNWidgets(40));
    },
  );
}
