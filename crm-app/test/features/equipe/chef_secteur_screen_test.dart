import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/equipe/chef_secteur_screen.dart';
import 'package:crm_app/features/equipe/promoteur_screen.dart';
import 'package:crm_app/features/equipe/semaine_cs_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Page d'un chef de secteur vue par le directeur (maquette : `pageCS` l.851-877, `pageTournee('lect')` l.1031-1034).
ProviderContainer _conteneur(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ChefSecteurScreen)));

Future<void> _ouvrir(WidgetTester tester, String csId) =>
    pumpEcran(tester, ChefSecteurScreen(csId: csId), role: Role.dir);

Future<void> _onglet(WidgetTester tester, String libelle) async {
  await tester.tap(find.text(libelle));
  await tester.pumpAndSettle();
}

Future<void> _toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('entête, actions et onglets', (tester) async {
    await _ouvrir(tester, 'n');
    expect(find.text('Nadia H.'), findsOneWidget);
    expect(
      find.text('Chef de secteur · Secteur Île-de-France'),
      findsOneWidget,
    );
    expect(find.text('Appeler'), findsOneWidget);
    expect(find.text('Envoyer un mail'), findsOneWidget);
    for (final onglet in ['Planning', 'Visites', 'Commandes', 'Promoteurs']) {
      expect(find.text(onglet), findsOneWidget, reason: onglet);
    }
    expect(find.byType(BoutonRetour), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chaque chef de secteur a son secteur dans l’entête', (
    tester,
  ) async {
    await _ouvrir(tester, 'k');
    expect(
      find.text('Chef de secteur · Secteur Normandie / Hauts-de-France'),
      findsOneWidget,
    );
    await _ouvrir(tester, 's');
    expect(find.text('Chef de secteur · Secteur Sud-Est'), findsOneWidget);
  });

  group('actions Appeler et Envoyer un mail', () {
    testWidgets('toast d’appel', (tester) async {
      await _ouvrir(tester, 'n');
      await tester.tap(find.text('Appeler'));
      await tester.pump();
      expect(find.text('Appel de Nadia H. en cours.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Appel de Nadia H. en cours.'), findsNothing);
    });

    testWidgets('toast de messagerie', (tester) async {
      await _ouvrir(tester, 'k');
      await tester.tap(find.text('Envoyer un mail'));
      await tester.pump();
      // Le point final du nom court est suivi de celui de la phrase, comme dans la maquette.
      expect(
        find.text('Ouverture de la messagerie : nouveau mail à Karim B..'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('onglet Planning (lecture seule)', () {
    testWidgets('semaine, jours et lignes du jour', (tester) async {
      await _ouvrir(tester, 'n');
      expect(find.text('Semaine 45'), findsOneWidget);
      expect(find.text('2 – 6 nov.'), findsOneWidget);
      for (final j in ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven']) {
        expect(find.text(j), findsOneWidget, reason: j);
      }
      for (final d in ['2', '3', '4', '5', '6']) {
        expect(find.text(d), findsOneWidget, reason: d);
      }
      // Planning de la semaine du profil (le directeur voit toutes ses lignes).
      expect(find.text('2 RDV'), findsNWidgets(2));
      expect(find.text('3 RDV'), findsOneWidget);
      expect(find.text('1 RDV'), findsOneWidget);
      expect(find.text('0 RDV'), findsOneWidget);
      // Mercredi : trois lignes.
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('Carrefour – Rouen'), findsOneWidget);
      expect(find.text('Client'), findsOneWidget);
      expect(find.text('11:30'), findsOneWidget);
      expect(find.text('Prospect'), findsOneWidget);
      expect(find.text('RDV'), findsOneWidget);
      expect(find.text('16:00'), findsOneWidget);
      expect(find.text('ADM'), findsOneWidget);
      expect(find.text('Compte rendu'), findsOneWidget);
      // Lecture seule : ni crayon ni bouton d'ajout.
      expect(find.text('＋ Ajouter une ligne'), findsNothing);
      expect(find.text('✎'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changer de jour change celui de toute l’application', (
      tester,
    ) async {
      await _ouvrir(tester, 'n');
      await tester.tap(find.text('Jeu'));
      await tester.pumpAndSettle();
      expect(_conteneur(tester).read(jourPlanningProvider), 3);
      expect(find.text('Super U – Versailles'), findsOneWidget);
      expect(find.text('Négo'), findsOneWidget);
      expect(
        find.text(
          'Accompagnement · RDV · Soirée étape (Versailles) · Négociation',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Ven'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune ligne ce jour.'), findsOneWidget);
      await tester.tap(find.text('Lun'));
      await tester.pumpAndSettle();
      expect(find.text('Fait ✓'), findsNWidgets(2));
    });

    testWidgets('carte du rapport d’activité de la semaine affichée', (
      tester,
    ) async {
      await _ouvrir(tester, 'n');
      expect(find.text("Rapport d'activité"), findsOneWidget);
      expect(find.text('Semaine 45 · en cours'), findsOneWidget);
      expect(find.text('2 – 6 novembre'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('60 % du prévu'), findsOneWidget);
      expect(find.text('+1 ajoutée · 1 retirée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigation entre les semaines', (tester) async {
      await _ouvrir(tester, 'n');
      // Semaine suivante : ni ligne, ni rapport.
      await tester.tap(find.text('›'));
      await tester.pumpAndSettle();
      expect(find.text('Semaine 46'), findsOneWidget);
      expect(find.text('9 – 13 nov.'), findsOneWidget);
      expect(find.text('Aucune ligne ce jour.'), findsOneWidget);
      expect(find.text("Rapport d'activité"), findsNothing);
      expect(find.text('0 RDV'), findsNWidgets(5));
      // Retour sur la semaine 45 puis semaine 44 : le rapport validé.
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      expect(find.text('Semaine 44'), findsNWidgets(2)); // en-tête + carte
      expect(find.text('26 – 30 oct.'), findsOneWidget);
      expect(find.text('Validé auto'), findsOneWidget);
      expect(find.text('83 % du prévu'), findsOneWidget);
      expect(find.text('+1 ajoutée · 1 retirée · 1 déplacée'), findsOneWidget);
      expect(find.text('Aucune ligne ce jour.'), findsOneWidget);
      // Semaine à cheval sur deux mois.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('‹'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Semaine 40'), findsNWidgets(2));
      expect(find.text('28 sept. – 2 oct.'), findsOneWidget);
      expect(find.text('+1 ajoutée'), findsOneWidget);
      // Avant la semaine 39 il n'y a plus de rapport.
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      expect(find.text('Semaine 38'), findsOneWidget);
      expect(find.text("Rapport d'activité"), findsNothing);
    });

    testWidgets('semaine sans prévision : message sur la carte', (
      tester,
    ) async {
      await _ouvrir(tester, 's');
      expect(find.text('Semaine 45 · en cours'), findsOneWidget);
      expect(
        find.text('Prévision non renseignée : pas de comparaison'),
        findsOneWidget,
      );
      expect(find.textContaining('du prévu'), findsNothing);
    });

    testWidgets('la carte ouvre la semaine du rapport', (tester) async {
      await _ouvrir(tester, 'n');
      await _toucher(tester, find.text('Semaine 45 · en cours'));
      expect(find.byType(SemaineCsScreen), findsOneWidget);
      expect(find.text('Nadia H. · 2 – 6 novembre'), findsOneWidget);
      await tester.tap(find.byType(BoutonRetour).last);
      await tester.pumpAndSettle();
      expect(find.byType(SemaineCsScreen), findsNothing);
      expect(find.byType(ChefSecteurScreen), findsOneWidget);
    });

    testWidgets('le planning d’un autre chef de secteur vient du store', (
      tester,
    ) async {
      await _ouvrir(tester, 'k');
      // Planning de Karim B. composé par le directeur : lundi 09:00 puis mardi 10:00, mercredi, jeudi, vendredi.
      expect(find.text('1 RDV'), findsWidgets);
      final c = _conteneur(tester);
      c
          .read(crmProvider.notifier)
          .ajouterEtape(
            const EtapePlanning(
              id: 'zz1',
              jour: 2,
              heure: '08:15',
              cible: CiblePlanning.libre,
              titre: 'Chez Marcel',
              note: 'Café',
            ),
            pour: 'Karim B.',
          );
      await tester.pumpAndSettle();
      expect(find.text('Chez Marcel'), findsOneWidget);
      expect(find.text('Libre'), findsOneWidget);
      expect(find.text('Café'), findsOneWidget);
      expect(find.text('08:15'), findsOneWidget);
      // Le planning de Nadia H. n'est pas touché.
      final nadia = c.read(crmProvider).planDe('Nadia H.');
      expect(nadia.any((e) => e.id == 'zz1'), isFalse);
    });
  });

  group('onglet Visites', () {
    testWidgets('six visites de Nadia H.', (tester) async {
      await _ouvrir(tester, 'n');
      await _onglet(tester, 'Visites');
      expect(find.text('Visites de Nadia H.'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Carrefour – Rouen'), findsNWidgets(2));
      expect(find.text('4 nov. 09:00'), findsOneWidget);
      expect(find.text('29 oct. 14:30'), findsOneWidget);
      expect(find.text('Envoyée'), findsNWidgets(6));
      expect(find.text('Lecture seule.'), findsNothing);
      // L'onglet Planning n'est plus affiché.
      expect(find.text('Semaine 45'), findsNothing);
    });

    testWidgets('clients propres à chaque chef de secteur', (tester) async {
      await _ouvrir(tester, 'k');
      await _onglet(tester, 'Visites');
      expect(find.text('Visites de Karim B.'), findsOneWidget);
      expect(find.text('Auchan – Avignon'), findsNWidgets(2));
      expect(find.text('Carrefour Market – Marseille'), findsNWidgets(2));
      expect(find.text('Intermarché – Lyon'), findsNWidgets(2));
    });
  });

  group('onglet Commandes', () {
    testWidgets('trois commandes de Nadia H.', (tester) async {
      await _ouvrir(tester, 'n');
      await _onglet(tester, 'Commandes');
      expect(find.text('Commandes de Nadia H.'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1 540,00 € HT'), findsOneWidget);
      expect(
        find.text('CDE-2041 · Super U – Versailles · 3 nov.'),
        findsOneWidget,
      );
      expect(find.text('1 980,00 € HT'), findsOneWidget);
      expect(
        find.text('CDE-2039 · Carrefour – Paris · 3 nov.'),
        findsOneWidget,
      );
      expect(find.text('958,70 € HT'), findsOneWidget);
      expect(find.text('CDE-2027 · Auchan – Rouen · 2 nov.'), findsOneWidget);
      expect(find.text('Pas livrée'), findsNWidgets(2));
      expect(find.text('Livrée'), findsOneWidget);
    });
  });

  group('onglet Promoteurs', () {
    testWidgets('résumé de l’équipe de Nadia H.', (tester) async {
      await _ouvrir(tester, 'n');
      await _onglet(tester, 'Promoteurs');
      expect(find.text("Résumé de l'équipe"), findsOneWidget);
      expect(find.text('3 promoteurs · Île-de-France'), findsOneWidget);
      for (final nom in ['Julien M.', 'Léa P.', 'Amine K.']) {
        expect(find.text(nom), findsOneWidget, reason: nom);
      }
      expect(find.text("Aujourd'hui : 1/2 visites faites"), findsNWidgets(3));
      expect(find.text('En visite · Auchan – Rouen'), findsOneWidget);
      expect(
        find.text(
          'Touchez un promoteur pour voir sa tournée du jour (lecture seule).',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('l’équipe de Sophie L. : deux promoteurs, un en retard', (
      tester,
    ) async {
      await _ouvrir(tester, 's');
      await _onglet(tester, 'Promoteurs');
      expect(find.text('2 promoteurs · Sud-Est'), findsOneWidget);
      expect(find.text('Hugo T.'), findsOneWidget);
      expect(find.text('Maëlle S.'), findsOneWidget);
      expect(
        find.text("En retard sur l'objectif"),
        findsOneWidget,
      ); // Maëlle S. : 66 %
    });

    testWidgets('un appui sur un promoteur ouvre sa page', (tester) async {
      await _ouvrir(tester, 'k');
      await _onglet(tester, 'Promoteurs');
      await _toucher(tester, find.text('Inès G.'));
      expect(find.byType(PromoteurScreen), findsOneWidget);
      expect(find.text('Promoteur · 3 clients'), findsOneWidget);
    });
  });
}
