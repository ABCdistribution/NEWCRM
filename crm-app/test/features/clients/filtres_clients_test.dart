import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/clients/clients_screen.dart';
import 'package:crm_app/features/clients/filtres_clients_sheet.dart';
import 'package:crm_app/features/clients/state/filtres_clients.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_clients.dart';

/// Feuille « Filtres » de la liste des clients : modale `mfiltres` l.1369-1377, actions `mag-*` l.1656-1659.
void main() {
  Future<void> ouvrirFiltres(WidgetTester tester) async {
    await tester.tap(find.byType(BoutonFiltre));
    await tester.pumpAndSettle();
  }

  Finder compteurFiltres(String n) =>
      find.descendant(of: find.byType(BoutonFiltre), matching: find.text(n));

  List<bool> radios(WidgetTester tester) => [
    for (final r in tester.widgetList<Radio20>(find.byType(Radio20)))
      r.selectionne,
  ];

  group('promoteur', () {
    testWidgets('les rubriques et les textes de la feuille', (tester) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
      await ouvrirFiltres(tester);
      expect(find.byType(FiltresClientsSheet), findsOneWidget);
      expect(find.text('Filtres'), findsOneWidget);
      expect(find.text('AFFICHER'), findsOneWidget);
      expect(find.text('Mon portefeuille (4)'), findsOneWidget);
      expect(find.text('Tous les clients du secteur (6)'), findsOneWidget);
      expect(find.text('ENSEIGNE'), findsOneWidget);
      expect(find.text('Toutes les enseignes'), findsOneWidget);
      expect(find.text('TRIER PAR'), findsOneWidget);
      expect(find.text('Nom (A → Z)'), findsOneWidget);
      expect(find.text('Classification (A → G)'), findsOneWidget);
      expect(find.text('Réinitialiser'), findsOneWidget);
      expect(find.text('Voir 4 clients'), findsOneWidget);
      // Choix initiaux : portefeuille, nom.
      expect(radios(tester), [true, false, true, false]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« tous les clients du secteur » s’applique tout de suite', (
      tester,
    ) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
      await ouvrirFiltres(tester);
      await tester.tap(find.text('Tous les clients du secteur (6)'));
      await tester.pumpAndSettle();
      expect(find.text('Voir 6 clients'), findsOneWidget);
      expect(radios(tester), [false, true, true, false]);
      expect(
        find.text('Tous les clients du secteur · 6 clients'),
        findsOneWidget,
      );
      expect(compteurFiltres('1'), findsOneWidget);

      await tester.tap(find.text('Voir 6 clients'));
      await tester.pumpAndSettle();
      expect(find.byType(FiltresClientsSheet), findsNothing);
    });

    testWidgets('tri par classification : A++ d’abord', (tester) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
      await ouvrirFiltres(tester);
      await tester.tap(find.text('Classification (A → G)'));
      await tester.pumpAndSettle();
      expect(radios(tester), [true, false, false, true]);
      expect(
        find.text('Mon portefeuille · 4 clients · triés par classe'),
        findsOneWidget,
      );
      expect(compteurFiltres('1'), findsOneWidget);
      expect(nomsClients(tester), [
        'Carrefour Market – Versailles', // A++
        'U Express – Boulogne-Billancourt', // B
        'U Express – Paris', // E
        'Carrefour – Ivry-sur-Seine', // F
      ]);
    });

    testWidgets('filtre par enseigne, avec le compte dans « Voir … »', (
      tester,
    ) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
      await ouvrirFiltres(tester);
      await tester.tap(find.text('Toutes les enseignes'));
      await tester.pumpAndSettle();
      // Enseignes du portefeuille, par ordre alphabétique.
      expect(find.text('Carrefour').last, findsOneWidget);
      expect(find.text('Carrefour Market').last, findsOneWidget);
      expect(find.text('U Express').last, findsOneWidget);
      expect(find.text('E.Leclerc'), findsNothing);
      await tester.tap(find.text('U Express').last);
      await tester.pumpAndSettle();
      expect(find.text('Voir 2 clients'), findsOneWidget);
      expect(nomsClients(tester), [
        'U Express – Boulogne-Billancourt',
        'U Express – Paris',
      ]);
      expect(compteurFiltres('1'), findsOneWidget);

      // Retour à « Toutes les enseignes ».
      await tester.tap(find.text('U Express').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toutes les enseignes').last);
      await tester.pumpAndSettle();
      expect(find.text('Voir 4 clients'), findsOneWidget);
      expect(compteurFiltres('1'), findsNothing);
    });

    testWidgets('« Voir 1 client » au singulier, recherche prise en compte', (
      tester,
    ) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
      await tester.enterText(find.byType(TextField), 'ivry');
      await tester.pumpAndSettle();
      await ouvrirFiltres(tester);
      expect(find.text('Voir 1 client'), findsOneWidget);
    });

    testWidgets(
      '« Réinitialiser » rétablit les filtres et garde la recherche',
      (tester) async {
        await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
        await tester.enterText(find.byType(TextField), 'u express');
        await tester.pumpAndSettle();
        await ouvrirFiltres(tester);
        await tester.tap(find.text('Tous les clients du secteur (6)'));
        await tester.tap(find.text('Classification (A → G)'));
        await tester.pumpAndSettle();
        expect(compteurFiltres('2'), findsOneWidget);

        await tester.tap(find.text('Réinitialiser'));
        await tester.pumpAndSettle();
        final f = conteneurDe(tester).read(filtresClientsProvider);
        expect(f.portee, PorteeClients.mes);
        expect(f.tri, TriClients.nom);
        expect(f.ens, isNull);
        expect(f.q, 'u express', reason: 'la recherche est conservée');
        expect(radios(tester), [true, false, true, false]);
        expect(compteurFiltres('2'), findsNothing);
        expect(find.text('Voir 2 clients'), findsOneWidget);
      },
    );
  });

  group('chef de secteur', () {
    testWidgets('pas de rubrique « Afficher » ni de portée', (tester) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.cs);
      await ouvrirFiltres(tester);
      expect(find.text('Filtres'), findsOneWidget);
      expect(find.text('AFFICHER'), findsNothing);
      expect(find.text('Mon portefeuille (4)'), findsNothing);
      expect(find.text('ENSEIGNE'), findsOneWidget);
      expect(find.text('TRIER PAR'), findsOneWidget);
      expect(find.text('Voir 6 clients'), findsOneWidget);
      expect(radios(tester), [true, false]);
    });

    testWidgets('le tri par classe s’affiche dans l’entête', (tester) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.cs);
      await ouvrirFiltres(tester);
      await tester.tap(find.text('Classification (A → G)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Clients de votre secteur · 6 clients · triés par classe'),
        findsOneWidget,
      );
      expect(compteurFiltres('1'), findsOneWidget);
      expect(nomsClients(tester), [
        'Carrefour Market – Versailles', // A++
        'E.Leclerc – Paris', // A+
        'U Express – Boulogne-Billancourt', // B
        'Carrefour – Versailles', // E : à classe égale, par le nom
        'U Express – Paris', // E
        'Carrefour – Ivry-sur-Seine', // F
      ]);
    });
  });

  group('directeur', () {
    testWidgets('« Tous les clients » (société) et « Clients de ma région »', (
      tester,
    ) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.dir);
      await ouvrirFiltres(tester);
      expect(find.text('Tous les clients (32)'), findsOneWidget);
      expect(find.text('Clients de ma région (10)'), findsOneWidget);
      expect(find.text('Voir 10 clients'), findsOneWidget);
      // Par défaut : la région.
      expect(radios(tester), [false, true, true, false]);

      await tester.tap(find.text('Tous les clients (32)'));
      await tester.pumpAndSettle();
      expect(find.text('Voir 32 clients'), findsOneWidget);
      expect(find.text('Tous les clients · 32 clients'), findsOneWidget);
      expect(compteurFiltres('1'), findsOneWidget);
    });

    testWidgets(
      'l’enseigne choisie réduit la liste des clients de la société',
      (tester) async {
        await pumpEcran(tester, const ClientsScreen(), role: Role.dir);
        await ouvrirFiltres(tester);
        await tester.tap(find.text('Tous les clients (32)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Toutes les enseignes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Auchan').last);
        await tester.pumpAndSettle();
        expect(find.text('Voir 3 clients'), findsOneWidget);
        expect(nomsClients(tester), [
          'Auchan – Avignon',
          'Auchan – Chambéry',
          'Auchan – Rouen',
        ]);
        expect(compteurFiltres('2'), findsOneWidget);
      },
    );

    testWidgets(
      'une enseigne absente de la nouvelle base reste appliquée mais la liste affiche « Toutes »',
      (tester) async {
        await pumpEcran(tester, const ClientsScreen(), role: Role.dir);
        await ouvrirFiltres(tester);
        await tester.tap(find.text('Tous les clients (32)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Toutes les enseignes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Auchan').last);
        await tester.pumpAndSettle();
        // Retour à la région : plus d'Auchan, le `<select>` revient sur « Toutes les enseignes ».
        await tester.tap(find.text('Clients de ma région (10)'));
        await tester.pumpAndSettle();
        expect(find.text('Toutes les enseignes'), findsOneWidget);
        expect(find.text('Voir 0 client'), findsOneWidget);
        expect(find.text('Aucun client.'), findsOneWidget);
      },
    );
  });
}
