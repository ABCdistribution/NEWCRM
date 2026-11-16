import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/commandes/prise_commande_screen.dart';
import 'package:crm_app/features/commandes/state/commande_provider.dart';
import 'package:crm_app/features/commandes/widgets/stock_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'support_commandes.dart';

ProviderContainer _conteneur(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PriseCommandeScreen)));

/// Quantité d'un produit dans la commande en cours (0 s'il n'y est pas).
int _qty(WidgetTester tester, String produitId) =>
    _conteneur(tester).read(commandeEnCoursProvider)?.ligne(produitId)?.qty ??
    0;

/// La ligne du catalogue d'un produit.
Finder _ligne(String produitId) => find.byWidgetPredicate(
  (w) => w is LigneProduit && w.produit.id == produitId,
);

/// Ouvre la feuille de scan : sa ligne rouge s'anime sans fin, `pumpAndSettle` ne peut donc pas être utilisé.
Future<void> ouvrirScan(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Scanner un code-barres'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Laisse la feuille de scan se refermer.
Future<void> laisserFermer(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _ouvrir(
  WidgetTester tester, {
  String? magasinId = 'm1',
  Role role = Role.promoteur,
}) => pumpEcran(tester, PriseCommandeScreen(magasinId: magasinId), role: role);

void main() {
  setUpAll(chargerInter);

  group('Étape 1 : choisir le client (cmdEcran l.1600-1603)', () {
    testWidgets('liste les clients actifs du promoteur avec leur adresse', (
      tester,
    ) async {
      await _ouvrir(tester, magasinId: null);
      expect(find.text('Nouvelle commande'), findsOneWidget);
      expect(find.text('Étape 1 sur 2 · choisissez le client'), findsOneWidget);
      // Portefeuille de Julien M. : m1, m4, m5 (inactif, écarté) et m8.
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(
        find.text('104 avenue des Champs, 78000 Versailles'),
        findsOneWidget,
      );
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsOneWidget);
      expect(find.text('U Express – Boulogne-Billancourt'), findsOneWidget);
      expect(find.text('U Express – Paris'), findsNothing);
      expect(find.text('›'), findsNWidgets(3));
      expect(find.text('Nom, marque, réf. ou EAN'), findsNothing);
    });

    testWidgets('choisir un client passe au catalogue de ce client', (
      tester,
    ) async {
      await _ouvrir(tester, magasinId: null);
      await tester.tap(find.text('Carrefour Market – Versailles'));
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 sur 2 · choisissez le client'), findsNothing);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(find.text('Nom, marque, réf. ou EAN'), findsOneWidget);
      expect(_conteneur(tester).read(commandeEnCoursProvider)!.magasinId, 'm1');
    });

    testWidgets('le chef de secteur et le directeur voient leurs clients', (
      tester,
    ) async {
      await _ouvrir(tester, magasinId: null, role: Role.cs);
      // Secteur s1 : 6 clients dont un inactif (m5).
      expect(find.byType(AppCarte), findsNWidgets(5));
      expect(find.text('E.Leclerc – Paris'), findsOneWidget);
    });
  });

  group('Catalogue (cmdEcran l.1604-1621)', () {
    testWidgets('affiche les 14 produits avec stock, prix et colisage', (
      tester,
    ) async {
      await _ouvrir(tester);
      expect(find.text('Nouvelle commande'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(find.byType(LigneProduit, skipOffstage: false), findsNWidgets(14));
      expect(find.text('Shampooing doux usage fréquent'), findsOneWidget);
      expect(
        find.text('Franck Provost · Réf. 900016 · 3,46 € HT'),
        findsOneWidget,
      );
      expect(find.text('● En stock · 98 disponibles'), findsOneWidget);
      expect(find.text('● Stock bas · 45 disponibles'), findsOneWidget);
      expect(find.text('＋ Ajouter'), findsWidgets);
      // Barre du bas vide.
      expect(find.text('0 article'), findsOneWidget);
      expect(find.text('0,00 € HT'), findsOneWidget);
      expect(find.text('Voir le panier ›'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un produit en rupture propose « Remplacer » et sa date', (
      tester,
    ) async {
      await _ouvrir(tester);
      final rupture = _ligne('a13');
      await tester.ensureVisible(rupture);
      await tester.pump();
      expect(
        find.descendant(of: rupture, matching: find.text('Remplacer ›')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rupture,
          matching: find.text('● Rupture · disponible le 12 nov.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rupture,
          matching: find.text('Le produit sera disponible à partir du 12 nov.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rupture, matching: find.text('＋ Ajouter')),
        findsNothing,
      );
    });

    testWidgets(
      '« Ajouter » prend le colisage, le compteur ajuste la quantité',
      (tester) async {
        await _ouvrir(tester);
        final a1 = _ligne('a1');
        await tester.tap(
          find.descendant(of: a1, matching: find.text('＋ Ajouter')),
        );
        await tester.pump();
        expect(_qty(tester, 'a1'), 6); // colisage de 6
        expect(find.byType(StepperQte), findsOneWidget);
        expect(find.text('6 articles'), findsOneWidget);
        expect(find.text('20,76 € HT'), findsOneWidget); // 3,46 × 6

        await tester.tap(find.bySemanticsLabel('Plus'));
        await tester.pump();
        expect(_qty(tester, 'a1'), 7);
        expect(find.text('7 articles'), findsOneWidget);
        expect(find.text('24,22 € HT'), findsOneWidget);

        for (var i = 0; i < 6; i++) {
          await tester.tap(find.bySemanticsLabel('Moins'));
          await tester.pump();
        }
        expect(_qty(tester, 'a1'), 1);
        expect(find.text('1 article'), findsOneWidget); // singulier
        await tester.tap(find.bySemanticsLabel('Moins'));
        await tester.pump();
        expect(_qty(tester, 'a1'), 0);
        expect(find.byType(StepperQte), findsNothing);
        expect(find.text('0 article'), findsOneWidget);
      },
    );

    testWidgets('au-delà du stock, le catalogue propose un remplacement', (
      tester,
    ) async {
      await _ouvrir(tester);
      final a4 = _ligne('a4'); // 8 disponibles, colisage 6
      await tester.ensureVisible(a4);
      await tester.pump();
      await tester.tap(
        find.descendant(of: a4, matching: find.text('＋ Ajouter')),
      );
      await tester.pump();
      expect(
        find.textContaining('Stock insuffisant', findRichText: true),
        findsNothing,
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(
          find.descendant(of: a4, matching: find.bySemanticsLabel('Plus')),
        );
        await tester.pump();
      }
      expect(_qty(tester, 'a4'), 9);
      expect(
        texteRiche(
          'Stock insuffisant : 8 disponibles pour 9 demandés. Compléter avec un remplacement ›',
        ),
        findsOneWidget,
      );
    });
  });

  group('Recherche et filtres', () {
    testWidgets(
      'la recherche porte sur le nom, la marque, la référence et l’EAN',
      (tester) async {
        await _ouvrir(tester);
        final champ = find.byType(TextFormField);

        await tester.enterText(champ, 'rouge');
        await tester.pump();
        expect(
          find.byType(LigneProduit, skipOffstage: false),
          findsNWidgets(3),
        );

        await tester.enterText(champ, 'jean louis');
        await tester.pump();
        expect(
          find.byType(LigneProduit, skipOffstage: false),
          findsNWidgets(4),
        );

        await tester.enterText(champ, '900040');
        await tester.pump();
        expect(find.byType(LigneProduit), findsOneWidget);
        expect(find.text('Stick lèvres SPF 30'), findsOneWidget);

        await tester.enterText(champ, '376123450016');
        await tester.pump();
        expect(find.text('Shampooing doux usage fréquent'), findsOneWidget);

        await tester.enterText(champ, 'zzz');
        await tester.pump();
        expect(find.text('Aucun produit.'), findsOneWidget);
      },
    );

    testWidgets(
      'la feuille de filtres filtre par marque et masque les ruptures',
      (tester) async {
        await _ouvrir(tester);
        await tester.tap(find.bySemanticsLabel('Filtres'));
        await tester.pumpAndSettle();
        for (final t in [
          'Filtres',
          'MARQUE',
          'Toutes les marques',
          'Franck Provost',
          'Jean Louis David',
          'MB Milano',
          'AUTRES',
          'Masquer les produits en rupture',
          'Réinitialiser',
          'Voir 14 produits',
        ]) {
          expect(find.text(t), findsWidgets, reason: t);
        }

        await toucher(tester, dansFeuille(find.text('MB Milano')));
        expect(find.text('Voir 6 produits'), findsOneWidget);
        expect(
          find.byType(LigneProduit, skipOffstage: false),
          findsNWidgets(6),
        );

        await toucher(tester, dansFeuille(find.byType(Interrupteur)));
        expect(find.text('Voir 5 produits'), findsOneWidget);
        expect(
          find.byType(LigneProduit, skipOffstage: false),
          findsNWidgets(5),
        );
        expect(find.text('Stick lèvres SPF 30'), findsNothing);

        await toucher(tester, find.text('Voir 5 produits'));
        expect(find.text('Filtres'), findsNothing);
        // Marque et masquage : deux filtres actifs sur le bouton.
        final filtre = tester.widget<BoutonFiltre>(
          find.byWidgetPredicate(
            (w) => w is BoutonFiltre && w.semantique == 'Filtres',
          ),
        );
        expect(filtre.nbFiltres, 2);

        await tester.tap(find.bySemanticsLabel('Filtres'));
        await tester.pumpAndSettle();
        await toucher(tester, find.text('Réinitialiser'));
        expect(find.text('Voir 14 produits'), findsOneWidget);
        expect(
          find.byType(LigneProduit, skipOffstage: false),
          findsNWidgets(14),
        );
      },
    );

    testWidgets('« Voir N produits » ignore la recherche, comme la maquette', (
      tester,
    ) async {
      await _ouvrir(tester);
      await tester.enterText(find.byType(TextFormField), 'rouge');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Filtres'));
      await tester.pumpAndSettle();
      expect(find.text('Voir 14 produits'), findsOneWidget);
    });
  });

  group('Remplacement d’un produit', () {
    testWidgets(
      'produit en rupture : trois propositions classées par prix proche',
      (tester) async {
        await _ouvrir(tester);
        await toucher(
          tester,
          find.descendant(
            of: _ligne('a13'),
            matching: find.text('Remplacer ›'),
          ),
        );
        expect(find.text('Produits de remplacement'), findsOneWidget);
        expect(
          dansFeuille(find.textContaining('Stick lèvres SPF 30')),
          findsOneWidget,
        );
        expect(
          dansFeuille(find.textContaining('Rupture · disponible le 12 nov.')),
          findsWidgets,
        );
        expect(
          texteRiche(
            'Proposés de la même marque, en stock (même famille en premier). Quantité reprise : 6.',
          ),
          findsOneWidget,
        );
        // Aucun n'est de la famille « Protections SPF » : le prix le plus proche (20,05 €) décide.
        expect(
          [
            for (final t in tester.widgetList<Text>(
              dansFeuille(
                find.byWidgetPredicate(
                  (w) => w is Text && w.style?.fontSize == 14,
                ),
              ),
            ))
              t.data,
          ],
          ['Rouge longue tenue 412', 'Rouge mat 101', 'Gloss nude 310'],
        );
        expect(texteRiche('· même famille'), findsNothing);
        expect(find.text('Choisir'), findsNWidgets(3));
        expect(find.text('Stick lèvres SPF 30'), findsWidgets);
      },
    );

    testWidgets('choisir un remplacement reprend la quantité et le dit', (
      tester,
    ) async {
      await _ouvrir(tester);
      await toucher(
        tester,
        find.descendant(of: _ligne('a13'), matching: find.text('Remplacer ›')),
      );
      await tester.tap(find.text('Choisir').first);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Produits de remplacement'), findsNothing);
      expect(
        find.text('Rouge longue tenue 412 ajouté en remplacement.'),
        findsOneWidget,
      );
      final ligne = _conteneur(
        tester,
      ).read(commandeEnCoursProvider)!.ligne('a14')!;
      expect(ligne.qty, 6); // colisage du produit en rupture
      expect(ligne.remplace, 'a13');
      expect(find.text('6 articles'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'stock insuffisant : on garde le disponible, le reste passe au remplacement',
      (tester) async {
        await _ouvrir(tester);
        final a4 = _ligne('a4');
        await tester.ensureVisible(a4);
        await tester.pump();
        await tester.tap(
          find.descendant(of: a4, matching: find.text('＋ Ajouter')),
        );
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          await tester.tap(
            find.descendant(of: a4, matching: find.bySemanticsLabel('Plus')),
          );
          await tester.pump();
        }
        await tester.ensureVisible(find.byType(ErreurStock));
        await tester.pump();
        await tester.tapOnText(
          find.textRange.ofSubstring('Compléter avec un remplacement ›'),
        );
        await tester.pumpAndSettle();
        expect(
          texteRiche('Stock insuffisant : 8 disponibles, 9 demandés'),
          findsOneWidget,
        );
        expect(texteRiche('Quantité reprise : 1.'), findsOneWidget);
        // Même famille (Colorations) d'abord : Coloration châtain 4.0, puis le prix le plus proche.
        expect(texteRiche('· même famille'), findsOneWidget);
        expect(find.text('Choisir'), findsNWidgets(3));

        await tester.tap(find.text('Choisir').first);
        await tester.pumpAndSettle();
        expect(_qty(tester, 'a4'), 8); // le disponible est conservé
        final remplacement = _conteneur(
          tester,
        ).read(commandeEnCoursProvider)!.ligne('a3')!;
        expect(remplacement.qty, 1);
        expect(remplacement.remplace, 'a4');
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  group('Scan simulé', () {
    testWidgets('chaque scan lit le produit disponible suivant', (
      tester,
    ) async {
      await _ouvrir(tester);
      await ouvrirScan(tester);
      expect(find.text('Scanner un produit'), findsOneWidget);
      expect(
        find.text(
          'Pointez la caméra vers le code-barres (EAN) du produit : il est ajouté à la commande.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Simuler un scan'));
      await laisserFermer(tester);
      expect(find.text('Scanner un produit'), findsNothing);
      expect(
        find.text('✓ Shampooing doux usage fréquent ajouté · EAN 376123450016'),
        findsOneWidget,
      );
      expect(_qty(tester, 'a1'), 6);
      await tester.pump(const Duration(seconds: 3));

      // Deuxième scan : le produit suivant ; troisième : encore le suivant.
      for (final suivant in ['a2', 'a3']) {
        await ouvrirScan(tester);
        await tester.tap(find.text('Simuler un scan'));
        await laisserFermer(tester);
        expect(_qty(tester, suivant), greaterThan(0), reason: suivant);
      }
      expect(_qty(tester, 'a2'), 6);
      expect(_qty(tester, 'a3'), 6);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('« Annuler » ferme la feuille sans rien ajouter', (
      tester,
    ) async {
      await _ouvrir(tester);
      await ouvrirScan(tester);
      await tester.tap(find.text('Annuler'));
      await laisserFermer(tester);
      expect(find.text('Scanner un produit'), findsNothing);
      expect(_conteneur(tester).read(commandeEnCoursProvider)!.lignes, isEmpty);
    });
  });

  testWidgets('« Voir le panier » ouvre le panier de la commande', (
    tester,
  ) async {
    await _ouvrir(tester);
    await tester.tap(
      find.descendant(of: _ligne('a1'), matching: find.text('＋ Ajouter')),
    );
    await tester.pump();
    await tester.tap(find.text('Voir le panier ›'));
    await tester.pumpAndSettle();
    expect(find.text('Panier'), findsOneWidget);
    expect(find.text('Shampooing doux usage fréquent'), findsOneWidget);
  });

  testWidgets('une nouvelle prise de commande repart d’une commande vide', (
    tester,
  ) async {
    await pumpEcran(
      tester,
      Builder(
        builder: (ctx) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => AppRoutes.priseCommande(ctx, magasinId: 'm1'),
                child: const Text('ouvrir m1'),
              ),
              TextButton(
                onPressed: () => AppRoutes.priseCommande(ctx, magasinId: 'm4'),
                child: const Text('ouvrir m4'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir m1'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: _ligne('a1'), matching: find.text('＋ Ajouter')),
    );
    await tester.pump();
    expect(_qty(tester, 'a1'), 6);
    await tester.tap(find.byType(BoutonRetour));
    await tester.pumpAndSettle();
    // La commande reste en mémoire après le retour (comme `S.cmd`), mais une nouvelle prise de commande la remplace.
    await tester.tap(find.text('ouvrir m4'));
    await tester.pumpAndSettle();
    expect(_qty(tester, 'a1'), 0);
    expect(find.text('Carrefour – Ivry-sur-Seine'), findsOneWidget);
  });
}
