import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/clients/clients_screen.dart';
import 'package:crm_app/features/clients/state/filtres_clients.dart';
import 'package:crm_app/features/clients/widgets/carte_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_clients.dart';

/// Onglet « Clients » : promoteur (`salesMagasins` l.1227-1235), chef de secteur et directeur (`pageMagasins`
/// l.689-695), liste `magasinsListe` l.1222-1226.
void main() {
  group('promoteur (Julien M.)', () {
    testWidgets('entête, recherche et liste de son portefeuille', (
      tester,
    ) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('Mon portefeuille · 4 clients'), findsOneWidget);
      expect(find.text('Enseigne, ville, code…'), findsOneWidget);
      expect(find.text('Voir tous les clients du secteur (6)'), findsOneWidget);
      expect(find.text('›'), findsOneWidget);
      // Tri par nom : « Carrefour – … » avant « Carrefour Market – … ».
      expect(nomsClients(tester), [
        'Carrefour – Ivry-sur-Seine',
        'Carrefour Market – Versailles',
        'U Express – Boulogne-Billancourt',
        'U Express – Paris',
      ]);
      expect(
        find.text('23 avenue de la République, 94200 Ivry-sur-Seine'),
        findsOneWidget,
      );
      expect(find.text('Classe F'), findsOneWidget);
      expect(find.text('Classe A++'), findsOneWidget);
      expect(find.text('Classe B'), findsOneWidget);
      // Client inactif : pastille grise « Inactif · Classe E ».
      expect(find.text('Inactif · Classe E'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BoutonFiltre),
          matching: find.byType(Text),
        ),
        findsNothing,
        reason: 'aucun filtre actif : pas de compteur',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Voir tous les clients du secteur » bascule la portée', (
      tester,
    ) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
      await tester.tap(find.text('Voir tous les clients du secteur (6)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tous les clients du secteur · 6 clients'),
        findsOneWidget,
      );
      expect(find.text('Revenir à mon portefeuille (4)'), findsOneWidget);
      expect(nomsClients(tester), [
        'Carrefour – Ivry-sur-Seine',
        'Carrefour – Versailles',
        'Carrefour Market – Versailles',
        'E.Leclerc – Paris',
        'U Express – Boulogne-Billancourt',
        'U Express – Paris',
      ]);
      // La portée n'est plus celle par défaut : un filtre actif.
      expect(
        find.descendant(
          of: find.byType(BoutonFiltre),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Revenir à mon portefeuille (4)'));
      await tester.pumpAndSettle();
      expect(find.text('Mon portefeuille · 4 clients'), findsOneWidget);
      expect(find.text('Voir tous les clients du secteur (6)'), findsOneWidget);
    });

    testWidgets('la recherche porte sur le nom et l’adresse, sans casse', (
      tester,
    ) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
      await tester.enterText(find.byType(TextField), 'VERSAILLES');
      await tester.pumpAndSettle();
      // Nom ou adresse : Carrefour Market – Versailles seulement dans le portefeuille.
      expect(nomsClients(tester), ['Carrefour Market – Versailles']);
      expect(find.text('Mon portefeuille · 1 client'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ivry');
      await tester.pumpAndSettle();
      expect(nomsClients(tester), ['Carrefour – Ivry-sur-Seine']);

      // Adresse seule : « avenue Victor Hugo » (U Express – Paris).
      await tester.enterText(find.byType(TextField), 'victor hugo');
      await tester.pumpAndSettle();
      expect(nomsClients(tester), ['U Express – Paris']);
    });

    testWidgets('aucun résultat : « Aucun client. »', (tester) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.promoteur);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Aucun client.'), findsOneWidget);
      expect(find.text('Mon portefeuille · 0 client'), findsOneWidget);
      expect(nomsClients(tester), isEmpty);
    });

    testWidgets('un appui sur une carte ouvre la fiche du client', (
      tester,
    ) async {
      final routes = await pumpEcranObserve(
        tester,
        const ClientsScreen(),
        role: Role.promoteur,
      );
      await tester.tap(find.text('Carrefour Market – Versailles'));
      await tester.pumpAndSettle();
      expect(routes.noms, contains('magasin'));
      expect(find.text('Client · À relancer'), findsOneWidget);
      expect(
        find.text('Classe A++ · 104 avenue des Champs, 78000 Versailles'),
        findsOneWidget,
      );
    });
  });

  group('chef de secteur (Nadia H.)', () {
    testWidgets('liste de tout le secteur, sans bascule de portée', (
      tester,
    ) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.cs);
      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('Clients de votre secteur · 6 clients'), findsOneWidget);
      expect(find.text('Rechercher un client…'), findsOneWidget);
      expect(find.byType(LienPortee), findsNothing);
      expect(nomsClients(tester), [
        'Carrefour – Ivry-sur-Seine',
        'Carrefour – Versailles',
        'Carrefour Market – Versailles',
        'E.Leclerc – Paris',
        'U Express – Boulogne-Billancourt',
        'U Express – Paris',
      ]);
      expect(find.text('Classe E'), findsOneWidget);
      expect(find.text('Inactif · Classe E'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('recherche : aucun client trouvé', (tester) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.cs);
      await tester.enterText(find.byType(TextField), 'amiens');
      await tester.pumpAndSettle();
      // Super U – Amiens est dans l'autre secteur.
      expect(find.text('Aucun client.'), findsOneWidget);
      expect(find.text('Clients de votre secteur · 0 client'), findsOneWidget);
    });
  });

  group('directeur (Cindy R.)', () {
    testWidgets('liste de toute la région', (tester) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.dir);
      expect(find.text('Clients de ma région · 10 clients'), findsOneWidget);
      expect(find.text('Rechercher un client…'), findsOneWidget);
      expect(find.byType(LienPortee), findsNothing);
      expect(nomsClients(tester), [
        'Carrefour – Ivry-sur-Seine',
        'Carrefour – Rouen',
        'Carrefour – Versailles',
        'Carrefour Market – Rouen',
        'Carrefour Market – Versailles',
        'E.Leclerc – Paris',
        'Monoprix – Caen',
        'Super U – Amiens',
        'U Express – Boulogne-Billancourt',
        'U Express – Paris',
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la recherche trouve un client de la région', (tester) async {
      await pumpEcran(tester, const ClientsScreen(), role: Role.dir);
      await tester.enterText(find.byType(TextField), 'amiens');
      await tester.pumpAndSettle();
      expect(nomsClients(tester), ['Super U – Amiens']);
      expect(find.text('Clients de ma région · 1 client'), findsOneWidget);
    });

    testWidgets(
      '« Tous les clients » du directeur inclut les clients hors région',
      (tester) async {
        await pumpEcran(tester, const ClientsScreen(), role: Role.dir);
        final c = conteneurDe(tester);
        c
            .read(filtresClientsProvider.notifier)
            .choisirPortee(PorteeClients.mes);
        await tester.pumpAndSettle();
        expect(find.text('Tous les clients · 32 clients'), findsOneWidget);
        expect(nomsClients(tester), hasLength(32));
        await tester.enterText(find.byType(TextField), 'avignon');
        await tester.pumpAndSettle();
        expect(nomsClients(tester), [
          'Auchan – Avignon',
          'Intermarché – Avignon',
          'Super U – Avignon',
          'Super U – Avignon (2)',
        ]);
      },
    );
  });

  testWidgets('la recherche survit au changement d’onglet', (tester) async {
    await lancerApp(tester, Role.cs);
    Finder dansNav(String l) =>
        find.descendant(of: find.byType(AppNavBar), matching: find.text(l));
    await tester.tap(dansNav('Clients'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rouen');
    await tester.pumpAndSettle();
    // Dans le secteur de Nadia H. : aucun client à Rouen.
    expect(find.text('Aucun client.'), findsOneWidget);

    await tester.tap(dansNav('Accueil'));
    await tester.pumpAndSettle();
    await tester.tap(dansNav('Clients'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun client.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'rouen'), findsOneWidget);
  });

  test('changer de profil remet les filtres à zéro', () {
    final c = conteneurPour(Role.promoteur);
    final ecoute = c.listen(filtresClientsProvider, (_, _) {});
    c.read(filtresClientsProvider.notifier)
      ..rechercher('abc')
      ..choisirTri(TriClients.classe)
      ..choisirEnseigne('Carrefour');
    expect(ecoute.read().tri, TriClients.classe);
    expect(ecoute.read().portee, PorteeClients.mes);

    c.read(roleProvider.notifier).choisir(Role.dir);
    final f = ecoute.read();
    expect(f.q, '');
    expect(f.tri, TriClients.nom);
    expect(f.ens, isNull);
    expect(f.portee, PorteeClients.tous);
  });
}
