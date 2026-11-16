import 'dart:async';

import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/commandes/prise_commande_screen.dart';
import 'package:crm_app/features/commandes/state/attente_provider.dart';
import 'package:crm_app/features/commandes/state/commande_provider.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'support_commandes.dart';

BuildContext _ctx(WidgetTester tester) =>
    tester.element(find.byType(ShellScreen, skipOffstage: false));

ProviderContainer _conteneur(WidgetTester tester) =>
    ProviderScope.containerOf(_ctx(tester));

/// Route affichée au premier plan (la dernière de la pile).
ModalRoute<Object?> _routeCourante(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.byType(Scaffold).last))!;

Finder _ligne(String produitId) => find.byWidgetPredicate(
  (w) => w is LigneProduit && w.produit.id == produitId,
);

/// Lance l'appli, ouvre la prise de commande chez `magasinId` et ajoute un colisage de chaque produit demandé.
Future<void> _preparer(
  WidgetTester tester, {
  Role role = Role.promoteur,
  String magasinId = 'm1',
  String? visiteId,
  List<String> produits = const ['a1'],
}) async {
  await lancerApp(tester, role);
  unawaited(
    AppRoutes.priseCommande(
      _ctx(tester),
      magasinId: magasinId,
      visiteId: visiteId,
    ),
  );
  await tester.pumpAndSettle();
  for (final id in produits) {
    await tester.ensureVisible(_ligne(id));
    await tester.pump();
    await tester.tap(
      find.descendant(of: _ligne(id), matching: find.text('＋ Ajouter')),
    );
    await tester.pump();
  }
}

Future<void> _versPanier(WidgetTester tester) async {
  await tester.tap(find.text('Voir le panier ›'));
  await tester.pumpAndSettle();
}

/// Choisit une date dans le sélecteur de date de la feuille « Ne pas livrer avant… ».
Future<void> _choisirDate(WidgetTester tester, String jour) async {
  await tester.tap(find.text('jj/mm/aaaa'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(jour));
  await tester.pump();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(chargerInter);

  group('Contenu du panier (cmdPanier l.1624-1642)', () {
    testWidgets('lignes, total, livraison estimée, remarque et actions', (
      tester,
    ) async {
      await _preparer(tester);
      await _versPanier(tester);
      expect(find.text('Panier'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(find.text('＋ Ajouter des articles'), findsOneWidget);
      expect(find.text('Shampooing doux usage fréquent'), findsOneWidget);
      expect(find.text('3,46 € × 6 = 20,76 €'), findsOneWidget);
      expect(find.text('● En stock · 98 disponibles'), findsOneWidget);
      expect(find.text('1 référence · 6 articles'), findsOneWidget);
      expect(find.text('Total HT'), findsOneWidget);
      expect(find.text('20,76 €'), findsOneWidget);
      expect(find.text('🚚 Livraison estimée ven. 6 nov.'), findsOneWidget);
      expect(find.text('Ne pas livrer avant une date précise'), findsOneWidget);
      expect(find.text("Remarque pour l'ADV (facultatif)"), findsOneWidget);
      expect(find.text('Ex. prévenir le chef de rayon'), findsOneWidget);
      expect(find.text('⏸ Mettre en attente'), findsOneWidget);
      expect(find.text('✓ Valider'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('les compteurs du panier modifient la commande et le total', (
      tester,
    ) async {
      await _preparer(tester, produits: ['a1', 'a2']);
      await _versPanier(tester);
      expect(find.text('2 références · 12 articles'), findsOneWidget);
      // 20,76 + 22,62 × 6 = 156,48 €
      expect(find.text('156,48 €'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Plus').first);
      await tester.pump();
      expect(find.text('2 références · 13 articles'), findsOneWidget);
      expect(find.text('3,46 € × 7 = 24,22 €'), findsOneWidget);
      expect(find.text('159,94 €'), findsOneWidget);
      // Un produit à zéro quitte le panier.
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.bySemanticsLabel('Moins').first);
        await tester.pump();
      }
      expect(find.text('1 référence · 6 articles'), findsOneWidget);
      expect(find.text('Shampooing doux usage fréquent'), findsNothing);
    });

    testWidgets('« Ajouter des articles » revient au catalogue', (
      tester,
    ) async {
      await _preparer(tester);
      await _versPanier(tester);
      await tester.tap(find.text('＋ Ajouter des articles'));
      await tester.pumpAndSettle();
      expect(find.text('Panier'), findsNothing);
      expect(find.text('Nom, marque, réf. ou EAN'), findsOneWidget);
    });

    testWidgets('la remarque pour l’ADV est conservée', (tester) async {
      await _preparer(tester);
      await _versPanier(tester);
      await tester.enterText(
        find.byType(TextFormField),
        'Prévenir le chef de rayon',
      );
      await tester.pump();
      expect(
        _conteneur(tester).read(commandeEnCoursProvider)!.note,
        'Prévenir le chef de rayon',
      );
    });

    testWidgets('produit en stock insuffisant : alerte et lien de remplacement', (
      tester,
    ) async {
      await _preparer(tester, produits: ['a4']);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.bySemanticsLabel('Plus'));
        await tester.pump();
      }
      await _versPanier(tester);
      expect(find.text('● Stock bas · 8 disponibles'), findsOneWidget);
      expect(
        texteRiche('Stock insuffisant (8 disponibles). Remplacement ›'),
        findsOneWidget,
      );
      await tester.tap(find.text('✓ Valider'));
      await tester.pump();
      expect(
        find.text(
          'Stock insuffisant pour « Coloration blond 7.3 » : choisissez un remplacement ou baissez la quantité.',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      // Le remplacement s'ouvre depuis le lien, et le panier affiche ce que la ligne remplace.
      await tester.tapOnText(find.textRange.ofSubstring('Remplacement ›'));
      await tester.pumpAndSettle();
      expect(find.text('Produits de remplacement'), findsOneWidget);
      await tester.tap(find.text('Choisir').first);
      await tester.pumpAndSettle();
      expect(find.text('↺ Remplace Coloration blond 7.3'), findsOneWidget);
      expect(find.text('Coloration châtain 4.0'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Consigne « Ne pas livrer avant » (cmd-pas l.1359-1368)', () {
    testWidgets('la case ouvre la feuille ; « Annuler » abandonne la consigne', (
      tester,
    ) async {
      await _preparer(tester);
      await _versPanier(tester);
      await tester.tap(find.text('Ne pas livrer avant une date précise'));
      await tester.pumpAndSettle();
      expect(find.text('Ne pas livrer avant…'), findsOneWidget);
      expect(find.text('⚠ Important'), findsOneWidget);
      expect(
        find.text(
          "Cette consigne est transmise à l'ADV : indiquez pourquoi et à partir de quand le client peut être livré.",
        ),
        findsOneWidget,
      );
      expect(find.text('MOTIF'), findsOneWidget);
      expect(find.text('Impératif'), findsOneWidget);
      expect(find.text('Inventaire'), findsOneWidget);
      expect(find.text('Ne pas livrer avant le *'), findsOneWidget);
      expect(find.text('jj/mm/aaaa'), findsOneWidget);
      expect(_conteneur(tester).read(commandeEnCoursProvider)!.pas, isTrue);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Ne pas livrer avant…'), findsNothing);
      final cmd = _conteneur(tester).read(commandeEnCoursProvider)!;
      expect(cmd.pas, isFalse);
      expect(cmd.dateMin, isEmpty);
    });

    testWidgets(
      'l’appui sur le voile abandonne aussi une consigne incomplète',
      (tester) async {
        await _preparer(tester);
        await _versPanier(tester);
        await tester.tap(find.text('Ne pas livrer avant une date précise'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inventaire'));
        await tester.pump();
        await tester.tapAt(const Offset(195, 20)); // le voile
        await tester.pumpAndSettle();
        final cmd = _conteneur(tester).read(commandeEnCoursProvider)!;
        expect(cmd.pas, isFalse);
        expect(cmd.motifPas, isEmpty);
      },
    );

    testWidgets('« Valider » exige le motif puis la date', (tester) async {
      await _preparer(tester);
      await _versPanier(tester);
      await tester.tap(find.text('Ne pas livrer avant une date précise'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Valider'));
      await tester.pump();
      expect(
        find.text('Choisissez le motif de cette consigne.'),
        findsOneWidget,
      );
      expect(find.text('Ne pas livrer avant…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.text('Impératif'));
      await tester.pump();
      await tester.tap(find.text('Valider'));
      await tester.pump();
      expect(
        find.text('Indiquez la date avant laquelle ne pas livrer.'),
        findsOneWidget,
      );
      expect(find.text('Ne pas livrer avant…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('une consigne complète s’affiche dans le panier et se modifie', (
      tester,
    ) async {
      await _preparer(tester);
      await _versPanier(tester);
      await tester.tap(find.text('Ne pas livrer avant une date précise'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impératif'));
      await tester.pump();
      await _choisirDate(tester, '16');
      expect(find.text('16/11/2026'), findsOneWidget);
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(find.text('Ne pas livrer avant…'), findsNothing);
      expect(find.text('⏳ Ne pas livrer avant le 16 nov.'), findsOneWidget);
      expect(find.text('Motif : Impératif'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(
        find.text('🚚 Livraison estimée à partir du 16 nov.'),
        findsOneWidget,
      );

      // « Modifier » rouvre la feuille ; annuler une consigne complète la conserve.
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      expect(find.text('16/11/2026'), findsOneWidget);
      await tester.tap(find.text('Inventaire'));
      await tester.pump();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Motif : Inventaire'), findsOneWidget);
      expect(find.text('⏳ Ne pas livrer avant le 16 nov.'), findsOneWidget);

      // Décocher la case efface la consigne.
      await tester.tap(find.text('Ne pas livrer avant une date précise'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsNothing);
      final cmd = _conteneur(tester).read(commandeEnCoursProvider)!;
      expect(cmd.pas, isFalse);
      expect(cmd.dateMin, isEmpty);
      expect(cmd.motifPas, isEmpty);
      expect(find.text('🚚 Livraison estimée ven. 6 nov.'), findsOneWidget);
    });

    testWidgets('le sélecteur de date ne propose pas de jour passé', (
      tester,
    ) async {
      await _preparer(tester);
      await _versPanier(tester);
      await tester.tap(find.text('Ne pas livrer avant une date précise'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('jj/mm/aaaa'));
      await tester.pumpAndSettle();
      // Le 4 novembre 2026 est le premier jour proposé : le 3 est inactif.
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(picker.firstDate, DateTime(2026, 11, 4));
      expect(picker.initialDate, DateTime(2026, 11, 4));
      await tester.tap(find.text('Annuler').last);
      await tester.pumpAndSettle();
    });
  });

  group('Valider (cmd-valider l.1694-1706)', () {
    testWidgets('un panier vide ne peut être ni validé ni mis en attente', (
      tester,
    ) async {
      await _preparer(tester, produits: const []);
      await _versPanier(tester);
      expect(find.text('Le panier est vide.'), findsOneWidget);
      expect(find.text('0 référence · 0 articles'), findsOneWidget);
      expect(find.text('0,00 €'), findsOneWidget);
      await tester.tap(find.text('✓ Valider'));
      await tester.pump();
      expect(
        find.text('Le panier est vide : ajoutez au moins un produit.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('⏸ Mettre en attente'));
      await tester.pump();
      expect(
        find.text('Rien à mettre en attente : le panier est vide.'),
        findsOneWidget,
      );
      expect(find.text('Panier'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('la commande rejoint le suivi de livraison du promoteur', (
      tester,
    ) async {
      await _preparer(tester);
      await _versPanier(tester);
      await tester.tap(find.text('✓ Valider'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Commande CDE-2044 enregistrée. Envoi dès que le réseau le permet.',
        ),
        findsOneWidget,
      );
      // Le promoteur arrive sur l'onglet « Commandes », la pile est vidée.
      expect(find.text('Panier'), findsNothing);
      expect(find.text('Nouvelle commande'), findsNothing);
      expect(find.text('Mes commandes · 6 résultats'), findsOneWidget);
      expect(idsCartes(tester).first, 'CDE-2044');
      expect(_conteneur(tester).read(commandeEnCoursProvider), isNull);

      final c = _conteneur(tester).read(crmProvider).commandes.first;
      expect(c.id, 'CDE-2044');
      expect(c.src, 'Appli');
      expect(c.par, 'Julien M.');
      expect(c.magasinId, 'm1');
      expect(c.date, '4 nov.');
      expect(c.ht, '20,76 €');
      expect(c.lignes, 1);
      expect(c.statut, StatutLivraison.pasLivree);
      expect(c.eta, 'ven. 6 nov.');
      expect(c.colis, 1);
      expect(c.pasAvant, isNull);
      expect(c.transporteur, isNull);
      expect(c.evenements.single.libelle, 'Commande reçue');
      expect(c.evenements.single.detail, '4 nov. 14:23');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('avec une consigne : date, motif et message de livraison', (
      tester,
    ) async {
      await _preparer(tester, produits: ['a1', 'a2']);
      await _versPanier(tester);
      await tester.tap(find.text('Ne pas livrer avant une date précise'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventaire'));
      await tester.pump();
      await _choisirDate(tester, '16');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('✓ Valider'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Commande CDE-2044 enregistrée · livraison à partir du 16 nov.. Envoi dès que le réseau le permet.',
        ),
        findsOneWidget,
      );
      final c = _conteneur(tester).read(crmProvider).commandes.first;
      expect(c.pasAvant, '2026-11-16');
      expect(c.motifPas, 'Inventaire');
      expect(c.eta, 'à partir du 16 nov.');
      expect(c.lignes, 2);
      expect(c.colis, 1); // 12 articles : un colis
      // La carte de la liste porte la consigne (la commande en attente de la démo aussi : 16 nov., Inventaire).
      expect(
        find.text('⏳ Ne pas livrer avant le 16 nov. · Inventaire'),
        findsNWidgets(2),
      );
      expect(find.text('🚚 Départ prévu à partir du 16 nov.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('une consigne incomplète rouvre la feuille avec un message', (
      tester,
    ) async {
      await _preparer(tester);
      await _versPanier(tester);
      // Consigne cochée, motif choisi, sans date : on valide la feuille sans date impossible, donc on force l'état.
      _conteneur(tester).read(commandeEnCoursProvider.notifier)
        ..basculerConsigne()
        ..choisirMotif('Impératif');
      await tester.pump();
      await tester.tap(find.text('✓ Valider'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Précisez le motif et la date de la consigne « ne pas livrer avant ».',
        ),
        findsOneWidget,
      );
      expect(find.text('Ne pas livrer avant…'), findsOneWidget);
      expect(_conteneur(tester).read(crmProvider).commandes, hasLength(10));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'le chef de secteur revient à l’écran racine après validation',
      (tester) async {
        await _preparer(tester, role: Role.cs, magasinId: 'm10');
        await _versPanier(tester);
        await tester.tap(find.text('✓ Valider'));
        await tester.pumpAndSettle();
        expect(find.text('Panier'), findsNothing);
        expect(find.text('Nouvelle commande'), findsNothing);
        final c = _conteneur(tester).read(crmProvider).commandes.first;
        expect(c.id, 'CDE-2044');
        expect(c.par, 'Nadia H.');
        expect(c.magasinId, 'm10');
        // Il revient à l'écran racine, sur son onglet courant (l'accueil).
        expect(_routeCourante(tester).isFirst, isTrue);
        expect(_conteneur(tester).read(ongletProvider), OngletApp.accueil);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'depuis une visite : on revient sur la visite, qui garde la commande',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        // Écran de la visite (lot visites) remplacé par une route de même nom : seul son nom compte pour le retour.
        unawaited(
          Navigator.of(_ctx(tester)).push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'visite'),
              builder: (_) => const Scaffold(body: Text('écran de la visite')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        unawaited(
          AppRoutes.priseCommande(
            _ctx(tester),
            magasinId: 'm4',
            visiteId: 'd0',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: _ligne('a1'), matching: find.text('＋ Ajouter')),
        );
        await tester.pump();
        await _versPanier(tester);
        await tester.tap(find.text('✓ Valider'));
        await tester.pumpAndSettle();
        expect(find.text('Panier'), findsNothing);
        expect(find.text('Nouvelle commande'), findsNothing);
        expect(find.text('écran de la visite'), findsOneWidget);
        expect(_routeCourante(tester).settings.name, 'visite');
        final etat = _conteneur(tester).read(crmProvider);
        final cmd = etat.visiteParId('d0')!.cmd!;
        expect(cmd.id, '2044');
        expect(cmd.ht, '20,76 €');
        expect(cmd.liv, '06/11/2026');
        expect(etat.commandes.first.id, 'CDE-2044');
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  group('Mettre en attente (cmd-attente l.1509-1515)', () {
    testWidgets('la commande est mise de côté, le promoteur la retrouve', (
      tester,
    ) async {
      await _preparer(tester);
      await _versPanier(tester);
      await tester.enterText(find.byType(TextFormField), 'À relancer demain');
      await tester.tap(find.text('⏸ Mettre en attente'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Commande mise en attente. Retrouvez-la dans Commandes pour la reprendre.',
        ),
        findsOneWidget,
      );
      expect(find.text('Panier'), findsNothing);
      expect(_conteneur(tester).read(commandeEnCoursProvider), isNull);
      // Onglet « Commandes » : deux commandes en attente, la nouvelle en tête.
      expect(find.text('Commandes en attente'), findsOneWidget);
      final attentes = _conteneur(tester).read(attenteProvider);
      expect(attentes, hasLength(2));
      expect(attentes.first.magasinId, 'm1');
      expect(attentes.first.note, 'À relancer demain');
      expect(attentes.first.date, '4 nov. 14:23');
      expect(find.text('2'), findsWidgets);
      expect(
        find.text('1 référence · 6 articles · 20,76 € HT'),
        findsOneWidget,
      );
      expect(find.text('📝 À relancer demain'), findsOneWidget);
      // Aucune commande n'a été créée.
      expect(_conteneur(tester).read(crmProvider).commandes, hasLength(10));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'reprendre puis valider envoie la commande et la retire de l’attente',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        AppRoutes.allerOnglet(_ctx(tester), OngletApp.commandes);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reprendre'));
        await tester.pumpAndSettle();
        expect(find.text('Panier'), findsOneWidget);
        await tester.tap(find.text('✓ Valider'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Commande CDE-2044 enregistrée · livraison à partir du 16 nov.. Envoi dès que le réseau le permet.',
          ),
          findsOneWidget,
        );
        expect(_conteneur(tester).read(attenteProvider), isEmpty);
        expect(find.text('Commandes en attente'), findsNothing);
        final c = _conteneur(tester).read(crmProvider).commandes.first;
        expect(c.magasinId, 'm8');
        expect(c.lignes, 2);
        expect(c.ht, '662,16 €');
        expect(c.colis, 3); // 36 articles
        expect(c.note, 'En attente de la validation du chef de rayon');
        expect(c.pasAvant, '2026-11-16');
        expect(c.motifPas, 'Inventaire');
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'reprendre puis remettre en attente remplace la commande reprise',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        AppRoutes.allerOnglet(_ctx(tester), OngletApp.commandes);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reprendre'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Plus').first);
        await tester.pump();
        await tester.tap(find.text('⏸ Mettre en attente'));
        await tester.pumpAndSettle();
        final attentes = _conteneur(tester).read(attenteProvider);
        expect(attentes, hasLength(1));
        expect(attentes.single.lignes.first.qty, 13);
        expect(attentes.single.dateMin, '2026-11-16');
        expect(attentes.single.motifPas, 'Inventaire');
        expect(
          find.text('2 références · 37 articles · 684,78 € HT'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}
