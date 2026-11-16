import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/visites/kit_detail_sheet.dart';
import 'package:crm_app/features/visites/kits_sheet.dart';
import 'package:crm_app/features/visites/saisie_etape_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_visites.dart';

/// Brouillon chez Carrefour Market – Versailles (m1) avec la saisie de `etape` ouverte par-dessus.
Future<String> ouvrirSaisie(
  WidgetTester tester,
  EtapeDph etape, {
  Role role = Role.promoteur,
}) async {
  final id = await demarrerVisiteChez(tester, role, 'm1');
  if (role == Role.promoteur) {
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
  }
  AppRoutes.saisieEtapeVisite(
    contexteCoquille(tester),
    visiteId: id,
    etape: etape,
  );
  await tester.pumpAndSettle();
  return id;
}

Visite visite(WidgetTester tester, String id) =>
    storeApp(tester).visites.firstWhere((v) => v.id == id);

Future<void> enregistrer(WidgetTester tester, String libelle) async {
  await tester.tap(find.text(libelle));
  await tester.pumpAndSettle();
}

void main() {
  group('Saisie : vérification DN (visiteSaisie l.1282-1289)', () {
    testWidgets('sans kit : consigne vide et refus d’enregistrer', (
      tester,
    ) async {
      await ouvrirSaisie(tester, EtapeDph.dn);
      expect(find.byType(SaisieEtapeScreen), findsOneWidget);
      expect(find.text('Vérification DN'), findsWidgets);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(find.text('DISTRIBUTION NUMÉRIQUE PAR KIT'), findsOneWidget);
      expect(find.text('Sélectionner les kits du rayon…'), findsOneWidget);
      expect(
        find.text(
          'Aucun kit sélectionné : choisissez les kits constatés en rayon, pour la distribution numérique.',
        ),
        findsOneWidget,
      );
      await enregistrer(tester, '✓ Enregistrer la vérification DN');
      expect(
        find.text('Sélectionnez au moins un kit pour la vérification DN.'),
        findsOneWidget,
      );
      expect(find.byType(SaisieEtapeScreen), findsOneWidget);
      await attendreToast(tester);
    });

    testWidgets(
      'choisir des kits, ouvrir leur détail, en retirer un, enregistrer',
      (tester) async {
        final id = await ouvrirSaisie(tester, EtapeDph.dn);
        await tester.tap(find.text('Sélectionner les kits du rayon…'));
        await tester.pumpAndSettle();
        expect(find.byType(KitsSheet), findsOneWidget);
        expect(find.text('Valider (0)'), findsOneWidget);
        await tester.tap(find.textContaining('COSMIA ZIPPED PLANE KIT'));
        await tester.tap(find.textContaining('Kit racines brun'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Valider (2)'));
        await tester.pumpAndSettle();

        expect(visite(tester, id).kits, ['COSMIA-01', '900024']);
        expect(visite(tester, id).dn, {'COSMIA-01': 0, '900024': 0});
        expect(
          find.text('2 kits sélectionnés · ajouter ou retirer…'),
          findsOneWidget,
        );
        expect(find.text('COSMIA ZIPPED PLANE KIT ›'), findsOneWidget);
        expect(find.text('Cosmia · Réf. COSMIA-01'), findsOneWidget);
        expect(find.text('Kit racines brun ›'), findsOneWidget);
        expect(find.text('Jean Louis David · Réf. 900024'), findsOneWidget);
        expect(find.text('✕'), findsNWidgets(2));
        expect(find.textContaining('Aucun kit sélectionné'), findsNothing);

        // un appui sur le nom ouvre la composition du kit
        await tester.tap(find.text('COSMIA ZIPPED PLANE KIT ›'));
        await tester.pumpAndSettle();
        expect(find.byType(KitDetailSheet), findsOneWidget);
        expect(
          find.text('Réf. COSMIA-01 · 5 produits dans le kit'),
          findsOneWidget,
        );
        await tester.tap(find.text('Fermer'));
        await tester.pumpAndSettle();

        // la croix retire le kit
        await tester.tap(find.text('✕').first);
        await tester.pumpAndSettle();
        expect(visite(tester, id).kits, ['900024']);
        expect(visite(tester, id).dn.keys, ['900024']);
        expect(
          find.text('1 kit sélectionné · ajouter ou retirer…'),
          findsOneWidget,
        );

        await enregistrer(tester, '✓ Enregistrer la vérification DN');
        expect(find.text('Vérification DN enregistrée.'), findsOneWidget);
        expect(find.byType(SaisieEtapeScreen), findsNothing);
        expect(visite(tester, id).chrono[EtapeDph.dn], '04/11/2026 14h27');
        expect(find.text('04/11/2026 14h27 · 1 kit'), findsOneWidget);
        expect(find.text('Modifier'), findsOneWidget);
      },
    );

    testWidgets('chef de secteur : même saisie', (tester) async {
      await ouvrirSaisie(tester, EtapeDph.dn, role: Role.cs);
      expect(find.text('DISTRIBUTION NUMÉRIQUE PAR KIT'), findsOneWidget);
      expect(find.text('✓ Enregistrer la vérification DN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Saisie : concurrence (visiteSaisie l.1298-1303)', () {
    testWidgets('textes, consignes vides et refus', (tester) async {
      final id = await ouvrirSaisie(tester, EtapeDph.concurrence);
      expect(find.text('Concurrence'), findsWidgets);
      expect(find.text('MARQUES ET MÉTRAGES CONCURRENTS'), findsOneWidget);
      expect(find.text('Aucune marque concurrente en rayon'), findsOneWidget);
      expect(find.text('Marque concurrente'), findsOneWidget);
      expect(find.text('Ex. nom de la marque'), findsOneWidget);
      expect(find.text('Métrage (mètres linéaires)'), findsOneWidget);
      expect(find.text('Ex. 1,5'), findsOneWidget);
      expect(find.text('＋ Ajouter cette marque'), findsOneWidget);
      expect(
        find.text(
          'Aucune marque saisie : ajoutez les marques concurrentes et leur métrage, ou cochez « Aucune marque concurrente ».',
        ),
        findsOneWidget,
      );
      await enregistrer(tester, '✓ Enregistrer la concurrence');
      expect(
        find.text(
          'Ajoutez au moins une marque concurrente, ou cochez « Aucune marque concurrente ».',
        ),
        findsOneWidget,
      );
      expect(
        visite(tester, id).chrono.containsKey(EtapeDph.concurrence),
        isFalse,
      );
      await attendreToast(tester);
    });

    testWidgets(
      'ajouter des marques, avec contrôle de la marque et du métrage',
      (tester) async {
        final id = await ouvrirSaisie(tester, EtapeDph.concurrence);
        final champs = find.byType(EditableText);

        await enregistrer(tester, '＋ Ajouter cette marque');
        expect(find.text('Indiquez la marque concurrente.'), findsOneWidget);
        await attendreToast(tester);

        await tester.enterText(champs.at(0), 'Marque X');
        await enregistrer(tester, '＋ Ajouter cette marque');
        expect(
          find.text('Indiquez le métrage en mètres (ex. 1,5).'),
          findsOneWidget,
        );
        await attendreToast(tester);
        await tester.enterText(champs.at(1), '0');
        await enregistrer(tester, '＋ Ajouter cette marque');
        expect(
          find.text('Indiquez le métrage en mètres (ex. 1,5).'),
          findsOneWidget,
        );
        await attendreToast(tester);
        expect(visite(tester, id).concurrence.liste, isEmpty);

        await tester.enterText(champs.at(1), '1,5');
        await enregistrer(tester, '＋ Ajouter cette marque');
        expect(visite(tester, id).concurrence.liste.length, 1);
        expect(visite(tester, id).concurrence.liste.first.marque, 'Marque X');
        expect(visite(tester, id).concurrence.liste.first.metrage, 1.5);
        expect(find.text('1,5 m linéaire'), findsOneWidget);
        // les champs sont vidés et la consigne vide disparaît
        expect(
          tester.widget<EditableText>(champs.at(0)).controller.text,
          isEmpty,
        );
        expect(find.textContaining('Aucune marque saisie'), findsNothing);

        await tester.enterText(champs.at(0), '  Marque Y  ');
        await tester.enterText(champs.at(1), '2');
        await enregistrer(tester, '＋ Ajouter cette marque');
        expect(find.text('Marque Y'), findsOneWidget);
        expect(find.text('2 m linéaire'), findsOneWidget);

        await enregistrer(tester, '✓ Enregistrer la concurrence');
        expect(find.text('Concurrence enregistrée.'), findsOneWidget);
        expect(find.text('04/11/2026 14h27 · 2 marques'), findsOneWidget);
      },
    );

    testWidgets('retirer une marque, puis « Aucune marque concurrente »', (
      tester,
    ) async {
      final id = await ouvrirSaisie(tester, EtapeDph.concurrence);
      final champs = find.byType(EditableText);
      for (final (m, l) in [('A', '1'), ('B', '2')]) {
        await tester.enterText(champs.at(0), m);
        await tester.enterText(champs.at(1), l);
        await enregistrer(tester, '＋ Ajouter cette marque');
      }
      await tester.tap(find.text('✕').first);
      await tester.pumpAndSettle();
      expect(visite(tester, id).concurrence.liste.map((c) => c.marque), ['B']);

      // cocher « aucune » vide la liste et masque la saisie
      await tester.tap(find.byType(Interrupteur));
      await tester.pumpAndSettle();
      expect(visite(tester, id).concurrence.aucune, isTrue);
      expect(visite(tester, id).concurrence.liste, isEmpty);
      expect(find.text('Marque concurrente'), findsNothing);
      expect(find.text('＋ Ajouter cette marque'), findsNothing);
      expect(find.textContaining('Aucune marque saisie'), findsNothing);

      await enregistrer(tester, '✓ Enregistrer la concurrence');
      expect(find.text('Concurrence enregistrée.'), findsOneWidget);
      expect(find.text('04/11/2026 14h27 · aucune marque'), findsOneWidget);
    });

    testWidgets('la décoration « aucune » se défait', (tester) async {
      final id = await ouvrirSaisie(tester, EtapeDph.concurrence);
      await tester.tap(find.byType(Interrupteur));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Interrupteur));
      await tester.pumpAndSettle();
      expect(visite(tester, id).concurrence.aucune, isFalse);
      expect(find.text('Marque concurrente'), findsOneWidget);
    });
  });

  group('Saisie : promotions (visiteSaisie l.1304-1305)', () {
    testWidgets('il faut dire si les promotions sont conformes', (
      tester,
    ) async {
      final id = await ouvrirSaisie(tester, EtapeDph.promos);
      expect(find.text('Vérification Promos'), findsWidgets);
      expect(
        find.text('Les promotions sont en place et conformes'),
        findsOneWidget,
      );
      expect(find.text('Remarque (facultatif)'), findsOneWidget);
      expect(find.text('Ex. tête de gondole non refaite'), findsOneWidget);
      await enregistrer(tester, '✓ Enregistrer la vérification Promos');
      expect(
        find.text('Indiquez si les promotions sont conformes.'),
        findsOneWidget,
      );
      expect(visite(tester, id).promosConformes, isNull);
      await attendreToast(tester);

      await tester.tap(find.byType(Interrupteur));
      await tester.pumpAndSettle();
      expect(visite(tester, id).promosConformes, isTrue);
      await tester.tap(find.byType(Interrupteur));
      await tester.pumpAndSettle();
      // « non » est une réponse : on peut enregistrer
      expect(visite(tester, id).promosConformes, isFalse);
      await enregistrer(tester, '✓ Enregistrer la vérification Promos');
      expect(find.text('Vérification Promos enregistrée.'), findsOneWidget);
      expect(find.byType(SaisieEtapeScreen), findsNothing);
      expect(visite(tester, id).chrono.containsKey(EtapeDph.promos), isTrue);
    });

    testWidgets('la remarque est conservée au fil de la frappe', (
      tester,
    ) async {
      final id = await ouvrirSaisie(tester, EtapeDph.promos);
      await tester.enterText(
        find.byType(EditableText),
        'tête de gondole non refaite',
      );
      await tester.pumpAndSettle();
      expect(visite(tester, id).promosNote, 'tête de gondole non refaite');
      expect(find.text('tête de gondole non refaite'), findsOneWidget);
    });
  });

  group('Saisie : bilan de visite (visiteSaisie l.1290-1297)', () {
    testWidgets('résumé des résultats et objectifs du magasin', (tester) async {
      await ouvrirSaisie(tester, EtapeDph.bilan);
      expect(find.text('Bilan de visite'), findsWidgets);
      expect(find.text('RÉSUMÉ DES RÉSULTATS'), findsOneWidget);
      void ligne(String cle, String valeur) {
        expect(find.text(cle), findsOneWidget, reason: cle);
        expect(find.text(valeur), findsWidgets, reason: valeur);
      }

      ligne('Distribution numérique', '0 kit vérifié');
      ligne('Concurrence', 'Aucune marque');
      ligne('Promotions', 'Non conformes');
      ligne('Photos', '0');
      ligne('Visite PEM', 'Non réalisée');
      expect(find.text('OBJECTIFS DU MAGASIN'), findsOneWidget);
      // m1 : objectif 5 250 €, réalisé 4 570 € (87 %), une OP en cours
      ligne('CA / objectif du mois', '4 570 € / 5 250 € (87 %)');
      ligne('OP en cours', '1');
      expect(
        find.text('Je valide les objectifs et le bilan de cette visite'),
        findsOneWidget,
      );
      expect(find.text('Commentaire (facultatif)'), findsOneWidget);
      expect(find.text('Ex. objectif atteint grâce à la PEM'), findsOneWidget);
      expect(find.text('✓ Enregistrer le bilan de visite'), findsOneWidget);
    });

    testWidgets('le résumé suit les saisies de la visite', (tester) async {
      final id = await ouvrirSaisie(tester, EtapeDph.bilan);
      conteneurApp(tester)
          .read(crmProvider.notifier)
          .majVisite(
            id,
            (v) => v.copyWith(
              kits: const ['COSMIA-01', '900024'],
              promosConformes: true,
              photos: const {
                EtapeDph.arrivee: 2,
                EtapeDph.rayonArrivee: 3,
                EtapeDph.face: 1,
                EtapeDph.rayonFin: 0,
              },
              pem: const VisitePem(realisee: true),
              concurrence: const Concurrence(
                liste: [
                  MarqueConcurrente(marque: 'A', metrage: 2),
                  MarqueConcurrente(marque: 'B', metrage: 1.5),
                ],
              ),
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('2 kits vérifiés'), findsOneWidget);
      expect(find.text('2 marques · 3,5 m'), findsOneWidget);
      expect(find.text('Conformes'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Réalisée'), findsOneWidget);
    });

    testWidgets('il faut valider les objectifs pour enregistrer', (
      tester,
    ) async {
      final id = await ouvrirSaisie(tester, EtapeDph.bilan);
      await enregistrer(tester, '✓ Enregistrer le bilan de visite');
      expect(
        find.text('Validez les objectifs pour enregistrer le bilan.'),
        findsOneWidget,
      );
      expect(find.byType(SaisieEtapeScreen), findsOneWidget);
      await attendreToast(tester);

      await tester.tap(find.byType(Interrupteur));
      await tester.pumpAndSettle();
      expect(visite(tester, id).bilanValide, isTrue);
      await tester.enterText(find.byType(EditableText), 'objectif atteint');
      await tester.pumpAndSettle();
      expect(visite(tester, id).bilanNote, 'objectif atteint');
      await enregistrer(tester, '✓ Enregistrer le bilan de visite');
      expect(find.text('Bilan de visite enregistré.'), findsOneWidget);
      expect(find.byType(SaisieEtapeScreen), findsNothing);
      expect(visite(tester, id).chrono[EtapeDph.bilan], '04/11/2026 14h27');
    });
  });

  testWidgets(
    'une étape photo ouverte à la main affiche la saisie des promotions',
    (tester) async {
      await ouvrirSaisie(tester, EtapeDph.face);
      expect(
        find.text('Les promotions sont en place et conformes'),
        findsOneWidget,
      );
      expect(find.text('✓ Enregistrer la vérification Promos'), findsOneWidget);
    },
  );

  testWidgets('saisie d’une visite inconnue', (tester) async {
    await lancerApp(tester, Role.promoteur);
    AppRoutes.saisieEtapeVisite(
      contexteCoquille(tester),
      visiteId: 'inconnue',
      etape: EtapeDph.dn,
    );
    await tester.pumpAndSettle();
    expect(find.text('Visite introuvable.'), findsOneWidget);
    expect(find.byType(BarreBasse), findsNothing);
  });
}
