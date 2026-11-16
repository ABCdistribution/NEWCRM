import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/fiche_prospect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Dialogue « Passer en client ? » : maquette `confirm` l.1833-1835 et actions `en-client`, `en-client-ok` l.2029-2030.
Future<void> _ouvrirDialogue(WidgetTester tester, String id, Role role) async {
  await pumpEcran(tester, FicheProspectScreen(prospectId: id), role: role);
  await tester.tap(find.text('Passer en client'));
  await tester.pumpAndSettle();
}

Prospect _prospect(WidgetTester tester, String id) => ProviderScope.containerOf(
  tester.element(find.byType(FicheProspectScreen)),
).read(prospectParIdProvider(id))!;

Finder _dansDialogue(String texte) =>
    find.descendant(of: find.byType(Dialog), matching: find.text(texte));

void main() {
  testWidgets('le dialogue pose la question et propose deux boutons', (
    tester,
  ) async {
    await _ouvrirDialogue(tester, 'p1', Role.cs);
    expect(_dansDialogue('Passer en client ?'), findsOneWidget);
    expect(
      _dansDialogue(
        'Le prospect devient un client, avec ses contacts, notes et visites. Cette action est définitive.',
      ),
      findsOneWidget,
    );
    expect(_dansDialogue('Annuler'), findsOneWidget);
    expect(_dansDialogue('Passer en client'), findsOneWidget);
  });

  testWidgets('« Annuler » ferme le dialogue sans toucher au prospect', (
    tester,
  ) async {
    await _ouvrirDialogue(tester, 'p1', Role.cs);
    await tester.tap(_dansDialogue('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final p = _prospect(tester, 'p1');
    expect(p.statut, StatutProspect.negociation);
    expect(p.proba, 60);
    expect(p.timeline.length, 5);
    expect(find.text('Prospect · En négo'), findsOneWidget);
  });

  testWidgets('un toucher sur le voile ferme le dialogue', (tester) async {
    await _ouvrirDialogue(tester, 'p1', Role.cs);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(_prospect(tester, 'p1').statut, StatutProspect.negociation);
  });

  testWidgets('« Passer en client » référence le prospect à 100 %', (
    tester,
  ) async {
    await _ouvrirDialogue(tester, 'p1', Role.cs);
    await tester.tap(_dansDialogue('Passer en client'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(Dialog), findsNothing);
    expect(
      find.text('Le prospect est maintenant un client.'),
      findsNWidgets(2), // toast et détail de l'événement de timeline
    );
    final p = _prospect(tester, 'p1');
    expect(p.statut, StatutProspect.gagne);
    expect(p.proba, 100);
    expect(p.timeline.length, 6);
    expect(p.timeline.first.titre, 'Étape → Référencé');
    expect(p.timeline.first.date, 'auj.');
    expect(p.timeline.first.detail, 'Le prospect est maintenant un client.');
    // La fiche reflète le changement : badge, probabilité, segments, bouton retiré.
    expect(find.text('Prospect · Référencé'), findsOneWidget);
    expect(find.text('Probabilité 100 %'), findsOneWidget);
    expect(find.text('Étape → Référencé'), findsOneWidget);
    expect(tester.widget<EtapesBarre>(find.byType(EtapesBarre)).segments, 5);
    expect(find.text('Passer en client'), findsNothing);
    expect(find.text("Changer d'étape"), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('le directeur passe en client un prospect d’un autre secteur', (
    tester,
  ) async {
    await _ouvrirDialogue(tester, 'p3', Role.dir);
    await tester.tap(_dansDialogue('Passer en client'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_prospect(tester, 'p3').statut, StatutProspect.gagne);
    expect(find.text('Prospect · Référencé'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
