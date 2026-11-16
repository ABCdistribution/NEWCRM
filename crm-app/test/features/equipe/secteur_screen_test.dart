import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/equipe/choix_client_secteur_sheet.dart';
import 'package:crm_app/features/equipe/filtres_secteur_sheet.dart';
import 'package:crm_app/features/equipe/secteur_screen.dart';
import 'package:crm_app/features/equipe/state/equipe_state.dart';
import 'package:crm_app/features/equipe/state/filtres.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Onglets « Visites » et « Commandes » du secteur du chef de secteur (maquette : `pageSecteur` l.922-932, feuilles
/// `sec-filtres` l.1845-1853 et `sec-client` l.1865-1868).
ProviderContainer _conteneur(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(SecteurScreen)));

Finder _dansFiltres(String texte) => find.descendant(
  of: find.byType(FiltresSecteurSheet),
  matching: find.text(texte),
);

Finder _dansChoix(String texte) => find.descendant(
  of: find.byType(ChoixClientSecteurSheet),
  matching: find.text(texte),
);

Finder _pastilleFiltre(String n) =>
    find.descendant(of: find.byType(BoutonFiltre), matching: find.text(n));

Future<void> _ouvrirFiltres(WidgetTester tester) async {
  await tester.tap(find.byType(BoutonFiltre));
  await tester.pumpAndSettle();
}

Future<void> _appliquer(WidgetTester tester) async {
  await tester.tap(find.text('Appliquer'));
  await tester.pumpAndSettle();
}

void main() {
  group('visites du secteur', () {
    testWidgets('24 visites, les plus récentes d’abord, lecture seule', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.visites),
        role: Role.cs,
      );
      expect(find.text('Visites'), findsOneWidget);
      expect(
        find.text('24 visites · les plus récentes en premier'),
        findsOneWidget,
      );
      expect(find.text('Visites du secteur'), findsOneWidget);
      expect(find.text('4 nov. 09:00 · Moi'), findsOneWidget);
      expect(find.text('4 nov. 09:00 · Julien M.'), findsOneWidget);
      expect(find.text('4 nov. 09:00 · Amine K.'), findsOneWidget);
      expect(find.text('29 oct. 14:30 · Léa P.'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget); // la visite d'Amine K.
      expect(find.text('Envoyée'), findsNWidgets(23));
      expect(find.text('Lecture seule.'), findsOneWidget);
      // Aucun filtre : pas de pastille sur le bouton.
      expect(
        find.descendant(
          of: find.byType(BoutonFiltre),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      // Tri : la première carte est celle du 4 nov. 09:00 de Nadia H. (« Moi »).
      final premiere = tester.getTopLeft(find.text('4 nov. 09:00 · Moi'));
      final derniere = tester.getTopLeft(find.text('29 oct. 14:30 · Amine K.'));
      expect(premiere.dy, lessThan(derniere.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('les filtres « Mes visites », promoteur et client', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.visites),
        role: Role.cs,
      );
      await _ouvrirFiltres(tester);
      expect(_dansFiltres('Filtres'), findsOneWidget);
      expect(_dansFiltres('AFFICHER'), findsOneWidget);
      expect(_dansFiltres('Toutes les visites de mon secteur'), findsOneWidget);
      expect(_dansFiltres('Mes visites'), findsOneWidget);
      expect(_dansFiltres('PROMOTEUR'), findsOneWidget);
      expect(_dansFiltres('Tous les promoteurs'), findsOneWidget);
      for (final p in ['Julien M.', 'Léa P.', 'Amine K.']) {
        expect(_dansFiltres(p), findsOneWidget, reason: p);
      }
      // Pas de type de commande pour les visites.
      expect(_dansFiltres('TYPE DE COMMANDE'), findsNothing);
      expect(_dansFiltres('CLIENT'), findsOneWidget);
      expect(_dansFiltres('Tous les clients'), findsOneWidget);

      await tester.tap(_dansFiltres('Mes visites'));
      await tester.pumpAndSettle();
      // La liste derrière la feuille est déjà filtrée.
      expect(
        find.text('6 visites · les plus récentes en premier'),
        findsOneWidget,
      );
      await _appliquer(tester);
      expect(find.byType(FiltresSecteurSheet), findsNothing);
      expect(find.text('Mes visites'), findsOneWidget);
      expect(_pastilleFiltre('1'), findsOneWidget);
      expect(find.text('4 nov. 09:00 · Julien M.'), findsNothing);

      // Avec un promoteur en plus : plus aucune visite (« Mes visites » de Léa P. : aucune).
      await _ouvrirFiltres(tester);
      await tester.tap(_dansFiltres('Léa P.'));
      await tester.pumpAndSettle();
      await _appliquer(tester);
      expect(find.text('Aucun résultat avec ces filtres.'), findsOneWidget);
      expect(
        find.text('0 visite · les plus récentes en premier'),
        findsOneWidget,
      );
      expect(find.text('Mes visites · Léa P.'), findsOneWidget);
      expect(_pastilleFiltre('2'), findsOneWidget);
      expect(find.text('Lecture seule.'), findsOneWidget);
    });

    testWidgets('« Choisir un client » revient aux filtres avec le client', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.visites),
        role: Role.cs,
      );
      await _ouvrirFiltres(tester);
      await tester.tap(_dansFiltres('Tous les clients'));
      await tester.pumpAndSettle();
      // Une seule feuille à la fois : le choix du client remplace les filtres.
      expect(find.byType(FiltresSecteurSheet), findsNothing);
      expect(find.byType(ChoixClientSecteurSheet), findsOneWidget);
      expect(_dansChoix('Choisir un client'), findsOneWidget);
      expect(_dansChoix('Tous les clients'), findsOneWidget);
      expect(_dansChoix('Auchan – Rouen'), findsOneWidget);
      expect(_dansChoix('U Express – Boulogne-Billancourt'), findsOneWidget);
      expect(
        find.byType(OptionRadio),
        findsNWidgets(12),
      ); // « Tous » + 11 clients

      await tester.tap(_dansChoix('Auchan – Rouen'));
      await tester.pumpAndSettle();
      expect(find.byType(ChoixClientSecteurSheet), findsNothing);
      expect(find.byType(FiltresSecteurSheet), findsOneWidget);
      expect(_dansFiltres('Auchan – Rouen'), findsOneWidget);
      expect(_dansFiltres('Tous les clients'), findsNothing);
      expect(
        _conteneur(tester).read(filtresSecteurProvider).visites.client,
        'Auchan – Rouen',
      );
      await _appliquer(tester);
      expect(
        find.text('1 visite · les plus récentes en premier'),
        findsOneWidget,
      );
      expect(find.text('Visites du secteur · Auchan – Rouen'), findsOneWidget);
      expect(find.text('2 nov. 12:30 · Moi'), findsOneWidget);
      expect(_pastilleFiltre('1'), findsOneWidget);
    });

    testWidgets('le choix du client montre le client déjà retenu', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.visites),
        role: Role.cs,
      );
      _conteneur(tester)
          .read(filtresSecteurProvider.notifier)
          .maj(
            GenreSecteur.visites,
            (f) => f.copyWith(client: 'E.Leclerc – Paris'),
          );
      await _ouvrirFiltres(tester);
      await tester.tap(_dansFiltres('E.Leclerc – Paris'));
      await tester.pumpAndSettle();
      final radios = tester
          .widgetList<Radio20>(find.byType(Radio20))
          .where((r) => r.selectionne);
      expect(radios, hasLength(1));
      // La feuille « Choisir un client » est limitée à 80 % de la hauteur de l'écran (780 dp).
      final feuille = tester.getSize(find.byType(FeuilleBase));
      expect(feuille.height, lessThanOrEqualTo(780 * 0.8 + 0.5));
    });

    testWidgets('« Réinitialiser » rétablit tous les filtres de la liste', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.visites),
        role: Role.cs,
      );
      final notifier = _conteneur(tester).read(filtresSecteurProvider.notifier);
      notifier.maj(
        GenreSecteur.visites,
        (f) => f.copyWith(portee: PorteeSecteur.moi, promo: 'Amine K.'),
      );
      notifier.maj(
        GenreSecteur.commandes,
        (f) => f.copyWith(src: SourceCommande.edi),
      );
      await tester.pumpAndSettle();
      await _ouvrirFiltres(tester);
      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();
      final f = _conteneur(tester).read(filtresSecteurProvider);
      expect(f.visites.nb, 0);
      // Les commandes gardent leur propre filtre.
      expect(f.commandes.src, SourceCommande.edi);
      expect(find.byType(FiltresSecteurSheet), findsOneWidget);
      expect(
        find.text('24 visites · les plus récentes en premier'),
        findsOneWidget,
      );
    });
  });

  group('commandes du secteur', () {
    testWidgets('13 commandes, montant, détail, origine et livraison', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.commandes),
        role: Role.cs,
      );
      expect(find.text('Commandes'), findsOneWidget);
      expect(
        find.text('13 commandes · les plus récentes en premier'),
        findsOneWidget,
      );
      expect(find.text('Commandes du secteur'), findsOneWidget);
      expect(
        find.text('CDE-2041 · Super U – Versailles · 3 nov. · Moi · EDI'),
        findsOneWidget,
      );
      expect(
        find.text(
          'CDE-2046 · U Express – Boulogne-Billancourt · 3 nov. · Julien M. · Appli',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'CDE-2032 · Carrefour Market – Rouen · 30 oct. · Léa P. · Appli',
        ),
        findsOneWidget,
      );
      expect(find.text('1 540,00 € HT'), findsNWidgets(4));
      expect(find.text('958,70 € HT'), findsNWidgets(4));
      expect(find.text('Livrée'), findsNWidgets(5));
      expect(find.text('Pas livrée'), findsNWidgets(8));
      expect(find.text('Lecture seule.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la feuille de filtres propose le type de commande', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.commandes),
        role: Role.cs,
      );
      await _ouvrirFiltres(tester);
      expect(
        _dansFiltres('Toutes les commandes de mon secteur'),
        findsOneWidget,
      );
      expect(_dansFiltres('Mes commandes'), findsOneWidget);
      expect(_dansFiltres('TYPE DE COMMANDE'), findsOneWidget);
      expect(_dansFiltres('Toutes les commandes'), findsOneWidget);
      expect(_dansFiltres('Commandes EDI'), findsOneWidget);
      expect(_dansFiltres('Commandes appli'), findsOneWidget);

      await tester.tap(_dansFiltres('Commandes EDI'));
      await tester.pumpAndSettle();
      await _appliquer(tester);
      expect(
        find.text('4 commandes · les plus récentes en premier'),
        findsOneWidget,
      );
      expect(find.text('Commandes du secteur · Commandes EDI'), findsOneWidget);
      expect(_pastilleFiltre('1'), findsOneWidget);

      await _ouvrirFiltres(tester);
      await tester.tap(_dansFiltres('Mes commandes'));
      await tester.pumpAndSettle();
      await _appliquer(tester);
      expect(
        find.text('1 commande · les plus récentes en premier'),
        findsOneWidget,
      );
      expect(find.text('Mes commandes · Commandes EDI'), findsOneWidget);
      expect(_pastilleFiltre('2'), findsOneWidget);
    });

    testWidgets('promoteur et client combinés, liste vide', (tester) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.commandes),
        role: Role.cs,
      );
      await _ouvrirFiltres(tester);
      await tester.tap(_dansFiltres('Léa P.'));
      await tester.pumpAndSettle();
      expect(
        find.text('4 commandes · les plus récentes en premier'),
        findsOneWidget,
      );
      await tester.tap(_dansFiltres('Tous les clients'));
      await tester.pumpAndSettle();
      // Les clients proposés sont ceux des commandes : dix, plus « Tous ».
      expect(find.byType(OptionRadio), findsNWidgets(11));
      await tester.tap(_dansChoix('Auchan – Rouen'));
      await tester.pumpAndSettle();
      await _appliquer(tester);
      expect(find.text('Aucun résultat avec ces filtres.'), findsOneWidget);
      expect(
        find.text('0 commande · les plus récentes en premier'),
        findsOneWidget,
      );
      expect(
        find.text('Commandes du secteur · Léa P. · Auchan – Rouen'),
        findsOneWidget,
      );
      expect(_pastilleFiltre('2'), findsOneWidget);
    });

    testWidgets('les filtres des visites et des commandes sont indépendants', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.commandes),
        role: Role.cs,
      );
      _conteneur(tester)
          .read(filtresSecteurProvider.notifier)
          .maj(GenreSecteur.visites, (f) => f.copyWith(promo: 'Julien M.'));
      await tester.pumpAndSettle();
      expect(
        find.text('13 commandes · les plus récentes en premier'),
        findsOneWidget,
      );
      expect(find.text('Commandes du secteur'), findsOneWidget);
    });

    testWidgets('les filtres reviennent à zéro au changement de profil', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const SecteurScreen(genre: GenreSecteur.commandes),
        role: Role.cs,
      );
      final c = _conteneur(tester);
      c
          .read(filtresSecteurProvider.notifier)
          .maj(GenreSecteur.commandes, (f) => f.copyWith(promo: 'Léa P.'));
      expect(c.read(filtresSecteurProvider).commandes.nb, 1);
      c.read(roleProvider.notifier).choisir(Role.dir);
      expect(c.read(filtresSecteurProvider).commandes.nb, 0);
    });
  });
}
