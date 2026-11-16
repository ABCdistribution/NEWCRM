import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Corrections du socle faites à l'intégration : interligne, marges de feuille, halo de l'avatar, sélecteur, chiffres,
/// champs, tuile et soulignement. Les valeurs viennent du CSS de la maquette (`demo-appli.html`).
void main() {
  group('A1 · interligne « normal » de la maquette (1,21)', () {
    test('AppText.t pose 1,21 sauf interligne explicite', () {
      expect(AppText.interligne, 1.21);
      expect(AppText.t(14).height, 1.21);
      expect(AppText.t(23, h: 1.15).height, 1.15);
      expect(AppText.corps.height, 1.21);
    });

    test('les quinze styles du thème ont l’interligne de la maquette', () {
      for (final u in Univers.values) {
        final t = AppTheme.pour(u).textTheme;
        for (final s in [
          t.displayLarge,
          t.displayMedium,
          t.displaySmall,
          t.headlineLarge,
          t.headlineMedium,
          t.headlineSmall,
          t.titleLarge,
          t.titleMedium,
          t.titleSmall,
          t.bodyLarge, // saisie des champs
          t.bodyMedium, // texte courant (DefaultTextStyle)
          t.bodySmall,
          t.labelLarge,
          t.labelMedium,
          t.labelSmall,
        ]) {
          expect(s!.height, 1.21, reason: '${u.name} : $s');
        }
      }
    });

    testWidgets('un texte de 14 px mesure 17 dp, pas 20 (1,43 × 14)', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const Scaffold(
          body: Column(
            children: [
              Text('Abc', key: Key('defaut')),
              Text('Abc', key: Key('t14'), style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
      // Inter 14 px à 1,21 : 16,94 dp, arrondi à la ligne de pixels supérieure par le moteur.
      expect(tester.getSize(find.byKey(const Key('t14'))).height, 17);
      // Inter est bien chargée par `pumpEcran` : « Abc » mesure ~27 dp (Ahem, la police par défaut des tests, 42 dp).
      expect(tester.getSize(find.byKey(const Key('t14'))).width, lessThan(32));
      // 16 px par défaut : 19,36 dp, soit 19 ou 20, très loin des 23 dp de l'interligne 1,43.
      expect(
        tester.getSize(find.byKey(const Key('defaut'))).height,
        lessThanOrEqualTo(20),
      );
    });
  });

  group('A2 · marge basse du titre de feuille fusionnée avec la marge haute', () {
    Future<double> ecartTitreEtPremier(
      WidgetTester tester,
      Widget premier,
      Finder titre,
      Finder suite,
    ) async {
      await pumpEcran(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FeuilleBase(titre: 'Filtres', children: [premier]),
          ),
        ),
      );
      return tester.getTopLeft(suite).dy - tester.getBottomLeft(titre).dy;
    }

    testWidgets('titre suivi d’un TitreFiltre : 14 dp, pas 24', (tester) async {
      final ecart = await ecartTitreEtPremier(
        tester,
        const TitreFiltre('Afficher'),
        find.text('Filtres'),
        find.text('AFFICHER'),
      );
      // Entre le bas du titre et le haut du texte de l'intertitre : les 14 dp de `.titre-filtre`
      // (le texte de l'intertitre n'a pas de marge interne en plus).
      expect(ecart, 14);
    });

    testWidgets('titre suivi d’une SectionTitre : 14 dp', (tester) async {
      final ecart = await ecartTitreEtPremier(
        tester,
        const SectionTitre('Identité'),
        find.text('Filtres'),
        find.text('IDENTITÉ'),
      );
      expect(ecart, 14);
    });

    testWidgets(
      'titre suivi d’un autre élément : 10 dp (`h3{margin:0 0 10px}`)',
      (tester) async {
        final ecart = await ecartTitreEtPremier(
          tester,
          const Text('Contenu', key: Key('premier')),
          find.text('Filtres'),
          find.text('Contenu'),
        );
        expect(ecart, 10);
      },
    );

    testWidgets('une SectionTitre à marge haute réglée la fusionne aussi', (
      tester,
    ) async {
      final ecart = await ecartTitreEtPremier(
        tester,
        const SectionTitre('Identité', margeHaut: 4),
        find.text('Filtres'),
        find.text('IDENTITÉ'),
      );
      // 10 dp de titre, dont 4 sont déjà fournis par la marge haute de l'intertitre : 6 + 4.
      expect(ecart, 10);
    });
  });

  group('A3 · avatar teinté', () {
    testWidgets('garde le halo de l’univers quand `fond` est fourni', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const Scaffold(
          body: Column(
            children: [
              Avatar('JM', key: Key('blanc')),
              Avatar(
                'LP',
                key: Key('teinte'),
                fond: Color(0xFFDFE8FF),
                texte: Color(0xFF1E3A8A),
              ),
            ],
          ),
        ),
      );
      BoxDecoration deco(String cle) =>
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(Key(cle)),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      final blanc = deco('blanc');
      final teinte = deco('teinte');
      expect(teinte.color, const Color(0xFFDFE8FF));
      expect(teinte.boxShadow, isNotEmpty);
      expect(teinte.boxShadow, blanc.boxShadow);
    });
  });

  group('A4 · sélecteur', () {
    testWidgets('un libellé long passe à la ligne au lieu d’être tronqué', (
      tester,
    ) async {
      const long =
          'Visites du secteur · Léa P. · Carrefour Market – Versailles · Commandes appli';
      await pumpEcran(
        tester,
        Scaffold(
          body: Column(
            children: [
              Selecteur('Court', onTap: () {}, key: const Key('court')),
              Selecteur(long, onTap: () {}, key: const Key('long')),
            ],
          ),
        ),
      );
      final texte = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('long')),
          matching: find.text(long),
        ),
      );
      expect(texte.maxLines, isNull);
      expect(texte.overflow, isNull);
      expect(
        tester.getSize(find.byKey(const Key('long'))).height,
        greaterThan(tester.getSize(find.byKey(const Key('court'))).height),
      );
    });
  });

  group('A5 · chiffres', () {
    testWidgets('gap de 14 dp entre éléments et entre rangées', (tester) async {
      await pumpEcran(
        tester,
        Scaffold(
          body: Chiffres([
            for (var i = 0; i < 4; i++)
              Chiffre('${i + 10} %', 'du prévu à ce jour'),
          ]),
        ),
      );
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 14);
      expect(wrap.runSpacing, 14);
    });

    testWidgets('un élément sans partie en gras n’a pas d’espace initial', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const Scaffold(
          body: Chiffres([
            Chiffre('', '+1 ajoutée · 1 retirée'),
            Chiffre('60 %', 'du prévu'),
          ]),
        ),
      );
      expect(find.text('+1 ajoutée · 1 retirée'), findsOneWidget);
      expect(find.text('60 % du prévu', findRichText: true), findsOneWidget);
    });
  });

  group('A6 · champs', () {
    testWidgets('une zone de texte fait 72 dp (`textarea{min-height:72px}`)', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                ChampTexte(label: 'Observations', lignes: 3, margeBas: 0),
                ChampTexte(
                  label: 'Sur mesure',
                  lignes: 3,
                  hauteur: 100,
                  margeBas: 0,
                ),
              ],
            ),
          ),
        ),
      );
      final zones = find.byType(TextFormField);
      expect(tester.getSize(zones.at(0)).height, 72);
      expect(tester.getSize(zones.at(1)).height, 100);
      // Le texte saisi défile dans la zone : la hauteur ne change pas.
      await tester.enterText(zones.at(0), 'ligne\n' * 12);
      await tester.pump();
      expect(tester.getSize(zones.at(0)).height, 72);
    });

    testWidgets('un champ d’une ligne garde sa hauteur', (tester) async {
      await pumpEcran(
        tester,
        const Scaffold(body: ChampTexte(label: 'Adresse', margeBas: 0)),
      );
      // 12 + 17 + 12 de contenu : le champ ne grandit pas.
      expect(tester.getSize(find.byType(TextFormField)).height, 41);
    });

    testWidgets('la liste déroulante laisse plus de place au libellé', (
      tester,
    ) async {
      const long = 'Carrefour Market – Versailles · 104 avenue des Champs';
      await pumpEcran(
        tester,
        Scaffold(
          body: ChampListe<String>(
            label: 'Client',
            valeur: 'a',
            options: const {'a': long},
            onChanged: (_) {},
          ),
        ),
      );
      final liste = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      // La flèche mesure 16 dp : le bouton ne réserve plus les 24 dp par défaut.
      expect(liste.iconSize, 16);
      expect(find.text(long), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('A7 · tuile et soulignement', () {
    testWidgets('la valeur d’une tuile « nowrap » ne passe pas à la ligne', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        const Scaffold(
          body: SizedBox(
            width: 140,
            child: Tuile(
              libelle: 'CA / objectif du mois',
              valeur: '4 900 €',
              complement: '/ 12 000 €',
              tailleValeur: 19,
              nowrap: true,
            ),
          ),
        ),
      );
      final riche = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.textSpan?.toPlainText().startsWith('4 900') == true,
        ),
      );
      expect(riche.softWrap, isFalse);
    });

    testWidgets('sans nowrap la valeur peut passer à la ligne', (tester) async {
      await pumpEcran(
        tester,
        const Scaffold(
          body: Tuile(libelle: 'Visites', valeur: '3', complement: '/ 9'),
        ),
      );
      final riche = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText().startsWith('3') == true,
        ),
      );
      expect(riche.softWrap, isTrue);
    });

    testWidgets('TexteSouligne : filet de 1,5 dp décalé sous la ligne', (
      tester,
    ) async {
      await pumpEcran(
        tester,
        Scaffold(
          body: TexteSouligne(
            'Suivi des livraisons',
            key: const Key('lien'),
            style: AppText.t(
              14.5,
              w: FontWeight.w700,
              c: const Color(0xFF1F7AEA),
            ),
          ),
        ),
      );
      final boite = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('lien')),
          matching: find.byType(Container),
        ),
      );
      final deco = boite.decoration! as BoxDecoration;
      final bordure = (deco.border! as Border).bottom;
      expect(bordure.width, 1.5);
      expect(bordure.color, const Color(0xFF1F7AEA));
      // 4 dp sous la ligne de base, dont 14,5 × 494 / 2048 ≈ 3,5 dp de descente de la police.
      expect(
        (boite.padding! as EdgeInsets).bottom,
        closeTo(4 - 14.5 * 494 / 2048, 0.001),
      );
    });
  });
}
