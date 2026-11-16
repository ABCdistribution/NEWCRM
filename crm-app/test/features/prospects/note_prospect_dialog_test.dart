import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/fiche_prospect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Dialogue « Nouvelle note » d'un prospect : maquette `note` l.1836-1838 et action `note-ok` l.2032.
Future<void> _ouvrirDialogue(WidgetTester tester, String id, Role role) async {
  await pumpEcran(tester, FicheProspectScreen(prospectId: id), role: role);
  await tester.tap(
    find.descendant(
      of: find.byType(RangeeActions),
      matching: find.text('Note'),
    ),
  );
  await tester.pumpAndSettle();
}

Prospect _prospect(WidgetTester tester, String id) => ProviderScope.containerOf(
  tester.element(find.byType(FicheProspectScreen)),
).read(prospectParIdProvider(id))!;

Finder _dansDialogue(String texte) =>
    find.descendant(of: find.byType(Dialog), matching: find.text(texte));

void main() {
  testWidgets('le dialogue montre la zone de texte et deux boutons', (
    tester,
  ) async {
    await _ouvrirDialogue(tester, 'p1', Role.cs);
    expect(_dansDialogue('Nouvelle note'), findsOneWidget);
    expect(find.text('Votre remarque'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(_dansDialogue('Annuler'), findsOneWidget);
    expect(_dansDialogue('Enregistrer'), findsOneWidget);
    // La zone de texte a le focus à l'ouverture (`autofocus`).
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);
  });

  testWidgets('une note vide ou faite d’espaces n’est pas enregistrée', (
    tester,
  ) async {
    await _ouvrirDialogue(tester, 'p1', Role.cs);
    await tester.tap(_dansDialogue('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(_dansDialogue('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.text('Note enregistrée. Envoi dès que le réseau le permet.'),
      findsNothing,
    );
    expect(_prospect(tester, 'p1').timeline.length, 5);
  });

  testWidgets('« Annuler » ferme le dialogue sans note', (tester) async {
    await _ouvrirDialogue(tester, 'p1', Role.cs);
    await tester.enterText(find.byType(TextField), 'À ne pas garder');
    await tester.tap(_dansDialogue('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(_prospect(tester, 'p1').timeline.length, 5);
    expect(find.text('À ne pas garder'), findsNothing);
  });

  testWidgets('« Enregistrer » ajoute la note en tête de la timeline', (
    tester,
  ) async {
    await _ouvrirDialogue(tester, 'p1', Role.cs);
    await tester.enterText(find.byType(TextField), '  Rappeler jeudi  ');
    await tester.tap(_dansDialogue('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(Dialog), findsNothing);
    expect(
      find.text('Note enregistrée. Envoi dès que le réseau le permet.'),
      findsOneWidget,
    );
    final p = _prospect(tester, 'p1');
    expect(p.timeline.length, 6);
    final note = p.timeline.first;
    expect(note.titre, 'Note');
    expect(note.date, 'auj.');
    expect(note.detail, 'Rappeler jeudi'); // espaces retirés
    expect(note.icone, IconeEvenement.doc);
    expect(note.couleur, 0xFF6B7280);
    // La fiche affiche la note, avant l'historique existant (après le RDV prévu).
    expect(find.text('Rappeler jeudi'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Rappeler jeudi')).dy,
      lessThan(tester.getTopLeft(find.text('Visite · présentation gamme')).dy),
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('une seconde note passe devant la première', (tester) async {
    await _ouvrirDialogue(tester, 'p5', Role.cs);
    await tester.enterText(find.byType(TextField), 'Première');
    await tester.tap(_dansDialogue('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(
      find.descendant(
        of: find.byType(RangeeActions),
        matching: find.text('Note'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Seconde');
    await tester.tap(_dansDialogue('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(
      _prospect(tester, 'p5').timeline.take(2).map((e) => e.detail).toList(),
      ['Seconde', 'Première'],
    );
  });
}
