import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/features/equipe/promoteur_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Page d'un promoteur vue par son encadrement (maquette : `pagePromo` l.891-905, `activitePromo` l.880-887,
/// `pageTournee('mgr')` l.1031-1034).
ProviderContainer _conteneur(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PromoteurScreen)));

Future<void> _ouvrir(
  WidgetTester tester,
  String nom, {
  String csId = 'n',
  Role role = Role.cs,
}) => pumpEcran(
  tester,
  PromoteurScreen(csId: csId, nom: nom),
  role: role,
);

Future<void> _onglet(WidgetTester tester, String libelle) async {
  await tester.tap(find.text(libelle));
  await tester.pumpAndSettle();
}

Future<void> _choisirClient(WidgetTester tester, String client) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(client).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('entête, chiffres de la semaine et du mois, onglets', (
    tester,
  ) async {
    await _ouvrir(tester, 'Léa P.');
    expect(find.text('Léa P.'), findsOneWidget);
    expect(find.text('Promoteur · 4 clients'), findsOneWidget);
    expect(find.text('Visites semaine'), findsOneWidget);
    expect(find.text('6/9'), findsOneWidget);
    expect(find.text('Réalisé'), findsOneWidget);
    expect(find.text(eur(3100)), findsOneWidget);
    expect(find.text('Objectif'), findsOneWidget);
    expect(find.text(eur(4350)), findsOneWidget);
    expect(find.text('Planning'), findsOneWidget);
    expect(find.text('Visites (6)'), findsOneWidget);
    expect(find.text('Commandes (4)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le réalisé prend la couleur de l’atteinte de l’objectif', (
    tester,
  ) async {
    Color couleur(String texte) =>
        tester.widget<Text>(find.text(texte)).style!.color!;
    await _ouvrir(tester, 'Amine K.'); // 102 %
    expect(couleur(eur(5800)), AppColors.ok);
    await _ouvrir(tester, 'Léa P.'); // 71 %
    expect(couleur(eur(3100)), AppColors.warn);
    await _ouvrir(tester, 'Inès G.', csId: 'k'); // 58 %
    expect(couleur(eur(1700)), AppColors.alert);
  });

  group('onglet Planning', () {
    testWidgets('modifiable : consigne, semaine, jours, lignes et ajout', (
      tester,
    ) async {
      await _ouvrir(tester, 'Julien M.');
      expect(find.text('Vous pouvez modifier ce planning.'), findsOneWidget);
      expect(find.text('Semaine 45'), findsOneWidget);
      expect(find.text('2 – 6 nov.'), findsOneWidget);
      // Lundi 1, mardi 1, mercredi 2, jeudi 1, vendredi 1.
      expect(find.text('1 RDV'), findsNWidgets(4));
      expect(find.text('2 RDV'), findsOneWidget);
      // Mercredi : la tournée du jour de Julien M.
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsOneWidget);
      expect(find.text('Fait ✓'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
      // Le crayon n'est proposé que sur une ligne client ou prospect.
      expect(find.text('✎'), findsNWidgets(2));
      expect(find.text('＋ Ajouter une ligne'), findsOneWidget);
      // Pas de mention « Lecture seule. » sur le planning.
      expect(find.text('Lecture seule.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'chef de secteur : les clients hors de son secteur sont des lignes libres',
      (tester) async {
        // Les clients de Léa P. sont à Rouen : hors du secteur du chef de secteur.
        await _ouvrir(tester, 'Léa P.');
        expect(find.text('Carrefour – Rouen'), findsOneWidget);
        expect(find.text('Libre'), findsOneWidget);
        expect(find.text('Fait ✓'), findsOneWidget);
        expect(find.text('Client'), findsNothing);
        expect(find.text('✎'), findsNothing);
      },
    );

    testWidgets('directeur : les mêmes lignes sont des clients de sa région', (
      tester,
    ) async {
      await _ouvrir(tester, 'Léa P.', role: Role.dir);
      expect(find.text('Carrefour – Rouen'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Libre'), findsNothing);
      // Les deux lignes de la tournée (une faite, une à faire) sont des lignes client : deux crayons.
      expect(find.text('✎'), findsNWidgets(2));
    });

    testWidgets('changer de jour, de semaine', (tester) async {
      await _ouvrir(tester, 'Julien M.');
      await tester.tap(find.text('Lun'));
      await tester.pumpAndSettle();
      expect(_conteneur(tester).read(jourPlanningProvider), 0);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      await tester.tap(find.text('›'));
      await tester.pumpAndSettle();
      expect(find.text('Semaine 46'), findsOneWidget);
      expect(find.text('9 – 13 nov.'), findsOneWidget);
      expect(find.text('Aucune ligne ce jour.'), findsOneWidget);
      expect(find.text('＋ Ajouter une ligne'), findsOneWidget);
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      expect(find.text('Semaine 44'), findsOneWidget);
      expect(find.text('26 – 30 oct.'), findsOneWidget);
    });

    testWidgets('les lignes du store s’affichent, par semaine', (tester) async {
      await _ouvrir(tester, 'Julien M.');
      _conteneur(tester)
          .read(crmProvider.notifier)
          .ajouterEtape(
            const EtapePlanning(
              id: 'zz2',
              jour: 2,
              heure: '08:00',
              cible: CiblePlanning.libre,
              titre: 'Séminaire',
              rdv: true,
              appel: true,
              remp: true,
              note: 'À confirmer',
              sem: 1,
            ),
            pour: 'Julien M.',
          );
      await tester.pumpAndSettle();
      // La ligne est de la semaine suivante : rien cette semaine.
      expect(find.text('Séminaire'), findsNothing);
      expect(find.text('2 RDV'), findsOneWidget);
      await tester.tap(find.text('›'));
      await tester.pumpAndSettle();
      expect(find.text('Séminaire'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(
        find.text(
          'RDV · Appel téléphonique · Visite de remplacement · À confirmer',
        ),
        findsOneWidget,
      );
      expect(find.text('1 RDV'), findsOneWidget);
      // Une ligne libre n'a pas de crayon.
      expect(find.text('✎'), findsNothing);
    });

    testWidgets(
      '« Ajouter une ligne », un appui sur une ligne et le crayon ouvrent la feuille de saisie',
      (tester) async {
        await _ouvrir(tester, 'Julien M.');
        Future<void> fermer() async {
          await tester.tapAt(
            const Offset(195, 20),
          ); // le voile ferme la feuille
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
        }

        await tester.tap(find.text('＋ Ajouter une ligne'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        await fermer();
        await tester.tap(find.text('Carrefour Market – Versailles'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        await fermer();
        await tester.tap(find.text('✎').last);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        await fermer();
        // Une ligne qui n'est ni client ni prospect s'ouvre aussi, mais sans crayon.
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('onglets Visites et Commandes (lecture seule)', () {
    testWidgets('six visites, choix du client', (tester) async {
      await _ouvrir(tester, 'Julien M.');
      await _onglet(tester, 'Visites (6)');
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Tous les clients (4)'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsNWidgets(2));
      expect(find.text('4 nov. 09:00'), findsOneWidget);
      expect(find.text('29 oct. 14:30'), findsOneWidget);
      expect(find.text('Envoyée'), findsNWidgets(6));
      expect(find.text('Lecture seule.'), findsOneWidget);
      expect(find.text('Vous pouvez modifier ce planning.'), findsNothing);
      expect(find.text('＋ Ajouter une ligne'), findsNothing);

      await _choisirClient(tester, 'Carrefour – Ivry-sur-Seine');
      // Deux visites de Julien M. chez ce client ; le compteur de l'onglet reste celui du total.
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsNWidgets(3));
      expect(find.text('3 nov. 10:30'), findsOneWidget);
      expect(find.text('29 oct. 14:30'), findsOneWidget);
      expect(find.text('4 nov. 09:00'), findsNothing);
      expect(find.text('Visites (6)'), findsOneWidget);
    });

    testWidgets('trois commandes de Julien M., choix du client', (
      tester,
    ) async {
      await _ouvrir(tester, 'Julien M.');
      await _onglet(tester, 'Commandes (3)');
      expect(find.text('Tous les clients (4)'), findsOneWidget);
      expect(find.text('1 540,00 € HT'), findsOneWidget);
      expect(
        find.text('CDE-2041 · Carrefour – Ivry-sur-Seine · 3 nov.'),
        findsOneWidget,
      );
      expect(find.text('1 980,00 € HT'), findsOneWidget);
      expect(find.text('958,70 € HT'), findsOneWidget);
      expect(find.text('Pas livrée'), findsNWidgets(2));
      expect(find.text('Livrée'), findsOneWidget);
      expect(find.text('Lecture seule.'), findsOneWidget);

      await _choisirClient(tester, 'E.Leclerc – Paris');
      expect(find.text('958,70 € HT'), findsOneWidget);
      expect(find.text('1 540,00 € HT'), findsNothing);
    });

    testWidgets('changer d’onglet remet « Tous les clients »', (tester) async {
      await _ouvrir(tester, 'Julien M.');
      await _onglet(tester, 'Visites (6)');
      await _choisirClient(tester, 'E.Leclerc – Paris');
      await _onglet(tester, 'Commandes (3)');
      expect(find.text('Tous les clients (4)'), findsOneWidget);
      expect(find.text('1 540,00 € HT'), findsOneWidget);
    });

    testWidgets('la visite en cours d’Amine K. et les clients par défaut', (
      tester,
    ) async {
      await _ouvrir(tester, 'Amine K.');
      await _onglet(tester, 'Visites (6)');
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Envoyée'), findsNWidgets(5));
      await _ouvrir(tester, 'Camille D.', csId: 'k');
      await _onglet(tester, 'Visites (6)');
      expect(find.text('Auchan – Avignon'), findsNWidgets(2));
      expect(find.text('Tous les clients (3)'), findsOneWidget);
    });
  });
}
