import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/accueil/accueil_screen.dart';
import 'package:crm_app/features/accueil/accueil_state.dart';
import 'package:crm_app/features/commandes/prise_commande_screen.dart';
import 'package:crm_app/features/visites/visite_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_accueil.dart';

/// Accueil du promoteur « Julien M. » : maquette `salesAccueil` l.1138-1156, `blocLivraisons` l.1124-1128,
/// actions `v-ouvrir`, `v-ouvrir-id`, `cmd-nouvelle`, `liv-toggle`, `songlet` (l.1489-1521, l.1654-1666).
///
/// Données de la maquette pour Julien : clients m1, m4, m5, m8 ; tournée m4 09:30, m1 11:00, m8 12:30 ;
/// une visite faite aujourd'hui (m4, « 4 nov. 09:30 ») ; CA 4 200 € sur 4 900 € ;
/// commandes pas livrées CDE-2039 (m8) et CDE-2027 (m1).
void main() {
  Future<void> monter(WidgetTester tester) =>
      pumpEcran(tester, const AccueilScreen(), role: Role.promoteur);

  group('entête', () {
    testWidgets('Bonjour Julien, rôle et date du jour', (tester) async {
      await monter(tester);
      expect(find.text('Bonjour Julien'), findsOneWidget);
      expect(find.text('Promoteur · mer. 4 nov.'), findsOneWidget);
      expect(find.text('JM'), findsOneWidget);
      // Pas d'étoile de niveau pour le promoteur.
      expect(find.text('★'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tuile Visites : faites aujourd’hui sur la tournée', (
      tester,
    ) async {
      await monter(tester);
      expect(find.text('Visites'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('tuile CA / objectif du mois : 4 200 € sur 4 900 €', (
      tester,
    ) async {
      await monter(tester);
      expect(find.text('CA / objectif du mois'), findsOneWidget);
      expect(find.text('4 200 € / 4 900 €'), findsOneWidget);
      final barre = tester.widget<BarreObjectif>(find.byType(BarreObjectif));
      expect([barre.real, barre.cible], [4200, 4900]);
    });

    testWidgets('pas de tuile Prospects ni de bloc prospects', (tester) async {
      await monter(tester);
      expect(find.text('Prospects'), findsNothing);
      expect(find.text('Prospects à suivre'), findsNothing);
      expect(find.text('RDV du jour'), findsNothing);
    });
  });

  group('tournée du jour', () {
    testWidgets('trois visites avec heure, type et état', (tester) async {
      await monter(tester);
      expect(find.text('Ma tournée du jour'), findsOneWidget);
      // Pas de lien « Voir mon planning » côté promoteur.
      expect(find.text('Voir mon planning'), findsNothing);

      // la tournée et la rubrique « Visites PEM » (visite obligatoire chez ce client)
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsNWidgets(2));
      expect(find.text('09:30 · Planifiée'), findsOneWidget);
      expect(find.text('Réalisée'), findsOneWidget);
      expect(find.text('✅'), findsOneWidget);

      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(find.text('11:00 · Planifiée'), findsOneWidget);

      expect(find.text('U Express – Boulogne-Billancourt'), findsOneWidget);
      expect(find.text('12:30 · Passage opportunité'), findsOneWidget);

      expect(find.text('À faire'), findsNWidgets(2));
      expect(find.text('🕒'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('seule la première visite à faire propose « Démarrer »', (
      tester,
    ) async {
      await monter(tester);
      expect(find.text('Démarrer la visite'), findsOneWidget);
      expect(find.text('Reprendre la visite'), findsNothing);
      // Le bouton est dans la carte de Carrefour Market – Versailles (11:00).
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Démarrer la visite'),
            matching: find.byType(AppCarte),
          ),
          matching: find.text('Carrefour Market – Versailles'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('aucune étape : la tuile affiche 0 / 0 et rien sous le titre', (
      tester,
    ) async {
      await monter(tester);
      storeMonte(tester).mutate((e) => e.copyWith(tournee: const []));
      await tester.pumpAndSettle();
      expect(find.text('0 / 0'), findsOneWidget);
      expect(find.text('Ma tournée du jour'), findsOneWidget);
      expect(find.text('Démarrer la visite'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('une visite terminée aujourd’hui compte et passe au suivant', (
      tester,
    ) async {
      await monter(tester);
      storeMonte(tester).mutate(
        (e) => e.copyWith(
          visites: [
            visiteDemo(
              id: 'vx',
              num: 1,
              magasinId: 'm1',
              par: 'Julien M.',
              jour: 4,
              mois: 'nov',
              heure: 15,
              minute: 0,
            ),
            ...e.visites,
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Réalisée'), findsNWidgets(2));
      // Le bouton passe à la visite suivante (m8).
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Démarrer la visite'),
            matching: find.byType(AppCarte),
          ),
          matching: find.text('U Express – Boulogne-Billancourt'),
        ),
        findsOneWidget,
      );
    });
  });

  group('démarrer une visite', () {
    testWidgets('« Démarrer la visite » crée un brouillon et ouvre la visite', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      expect(storeMonte(tester).state.visites, hasLength(1));
      await toucher(tester, find.text('Démarrer la visite'));

      final visites = conteneurMonte(tester).read(crmProvider).visites;
      expect(visites, hasLength(2));
      expect(visites.first.magasinId, 'm1');
      expect(visites.first.etat, EtatVisite.brouillon);
      expect(visites.first.par, 'Julien M.');
      expect(find.byType(VisiteScreen), findsOneWidget);
      expect(
        tester.widget<VisiteScreen>(find.byType(VisiteScreen)).visiteId,
        visites.first.id,
      );
    });

    testWidgets('au retour : visite « En cours », « Reprendre » et brouillon', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await toucher(tester, find.text('Démarrer la visite'));
      AppRoutes.retourRacine(
        tester.element(find.byType(AccueilScreen, skipOffstage: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reprendre la visite'), findsOneWidget);
      expect(find.text('Démarrer la visite'), findsNothing);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('▶'), findsOneWidget);
      // Un brouillon n'est pas une visite faite : la tuile reste à 1 / 3.
      expect(find.text('1 / 3'), findsOneWidget);
      // Section « Brouillons ».
      expect(find.text('Brouillons'), findsOneWidget);
      expect(
        find.text('Visite en cours · brouillon sur ce téléphone'),
        findsOneWidget,
      );
    });

    testWidgets('un appui sur la ligne d’une visite la démarre aussi', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await toucher(tester, find.text('U Express – Boulogne-Billancourt'));
      final visites = conteneurMonte(tester).read(crmProvider).visites;
      expect(visites.first.magasinId, 'm8');
      expect(visites.first.etat, EtatVisite.brouillon);
      expect(find.byType(VisiteScreen), findsOneWidget);
    });

    testWidgets('un appui sur un brouillon rouvre cette visite', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      final id = storeMonte(tester).demarrerVisite('m1');
      await tester.pumpAndSettle();
      expect(find.text('Brouillons'), findsOneWidget);
      await toucher(
        tester,
        find.text('Visite en cours · brouillon sur ce téléphone'),
      );
      expect(find.byType(VisiteScreen), findsOneWidget);
      expect(
        tester.widget<VisiteScreen>(find.byType(VisiteScreen)).visiteId,
        id,
      );
      // Un seul brouillon : l'appui n'en crée pas d'autre.
      expect(
        conteneurMonte(tester)
            .read(crmProvider)
            .visites
            .where((v) => v.etat == EtatVisite.brouillon),
        hasLength(1),
      );
    });

    testWidgets('sans brouillon, pas de section « Brouillons »', (
      tester,
    ) async {
      await monter(tester);
      expect(find.text('Brouillons'), findsNothing);
    });
  });

  group('nouvelle commande', () {
    testWidgets('le bouton ouvre la prise de commande sans client', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      expect(find.text('＋ Nouvelle commande'), findsOneWidget);
      await toucher(tester, find.text('＋ Nouvelle commande'));
      expect(routeCourante(tester), 'cmd');
      final ecran = tester.widget<PriseCommandeScreen>(
        find.byType(PriseCommandeScreen),
      );
      expect(ecran.magasinId, isNull);
      expect(ecran.visiteId, isNull);
    });
  });

  group('suivi des livraisons', () {
    testWidgets('replié : lien souligné avec le nombre en cours', (
      tester,
    ) async {
      await monter(tester);
      expect(find.text('🚚 Suivi des livraisons · 2 en cours'), findsOneWidget);
      expect(find.text('▼'), findsOneWidget);
      expect(find.byType(CarteLivraison), findsNothing);
      expect(find.text("Voir l'historique des commandes ›"), findsNothing);
    });

    testWidgets('un appui déroule les commandes, un second les replie', (
      tester,
    ) async {
      await monter(tester);
      await toucher(tester, find.text('🚚 Suivi des livraisons · 2 en cours'));
      expect(find.text('▲'), findsOneWidget);
      expect(find.byType(CarteLivraison), findsNWidgets(2));
      expect(find.textContaining('CDE-2039'), findsOneWidget);
      expect(find.textContaining('CDE-2027'), findsOneWidget);
      expect(find.text('Pas livrée'), findsNWidgets(2));
      expect(find.text("Voir l'historique des commandes ›"), findsOneWidget);
      expect(conteneurMonte(tester).read(livraisonsOuvertesProvider), isTrue);

      await toucher(tester, find.text('▲'));
      expect(find.text('▼'), findsOneWidget);
      expect(find.byType(CarteLivraison), findsNothing);
      expect(conteneurMonte(tester).read(livraisonsOuvertesProvider), isFalse);
    });

    testWidgets('trois commandes au plus, les plus récentes d’abord', (
      tester,
    ) async {
      await monter(tester);
      Commande nouvelle(String id, String magasinId) => Commande(
        id: id,
        magasinId: magasinId,
        date: '4 nov.',
        ht: '100,00 €',
        lignes: 1,
        statut: StatutLivraison.pasLivree,
        eta: 'lun. 9 nov.',
        colis: 1,
        evenements: const [
          EvenementTransport('Commande reçue', '4 nov. 14:30'),
        ],
        src: 'Appli',
        par: 'Julien M.',
      );
      final store = storeMonte(tester);
      store.ajouterCommande(nouvelle('CDE-2042', 'm4'));
      store.ajouterCommande(nouvelle('CDE-2043', 'm1'));
      await tester.pumpAndSettle();
      expect(find.text('🚚 Suivi des livraisons · 4 en cours'), findsOneWidget);
      await toucher(tester, find.text('▼'));
      expect(find.byType(CarteLivraison), findsNWidgets(3));
      expect(find.textContaining('CDE-2043'), findsOneWidget);
      expect(find.textContaining('CDE-2042'), findsOneWidget);
      expect(find.textContaining('CDE-2039'), findsOneWidget);
      expect(find.textContaining('CDE-2027'), findsNothing);
    });

    testWidgets('aucune commande en cours : le bloc disparaît', (tester) async {
      await monter(tester);
      storeMonte(tester).mutate(
        (e) => e.copyWith(
          commandes: e.commandes
              .where((c) => c.statut == StatutLivraison.livree)
              .toList(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Suivi des livraisons'), findsNothing);
      expect(find.text('▼'), findsNothing);
    });

    testWidgets('un appui sur une carte ouvre le suivi du transport', (
      tester,
    ) async {
      await monter(tester);
      await toucher(tester, find.text('🚚 Suivi des livraisons · 2 en cours'));
      await toucher(tester, find.byType(CarteLivraison).first);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.textContaining('CDE-2039'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '« Voir l’historique des commandes » ouvre l’onglet Commandes',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        await toucher(
          tester,
          find.text('🚚 Suivi des livraisons · 2 en cours'),
        );
        await toucher(tester, find.text("Voir l'historique des commandes ›"));
        expect(
          conteneurMonte(tester).read(ongletProvider),
          OngletApp.commandes,
        );
      },
    );

    testWidgets('le bloc se replie au changement de profil', (tester) async {
      final c = conteneurPour(Role.promoteur);
      c.read(livraisonsOuvertesProvider.notifier).basculer();
      expect(c.read(livraisonsOuvertesProvider), isTrue);
      c.read(roleProvider.notifier).choisir(Role.cs);
      expect(c.read(livraisonsOuvertesProvider), isFalse);
    });
  });

  group('alertes de la cloche', () {
    testWidgets('la cloche affiche le nombre d’alertes du portefeuille', (
      tester,
    ) async {
      await monter(tester);
      // m1 (15 jours sans visite, classe A++), m8 (25 jours, classe B), m5 inactif.
      expect(
        find.descendant(of: find.byType(Cloche), matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('démarrer une visite chez m1 retire son alerte', (
      tester,
    ) async {
      await monter(tester);
      storeMonte(tester).demarrerVisite('m1');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(Cloche), matching: find.text('2')),
        findsOneWidget,
      );
    });
  });
}
