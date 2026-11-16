import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/fiche_prospect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Feuille « Changer d'étape » : maquette `feuille-etape` l.1830-1832 et action `etape-vers` l.2028.
Future<void> _ouvrirFeuille(WidgetTester tester, String id, Role role) async {
  await pumpEcran(tester, FicheProspectScreen(prospectId: id), role: role);
  await tester.tap(find.text("Changer d'étape"));
  await tester.pumpAndSettle();
}

ProviderContainer _store(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FicheProspectScreen)));

Prospect _prospect(WidgetTester tester, String id) =>
    _store(tester).read(prospectParIdProvider(id))!;

/// Un texte de la feuille (la fiche dessous répète « RDV pris », « Fiche créée »…).
Finder _dansFeuille(String texte) =>
    find.descendant(of: find.byType(FeuilleBase), matching: find.text(texte));

void main() {
  testWidgets('six étapes de « Fiche créée » à « Perdu », sans « Référencé »', (
    tester,
  ) async {
    await _ouvrirFeuille(tester, 'p1', Role.cs);
    for (final e in [
      'Fiche créée',
      'Contacté',
      'RDV pris',
      'Proposition',
      'En négociation',
      'Perdu',
    ]) {
      expect(_dansFeuille(e), findsOneWidget, reason: e);
    }
    expect(_dansFeuille('Référencé'), findsNothing);
    expect(
      find.text("Changer d'étape"),
      findsNWidgets(2),
    ); // bouton et titre de la feuille
  });

  testWidgets('la coche est sur l’étape courante', (tester) async {
    await _ouvrirFeuille(tester, 'p1', Role.cs);
    expect(_dansFeuille('✓'), findsOneWidget);
    expect(
      tester.getCenter(_dansFeuille('✓')).dy,
      tester.getCenter(_dansFeuille('En négociation')).dy,
    );
  });

  testWidgets(
    'la coche suit le statut d’un autre prospect, vu par le directeur',
    (tester) async {
      await _ouvrirFeuille(tester, 'p3', Role.dir);
      expect(
        tester.getCenter(_dansFeuille('✓')).dy,
        tester.getCenter(_dansFeuille('RDV pris')).dy,
      );
    },
  );

  testWidgets(
    'toucher l’étape courante ne fait rien : la feuille reste ouverte',
    (tester) async {
      await _ouvrirFeuille(tester, 'p1', Role.cs);
      final avant = _prospect(tester, 'p1');
      await tester.tap(_dansFeuille('En négociation'));
      await tester.pumpAndSettle();
      expect(find.byType(FeuilleBase), findsOneWidget);
      expect(find.textContaining('Étape : '), findsNothing);
      final apres = _prospect(tester, 'p1');
      expect(apres.statut, avant.statut);
      expect(apres.timeline.length, avant.timeline.length);
    },
  );

  testWidgets(
    'choisir « Contacté » change le statut, la probabilité et la timeline',
    (tester) async {
      await _ouvrirFeuille(tester, 'p1', Role.cs);
      await tester.tap(_dansFeuille('Contacté'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FeuilleBase), findsNothing);
      expect(find.text('Étape : Contacté.'), findsOneWidget);
      final p = _prospect(tester, 'p1');
      expect(p.statut, StatutProspect.contacte);
      expect(p.proba, 20);
      expect(p.timeline.first.titre, 'Étape → Contacté');
      expect(p.timeline.first.date, 'auj.');
      expect(
        p.timeline.first.detail,
        'Passé de « En négociation » à « Contacté »',
      );
      expect(p.timeline.length, 6);
      // La fiche derrière reflète le changement.
      expect(find.text('Prospect · À contacter'), findsOneWidget);
      expect(find.text('Probabilité 20 %'), findsOneWidget);
      expect(find.text('Étape → Contacté'), findsOneWidget);
      expect(
        find.text('Passé de « En négociation » à « Contacté »'),
        findsOneWidget,
      );
      expect(tester.widget<EtapesBarre>(find.byType(EtapesBarre)).segments, 2);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('les probabilités par défaut de chaque étape', (tester) async {
    for (final (libelle, statut, proba) in [
      ('Fiche créée', StatutProspect.nouveau, 10),
      ('RDV pris', StatutProspect.visite, 40),
      ('Proposition', StatutProspect.proposition, 55),
      ('Perdu', StatutProspect.perdu, 0),
    ]) {
      await _ouvrirFeuille(tester, 'p1', Role.cs);
      await tester.tap(_dansFeuille(libelle));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      final p = _prospect(tester, 'p1');
      expect(p.statut, statut, reason: libelle);
      expect(p.proba, proba, reason: libelle);
      // On repart d'un état neuf pour l'étape suivante.
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    '« Perdu » : Prospect · Perdu, probabilité 0 %, un seul segment',
    (tester) async {
      await _ouvrirFeuille(tester, 'p1', Role.cs);
      await tester.tap(_dansFeuille('Perdu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Étape : Perdu.'), findsOneWidget);
      expect(find.text('Prospect · Perdu'), findsOneWidget);
      expect(find.text('Probabilité 0 %'), findsOneWidget);
      expect(tester.widget<EtapesBarre>(find.byType(EtapesBarre)).segments, 1);
      expect(find.text('Passer en client'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('un toucher sur le voile ferme la feuille sans rien changer', (
    tester,
  ) async {
    await _ouvrirFeuille(tester, 'p1', Role.cs);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(find.byType(FeuilleBase), findsNothing);
    expect(_prospect(tester, 'p1').statut, StatutProspect.negociation);
  });
}
