import 'dart:async';

import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/theme/theme.dart';
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

/// Ouvre une feuille par `AppRoutes` et attend sa fin d'ouverture.
Future<void> _ouvrir(
  WidgetTester tester,
  Future<void> Function(BuildContext) ouvrir,
) async {
  unawaited(ouvrir(_ctx(tester)));
  await tester.pumpAndSettle();
}

/// La ligne rouge du scan, dessinée par un conteneur de la couleur d'alerte.
Finder get _ligneScan => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).color == AppColors.alert,
);

/// La vue de la caméra simulée : le fond sombre `#111827` de 190 px.
Finder get _vueScan => find.byWidgetPredicate(
  (w) => w is Container && w.color == const Color(0xFF111827),
);

double _hauteurLigneScan(WidgetTester tester) =>
    tester.getTopLeft(_ligneScan).dy - tester.getTopLeft(_vueScan).dy;

void main() {
  setUpAll(chargerInter);

  group('Suivi du transport (slivraison l.1424-1435)', () {
    testWidgets(
      'commande pas encore expédiée : étapes à venir, transporteur non attribué',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        await _ouvrir(tester, (c) => AppRoutes.detailLivraison(c, 'CDE-2041'));
        expect(find.text('CDE-2041 · E.Leclerc – Paris'), findsOneWidget);
        expect(dansFeuille(find.text('Pas livrée')), findsOneWidget);
        expect(
          find.text('1 540,00 € HT · 9 références · 8 colis'),
          findsOneWidget,
        );
        expect(find.text('SUIVI DU TRANSPORT'), findsOneWidget);
        expect(find.text('Commande reçue'), findsOneWidget);
        expect(find.text('3 nov. 10:12'), findsOneWidget);
        expect(find.text('Expédiée'), findsOneWidget);
        expect(find.text('À venir'), findsOneWidget);
        expect(find.text('Prévue ven. 6 nov.'), findsOneWidget);
        expect(find.text('…'), findsNWidgets(2));
        expect(find.text('TRANSPORTEUR'), findsOneWidget);
        expect(find.text('Origine'), findsOneWidget);
        expect(find.text("Saisie dans l'appli"), findsOneWidget);
        expect(find.text('Pas encore attribué'), findsOneWidget);
        expect(find.text('N° de suivi'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
        expect(find.text('Livraison'), findsOneWidget);
        expect(dansFeuille(find.text('ven. 6 nov.')), findsOneWidget);
        expect(find.text('Ne pas livrer avant'), findsNothing);
        // Pas de numéro de suivi : pas de lien vers le transporteur.
        expect(find.textContaining('Suivre le colis'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'commande EDI expédiée : transporteur, suivi du colis et lien',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        await _ouvrir(tester, (c) => AppRoutes.detailLivraison(c, 'CDE-2039'));
        expect(
          find.text('CDE-2039 · U Express – Boulogne-Billancourt'),
          findsOneWidget,
        );
        expect(find.text('Commande EDI'), findsOneWidget);
        expect(find.text('Geodis'), findsOneWidget);
        expect(find.text('GEO48271093'), findsOneWidget);
        expect(find.text('3 nov. 18:40 · Geodis'), findsOneWidget);
        expect(find.text('Prévue jeu. 5 nov.'), findsOneWidget);
        expect(
          find.text('…'),
          findsOneWidget,
        ); // seule « Livrée » reste à venir
        expect(find.text('À venir'), findsNothing);

        await tester.tap(find.text('🚚 Suivre le colis chez le transporteur'));
        await tester.pump();
        expect(
          find.text('Ouverture du suivi du transporteur (lien externe).'),
          findsOneWidget,
        );
        // La feuille reste ouverte.
        expect(find.text('SUIVI DU TRANSPORT'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'commande livrée : toutes les étapes sont faites, rien à venir',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        await _ouvrir(tester, (c) => AppRoutes.detailLivraison(c, 'CDE-2018'));
        expect(
          dansFeuille(find.text('Livrée')),
          findsNWidgets(2),
        ); // pastille + étape
        expect(
          find.text('22 oct. 10:42 · signée par Mme Petit'),
          findsOneWidget,
        );
        expect(find.text('20 oct. 18:00 · Geodis'), findsOneWidget);
        expect(find.text('…'), findsNothing);
        expect(find.text('À venir'), findsNothing);
        expect(find.text('livrée le 22 oct.'), findsOneWidget);
        expect(
          find.text('2 340,00 € HT · 14 références · 14 colis'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'la consigne « ne pas livrer avant » d’une commande de l’appli y figure',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        _conteneur(tester)
            .read(crmProvider.notifier)
            .ajouterCommande(
              const Commande(
                src: 'Appli',
                id: 'CDE-2044',
                magasinId: 'm1',
                date: '4 nov.',
                ht: '20,76 €',
                lignes: 1,
                statut: StatutLivraison.pasLivree,
                eta: 'à partir du 16 nov.',
                colis: 1,
                evenements: [
                  EvenementTransport('Commande reçue', '4 nov. 14:23'),
                ],
                pasAvant: '2026-11-16',
                motifPas: 'Impératif',
              ),
            );
        await _ouvrir(tester, (c) => AppRoutes.detailLivraison(c, 'CDE-2044'));
        expect(find.text('Ne pas livrer avant'), findsOneWidget);
        expect(find.text('16 nov.'), findsOneWidget);
        expect(find.text('Motif'), findsOneWidget);
        expect(find.text('Impératif'), findsOneWidget);
        expect(find.text('à partir du 16 nov.'), findsOneWidget);
      },
    );

    testWidgets('le directeur ouvre le suivi d’une commande de sa région', (
      tester,
    ) async {
      await lancerApp(tester, Role.dir);
      await _ouvrir(tester, (c) => AppRoutes.detailLivraison(c, 'CDE-2036'));
      expect(find.text('CDE-2036 · Super U – Amiens'), findsOneWidget);
      expect(find.text('Commande EDI'), findsOneWidget);
      expect(find.text('lun. 9 nov.'), findsWidgets);
    });
  });

  group('Scan simulé (cmd-scan l.1410-1415)', () {
    testWidgets('la ligne rouge va et vient entre 32 et 156 px', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      unawaited(AppRoutes.scannerProduit(_ctx(tester)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Scanner un produit'), findsOneWidget);
      expect(tester.getSize(_vueScan).height, 190);

      final positions = <double>[];
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 450));
        positions.add(_hauteurLigneScan(tester));
      }
      for (final p in positions) {
        expect(p, inInclusiveRange(32, 156));
      }
      expect(positions.toSet().length, greaterThan(3)); // la ligne bouge
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('animation réduite : la ligne reste à mi-hauteur', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await lancerApp(tester, Role.promoteur);
      await _ouvrir(tester, AppRoutes.scannerProduit);
      expect(find.text('Scanner un produit'), findsOneWidget);
      expect(_hauteurLigneScan(tester), 95);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_hauteurLigneScan(tester), 95);
    });

    testWidgets(
      'sans commande en cours, « Simuler un scan » ferme simplement la feuille',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await lancerApp(tester, Role.promoteur);
        await _ouvrir(tester, AppRoutes.scannerProduit);
        await tester.tap(find.text('Simuler un scan'));
        await tester.pumpAndSettle();
        expect(find.text('Scanner un produit'), findsNothing);
        expect(_conteneur(tester).read(commandeEnCoursProvider), isNull);
      },
    );
  });

  group('Feuilles ouvertes sans commande en cours', () {
    testWidgets('produits de remplacement d’un produit en rupture', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await _ouvrir(tester, (c) => AppRoutes.produitsRemplacement(c, 'a13'));
      expect(find.text('Produits de remplacement'), findsOneWidget);
      expect(find.text('Choisir'), findsNWidgets(3));
      await tester.tap(find.text('Choisir').first);
      await tester.pumpAndSettle();
      expect(find.text('Produits de remplacement'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('« Ne pas livrer avant… » se ferme par le voile sans effet', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await _ouvrir(tester, AppRoutes.nePasLivrerAvant);
      expect(find.text('Ne pas livrer avant…'), findsOneWidget);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.text('Ne pas livrer avant…'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filtres de la prise de commande', (tester) async {
      await lancerApp(tester, Role.promoteur);
      await _ouvrir(tester, AppRoutes.filtresPriseCommande);
      expect(find.text('Voir 14 produits'), findsOneWidget);
      await tester.tap(find.text('Voir 14 produits'));
      await tester.pumpAndSettle();
      expect(find.text('Filtres'), findsNothing);
    });
  });
}
