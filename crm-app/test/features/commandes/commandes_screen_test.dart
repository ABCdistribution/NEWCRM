import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/commandes/commandes_screen.dart';
import 'package:crm_app/features/commandes/state/attente_provider.dart';
import 'package:crm_app/features/commandes/state/filtres_commandes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'support_commandes.dart';

ProviderContainer _conteneur(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CommandesScreen)));

Future<void> _ouvrirFiltres(WidgetTester tester) async {
  await toucher(tester, find.byType(BoutonFiltre));
}

void main() {
  setUpAll(chargerInter);

  group('Commandes du promoteur (salesCommandes l.1204-1211)', () {
    testWidgets('entête, recherche, compteurs et cartes de livraison', (
      tester,
    ) async {
      await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
      expect(find.text('Commandes'), findsOneWidget);
      expect(find.text('Mes commandes · 5 résultats'), findsOneWidget);
      expect(find.text('Client, n° de commande…'), findsOneWidget);
      expect(find.text('Pas livrées'), findsOneWidget);
      expect(find.text('Livrées'), findsOneWidget);
      // 2 pas livrées (CDE-2039, CDE-2027) et 3 livrées (CDE-2018, CDE-1984, CDE-1930) sur ses 4 clients.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // Les commandes pas encore livrées d'abord, l'ordre d'origine sinon (tri stable de `ordreLiv`).
      expect(idsCartes(tester), [
        'CDE-2039',
        'CDE-2027',
        'CDE-2018',
        'CDE-1984',
        'CDE-1930',
      ]);
      // Aucun filtre actif : pas de pastille sur le bouton de filtres.
      expect(
        tester.widget<BoutonFiltre>(find.byType(BoutonFiltre)).nbFiltres,
        0,
      );
      // Pas de bouton « nouvelle commande » dans la maquette.
      expect(find.byType(AppFab), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'la carte d’une commande EDI affiche son étiquette et le suivi',
      (tester) async {
        await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
        expect(find.text('EDI'), findsNWidgets(4)); // 2039, 2027, 2018, 1930
        Finder pastille(String t) =>
            find.byWidgetPredicate((w) => w is Pastille && w.label == t);
        expect(pastille('Pas livrée'), findsNWidgets(2));
        expect(pastille('Livrée'), findsNWidgets(3));
        expect(
          find.text('🚚 Geodis · Livraison prévue jeu. 5 nov.'),
          findsOneWidget,
        );
        expect(find.text('🚚 Geodis · livrée le 22 oct.'), findsOneWidget);
        // Les commandes du promoteur ne portent pas de « par … ».
        expect(find.textContaining('par Julien'), findsNothing);
      },
    );

    testWidgets(
      'la commande en attente est proposée en tête avec ses actions',
      (tester) async {
        await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
        expect(find.text('Commandes en attente'), findsOneWidget);
        expect(find.text('1'), findsOneWidget); // compteur de la section
        expect(find.text('⏸ En attente'), findsOneWidget);
        // 22,62 × 12 + 16,28 × 24 = 662,16 €
        expect(
          find.text('2 références · 36 articles · 662,16 € HT'),
          findsOneWidget,
        );
        expect(
          find.text('Mise de côté le 3 nov. 17:40 · non envoyée'),
          findsOneWidget,
        );
        expect(
          find.text('⏳ Ne pas livrer avant le 16 nov. · Inventaire'),
          findsOneWidget,
        );
        expect(
          find.text('📝 En attente de la validation du chef de rayon'),
          findsOneWidget,
        );
        expect(find.text('Reprendre'), findsOneWidget);
        expect(find.text('Supprimer'), findsOneWidget);
      },
    );

    testWidgets('« Supprimer » retire la commande en attente et le dit', (
      tester,
    ) async {
      await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
      await tester.tap(find.text('Supprimer'));
      await tester.pump();
      expect(find.text('Commande en attente supprimée.'), findsOneWidget);
      expect(find.text('Commandes en attente'), findsNothing);
      expect(_conteneur(tester).read(attenteProvider), isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('« Reprendre » ouvre le panier de la commande mise de côté', (
      tester,
    ) async {
      await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
      await toucher(tester, find.text('Reprendre'));
      expect(find.text('Panier'), findsOneWidget);
      expect(find.text('U Express – Boulogne-Billancourt'), findsOneWidget);
      expect(find.text('Shampooing antipelliculaire'), findsOneWidget);
      expect(find.text('Rouge mat 101'), findsOneWidget);
      expect(find.text('662,16 €'), findsOneWidget);
      // La consigne de la commande en attente est reprise.
      expect(find.text('⏳ Ne pas livrer avant le 16 nov.'), findsOneWidget);
      expect(find.text('Motif : Inventaire'), findsOneWidget);
      // Dessous, la prise de commande avec son catalogue.
      await toucher(tester, find.text('＋ Ajouter des articles'));
      expect(find.text('Nouvelle commande'), findsOneWidget);
      expect(find.text('Nom, marque, réf. ou EAN'), findsOneWidget);
      expect(find.text('2 articles'), findsNothing);
      expect(find.text('36 articles'), findsOneWidget);
      expect(find.text('662,16 € HT'), findsOneWidget);
    });
  });

  group('Recherche', () {
    testWidgets(
      'par numéro de commande, par client, par auteur, sans résultat',
      (tester) async {
        await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
        final champ = find.byType(TextFormField);

        await tester.enterText(champ, 'CDE-2018');
        await tester.pump();
        expect(find.text('Mes commandes · 1 résultat'), findsOneWidget);
        expect(idsCartes(tester), ['CDE-2018']);
        // Les compteurs suivent la recherche (mais pas le filtre d'état).
        expect(find.text('0'), findsOneWidget);
        expect(find.text('1'), findsWidgets);

        await tester.enterText(champ, 'versailles');
        await tester.pump();
        expect(idsCartes(tester), ['CDE-2027', 'CDE-1984', 'CDE-1930']);

        await tester.enterText(champ, 'julien');
        await tester.pump();
        expect(idsCartes(tester), hasLength(5));

        await tester.enterText(champ, 'introuvable');
        await tester.pump();
        expect(find.text('Mes commandes · 0 résultat'), findsOneWidget);
        expect(find.text('Aucune commande pour ces filtres.'), findsOneWidget);
        expect(idsCartes(tester), isEmpty);
      },
    );
  });

  group('Feuille de filtres', () {
    testWidgets('texte et options de la feuille du promoteur', (tester) async {
      await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
      await _ouvrirFiltres(tester);
      for (final t in [
        'Filtres',
        'AFFICHER',
        'Mes commandes',
        'Toutes les commandes',
        'TYPE DE COMMANDE',
        'Commandes EDI',
        "Commandes saisies dans l'appli",
        'ÉTAT',
        'Tous les états',
        'Pas livrée',
        'PÉRIODE',
        'Toutes les dates',
        "Aujourd'hui",
        '7 derniers jours',
        'Réinitialiser',
        'Voir 5 commandes',
      ]) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(
        find.text('Toutes les commandes (sur vos clients)'),
        findsOneWidget,
      );
    });

    testWidgets('chaque choix filtre la liste, compte et se réinitialise', (
      tester,
    ) async {
      await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
      await _ouvrirFiltres(tester);

      await toucher(tester, dansFeuille(find.text('Pas livrée')));
      expect(find.text('Voir 2 commandes'), findsOneWidget);
      expect(idsCartes(tester), ['CDE-2039', 'CDE-2027']);

      await toucher(tester, dansFeuille(find.text('Commandes EDI')));
      expect(find.text('Voir 2 commandes'), findsOneWidget);

      await tester.tap(
        dansFeuille(find.text("Commandes saisies dans l'appli")),
      );
      await tester.pumpAndSettle();
      // Aucune commande « Pas livrée » saisie dans l'appli : « Voir 0 commande » au singulier.
      expect(find.text('Voir 0 commande'), findsOneWidget);

      await toucher(tester, dansFeuille(find.text('Tous les états')));
      expect(find.text('Voir 1 commande'), findsOneWidget); // CDE-1984
      expect(idsCartes(tester), ['CDE-1984']);

      await toucher(tester, dansFeuille(find.text("Aujourd'hui")));
      expect(find.text('Voir 0 commande'), findsOneWidget);

      await toucher(tester, find.text('Réinitialiser'));
      expect(find.text('Voir 5 commandes'), findsOneWidget);

      await toucher(tester, dansFeuille(find.text('7 derniers jours')));
      // 2 nov. (2039) : 2 jours ; 26 oct. (2027) : 9 jours ; 19 oct. et plus : trop anciennes.
      expect(find.text('Voir 1 commande'), findsOneWidget);
      expect(idsCartes(tester), ['CDE-2039']);

      await toucher(tester, find.text('Voir 1 commande'));
      expect(find.text('Filtres'), findsNothing);
      expect(find.text('Mes commandes · 1 résultat'), findsOneWidget);
      expect(
        tester.widget<BoutonFiltre>(find.byType(BoutonFiltre)).nbFiltres,
        1,
      );
    });

    testWidgets(
      'la pastille compte les filtres écartés des valeurs par défaut',
      (tester) async {
        await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
        await _ouvrirFiltres(tester);
        await toucher(tester, dansFeuille(find.text('Livrée')));
        await toucher(tester, dansFeuille(find.text('Commandes EDI')));
        await toucher(
          tester,
          texteRiche('Toutes les commandes (sur vos clients)'),
        );
        final f = _conteneur(tester).read(filtresCommandesProvider);
        expect(f.nbActifs(Role.promoteur), 3);
        expect(
          f.nbActifs(Role.cs),
          2,
        ); // « toutes » est la valeur par défaut de l'encadrement
        await toucher(tester, find.textContaining('Voir '));
        expect(find.text('3'), findsWidgets);
        expect(
          find.text('Toutes les commandes sur vos clients · 2 résultats'),
          findsOneWidget,
        );
      },
    );
  });

  group('Encadrement', () {
    testWidgets('le chef de secteur voit toutes les commandes de son secteur', (
      tester,
    ) async {
      await pumpEcran(tester, const CommandesScreen(), role: Role.cs);
      expect(
        find.text('Toutes les commandes de votre secteur · 6 résultats'),
        findsOneWidget,
      );
      expect(idsCartes(tester), [
        'CDE-2041',
        'CDE-2039',
        'CDE-2027',
        'CDE-2018',
        'CDE-1984',
        'CDE-1930',
      ]);
      // La commande d'un autre promoteur porte son auteur.
      expect(find.textContaining('par Amine K.'), findsOneWidget);
      expect(find.textContaining('par Julien M.'), findsNWidgets(5));
      expect(find.text('Commandes en attente'), findsOneWidget);
      await _ouvrirFiltres(tester);
      expect(
        find.text('Toutes les commandes (de votre secteur)'),
        findsOneWidget,
      );
    });

    testWidgets('le directeur voit toute sa région', (tester) async {
      await pumpEcran(tester, const CommandesScreen(), role: Role.dir);
      expect(
        find.text('Toutes les commandes de votre région · 10 résultats'),
        findsOneWidget,
      );
      expect(idsCartes(tester), hasLength(10));
      await _ouvrirFiltres(tester);
      expect(
        find.text('Toutes les commandes (de votre région)'),
        findsOneWidget,
      );
      await toucher(tester, dansFeuille(find.text('Mes commandes')));
      // Aucune commande du directeur : « Mes commandes » est vide.
      expect(find.text('Voir 0 commande'), findsOneWidget);
    });
  });

  testWidgets('un appui sur une carte ouvre le suivi du transport', (
    tester,
  ) async {
    await pumpEcran(tester, const CommandesScreen(), role: Role.promoteur);
    await tester.ensureVisible(find.byType(CarteLivraison).first);
    await toucher(tester, find.byType(CarteLivraison).first);
    expect(
      find.text('CDE-2039 · U Express – Boulogne-Billancourt'),
      findsOneWidget,
    );
    expect(find.text('SUIVI DU TRANSPORT'), findsOneWidget);
  });
}
