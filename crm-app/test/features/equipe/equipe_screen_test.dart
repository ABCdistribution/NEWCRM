import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/equipe/chef_secteur_screen.dart';
import 'package:crm_app/features/equipe/data/equipe_demo.dart';
import 'package:crm_app/features/equipe/equipe_screen.dart';
import 'package:crm_app/features/equipe/filtres_equipe_sheet.dart';
import 'package:crm_app/features/equipe/promoteur_screen.dart';
import 'package:crm_app/features/equipe/state/equipe_state.dart';
import 'package:crm_app/features/equipe/state/filtres.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Onglet « Mon équipe » (maquette : `pageEquipePilot` l.933-950, `ligneProm` l.767-769, feuille `eq-filtres` l.1869-1876).
ProviderContainer _conteneur(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(EquipeScreen, skipOffstage: false)),
);

Finder _dansFeuille(String texte) => find.descendant(
  of: find.byType(FiltresEquipeSheet),
  matching: find.text(texte),
);

Future<void> _ouvrirFiltres(WidgetTester tester) async {
  await tester.tap(find.byType(BoutonFiltre));
  await tester.pumpAndSettle();
}

Future<void> _toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('chef de secteur : les promoteurs de son secteur', () {
    testWidgets('entête, trois promoteurs et pied', (tester) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.cs);
      expect(find.text('Mon équipe'), findsOneWidget);
      expect(find.text('3 promoteurs · Île-de-France'), findsOneWidget);
      for (final nom in ['Julien M.', 'Léa P.', 'Amine K.']) {
        expect(find.text(nom), findsOneWidget, reason: nom);
      }
      expect(find.text('JM'), findsOneWidget);
      expect(
        find.text('3 clients · 8/10 visites cette semaine'),
        findsOneWidget,
      );
      expect(
        find.text('4 clients · 6/9 visites cette semaine'),
        findsOneWidget,
      );
      expect(
        find.text('3 clients · 9/9 visites cette semaine'),
        findsOneWidget,
      );
      expect(find.text(eur(4200)), findsOneWidget);
      expect(find.text('sur ${eur(4900)}'), findsOneWidget);
      expect(find.text(eur(5800)), findsOneWidget);
      expect(find.text('sur ${eur(5700)}'), findsOneWidget);
      expect(
        find.text(
          'Touchez un promoteur pour voir ses visites et ses commandes.',
        ),
        findsOneWidget,
      );
      // Pas de filtre ni de liste de chefs de secteur pour le chef de secteur.
      expect(find.byType(BoutonFiltre), findsNothing);
      expect(find.text('Chefs de secteur'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tournée du jour de chaque promoteur', (tester) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.cs);
      expect(find.text("Aujourd'hui : 1/2 visites faites"), findsNWidgets(3));
      expect(find.text('En visite · Auchan – Rouen'), findsOneWidget);
      // Léa P. est à 71 % : pas « en retard » (seuil de 70 %).
      expect(find.text("En retard sur l'objectif"), findsNothing);
    });

    testWidgets('un appui sur un promoteur ouvre sa page', (tester) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.cs);
      await _toucher(tester, find.text('Léa P.'));
      expect(find.byType(PromoteurScreen), findsOneWidget);
      expect(find.text('Promoteur · 4 clients'), findsOneWidget);
      await tester.tap(find.byType(BoutonRetour));
      await tester.pumpAndSettle();
      expect(find.byType(PromoteurScreen), findsNothing);
    });
  });

  group('directeur : chefs de secteur et promoteurs', () {
    testWidgets('liste des chefs de secteur par défaut', (tester) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.dir);
      expect(find.text('Mon équipe'), findsOneWidget);
      expect(find.text('3 chefs de secteur · 8 promoteurs'), findsOneWidget);
      expect(
        find.text('Chefs de secteur'),
        findsNWidgets(2),
      ); // sélecteur + titre
      expect(find.text('3'), findsOneWidget); // compteur du titre
      for (final nom in ['Nadia H.', 'Karim B.', 'Sophie L.']) {
        expect(find.text(nom), findsOneWidget, reason: nom);
      }
      expect(
        find.text('Île-de-France · Secteur Île-de-France · 3 promoteurs'),
        findsOneWidget,
      );
      expect(
        find.text('Nord · Secteur Normandie / Hauts-de-France · 3 promoteurs'),
        findsOneWidget,
      );
      expect(
        find.text('Sud-Est · Secteur Sud-Est · 2 promoteurs'),
        findsOneWidget,
      );
      expect(find.text('Prévision enregistrée'), findsNWidgets(2));
      expect(find.text('Prévision non renseignée'), findsOneWidget);
      expect(find.text('Rapport en cours'), findsNWidgets(3));
      expect(find.text('60 % du prévu à ce jour'), findsOneWidget);
      expect(find.text('+1 ajoutée · 1 retirée'), findsOneWidget);
      expect(find.text('75 % du prévu à ce jour'), findsOneWidget);
      expect(find.text('aucun écart'), findsOneWidget);
      expect(
        find.text('Pas de comparaison possible cette semaine'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Touchez un chef de secteur ou un promoteur pour voir son activité (lecture seule).',
        ),
        findsOneWidget,
      );
      // Aucun filtre actif : pas de pastille sur le bouton.
      expect(
        find.descendant(
          of: find.byType(BoutonFiltre),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('la feuille de filtres : afficher les promoteurs', (
      tester,
    ) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.dir);
      await _ouvrirFiltres(tester);
      expect(find.byType(FiltresEquipeSheet), findsOneWidget);
      expect(_dansFeuille('Filtres'), findsOneWidget);
      expect(_dansFeuille('AFFICHER'), findsOneWidget);
      expect(_dansFeuille('Chefs de secteur'), findsOneWidget);
      expect(_dansFeuille('Promoteurs'), findsOneWidget);
      expect(_dansFeuille('RÉGION'), findsOneWidget);
      for (final r in [
        'Toutes les régions',
        'Île-de-France',
        'Nord',
        'Sud-Est',
      ]) {
        expect(_dansFeuille(r), findsOneWidget, reason: r);
      }
      await tester.tap(_dansFeuille('Promoteurs'));
      await tester.pumpAndSettle();
      expect(
        _conteneur(tester).read(filtresEquipeProvider).type,
        TypeEquipe.promoteurs,
      );
      // La liste derrière la feuille suit aussitôt le choix (le directeur voit le nom du chef de secteur).
      expect(
        find.text('Julien M. · Nadia H.', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Inès G. · Karim B.', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Maëlle S. · Sophie L.', skipOffstage: false),
        findsOneWidget,
      );
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      expect(find.byType(FiltresEquipeSheet), findsNothing);

      expect(find.text('3 chefs de secteur · 8 promoteurs'), findsOneWidget);
      expect(find.text('Promoteurs'), findsNWidgets(2)); // sélecteur + titre
      expect(find.text('8'), findsOneWidget); // compteur du titre
      expect(find.text('Prévision enregistrée'), findsNothing);
      expect(find.text('Nadia H.'), findsNothing);
      // Un filtre actif : pastille « 1 ».
      expect(
        find.descendant(
          of: find.byType(BoutonFiltre),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      // Fait ressortir les promoteurs en retard sur leur objectif.
      expect(
        find.text("En retard sur l'objectif", skipOffstage: false),
        findsNWidgets(2),
      );
    });

    testWidgets('filtre par région : un seul chef de secteur', (tester) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.dir);
      await _ouvrirFiltres(tester);
      await tester.tap(_dansFeuille('Sud-Est'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      expect(
        find.text('1 chef de secteur · 2 promoteurs · Sud-Est'),
        findsOneWidget,
      );
      expect(find.text('Chefs de secteur · Sud-Est'), findsOneWidget);
      expect(find.text('Sophie L.'), findsOneWidget);
      expect(find.text('Nadia H.'), findsNothing);
      expect(find.text('Karim B.'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BoutonFiltre),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      // Promoteurs de cette région : les deux de Sophie L.
      await _ouvrirFiltres(tester);
      await tester.tap(_dansFeuille('Promoteurs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      expect(find.text('Promoteurs · Sud-Est'), findsOneWidget);
      expect(find.text('Hugo T. · Sophie L.'), findsOneWidget);
      expect(find.text('Maëlle S. · Sophie L.'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(BoutonFiltre),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      '« Réinitialiser » revient aux chefs de secteur de toutes les régions',
      (tester) async {
        await pumpEcran(tester, const EquipeScreen(), role: Role.dir);
        await _ouvrirFiltres(tester);
        await tester.tap(_dansFeuille('Nord'));
        await tester.tap(_dansFeuille('Promoteurs'));
        await tester.pumpAndSettle();
        expect(_conteneur(tester).read(filtresEquipeProvider).nb, 2);
        await tester.tap(find.text('Réinitialiser'));
        await tester.pumpAndSettle();
        // La feuille reste ouverte, les filtres sont revenus à leur valeur par défaut.
        expect(find.byType(FiltresEquipeSheet), findsOneWidget);
        expect(_conteneur(tester).read(filtresEquipeProvider).nb, 0);
        await tester.tap(find.text('Appliquer'));
        await tester.pumpAndSettle();
        expect(find.text('3 chefs de secteur · 8 promoteurs'), findsOneWidget);
      },
    );

    testWidgets('le sélecteur ouvre aussi la feuille de filtres', (
      tester,
    ) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.dir);
      await tester.tap(find.byType(Selecteur).first);
      await tester.pumpAndSettle();
      expect(find.byType(FiltresEquipeSheet), findsOneWidget);
    });

    testWidgets('promoteur en retard et promoteur en visite', (tester) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.dir);
      _conteneur(tester)
          .read(filtresEquipeProvider.notifier)
          .maj((f) => f.copyWith(type: TypeEquipe.promoteurs));
      await tester.pumpAndSettle();
      // Inès G. (58 %) et Maëlle S. (66 %) sont sous le seuil de 70 %.
      expect(
        find.text("En retard sur l'objectif", skipOffstage: false),
        findsNWidgets(2),
      );
      expect(
        find.text('En visite · Auchan – Rouen', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('un appui sur un chef de secteur ouvre sa page', (
      tester,
    ) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.dir);
      // Le filtre des semaines d'un chef de secteur revient à « Toutes » à l'ouverture de sa page.
      _conteneur(
        tester,
      ).read(filtreSemainesProvider.notifier).choisir(FiltreSemaines.ecarts);
      await _toucher(tester, find.text('Karim B.'));
      expect(find.byType(ChefSecteurScreen), findsOneWidget);
      expect(
        find.text('Chef de secteur · Secteur Normandie / Hauts-de-France'),
        findsOneWidget,
      );
      expect(
        _conteneur(tester).read(filtreSemainesProvider),
        FiltreSemaines.toutes,
      );
    });

    testWidgets(
      'un appui sur un promoteur ouvre sa page (liste des promoteurs)',
      (tester) async {
        await pumpEcran(tester, const EquipeScreen(), role: Role.dir);
        _conteneur(tester)
            .read(filtresEquipeProvider.notifier)
            .maj((f) => f.copyWith(type: TypeEquipe.promoteurs));
        await tester.pumpAndSettle();
        await _toucher(tester, find.text('Camille D. · Karim B.'));
        expect(find.byType(PromoteurScreen), findsOneWidget);
        expect(find.text('Promoteur · 4 clients'), findsOneWidget);
      },
    );

    testWidgets('les filtres reviennent à zéro au changement de profil', (
      tester,
    ) async {
      await pumpEcran(tester, const EquipeScreen(), role: Role.dir);
      final c = _conteneur(tester);
      c
          .read(filtresEquipeProvider.notifier)
          .maj((f) => f.copyWith(region: 'Nord'));
      expect(c.read(filtresEquipeProvider).region, 'Nord');
      c.read(roleProvider.notifier).choisir(Role.cs);
      expect(c.read(filtresEquipeProvider).nb, 0);
    });
  });
}
