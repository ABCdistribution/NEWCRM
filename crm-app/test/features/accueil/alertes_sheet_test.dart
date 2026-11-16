import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/accueil/accueil_screen.dart';
import 'package:crm_app/features/accueil/alertes_sheet.dart';
import 'package:crm_app/features/clients/fiche_magasin_screen.dart';
import 'package:crm_app/features/prospects/fiche_prospect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_accueil.dart';

/// Feuille des alertes (la cloche) : maquette modale `cloche` l.1908-1913, `alertes()` l.642-654,
/// `alertesProspects()` l.629-641, actions `alerte-ouvrir` (l.1981) et `fiche-prospect` (l.1989).
void main() {
  Future<void> monterFeuille(
    WidgetTester tester,
    Role role, {
    List<Alerte>? alertes,
  }) => pumpEcran(
    tester,
    const Scaffold(body: AlertesSheet()),
    role: role,
    overrides: [
      if (alertes != null) alertesProvider.overrideWithValue(alertes),
    ],
  );

  final feuille = find.byType(AlertesSheet);

  /// Texte du titre de la feuille : « Alertes » ou « Alertes clients », suivi de la pastille du nombre.
  String titre(WidgetTester tester) {
    final t = tester
        .widgetList<Text>(
          find.descendant(of: feuille, matching: find.byType(Text)),
        )
        .map((t) => t.textSpan?.toPlainText() ?? '')
        .firstWhere((s) => s.startsWith('Alertes'));
    return t.replaceAll('￼', '').trim();
  }

  /// Pastille du nombre d'alertes (le seul texte numérique de la feuille).
  Finder compteur(String n) =>
      find.descendant(of: feuille, matching: find.text(n));

  /// Fonds de carte d'alerte, dans l'ordre d'affichage.
  List<FondAlerte> fonds(WidgetTester tester) => [
    for (final c in tester.widgetList<CustomPaint>(
      find.descendant(of: feuille, matching: find.byType(CustomPaint)),
    ))
      if (c.painter is FondAlerte) c.painter! as FondAlerte,
  ];

  double hauteurDe(WidgetTester tester, String texte) => tester
      .getTopLeft(find.descendant(of: feuille, matching: find.text(texte)))
      .dy;

  group('promoteur', () {
    testWidgets('« Alertes clients » : trois alertes sur son portefeuille', (
      tester,
    ) async {
      await monterFeuille(tester, Role.promoteur);
      expect(titre(tester), 'Alertes clients');
      expect(compteur('3'), findsOneWidget);

      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(find.text('Classe A++'), findsOneWidget);
      expect(
        find.text(
          'Pas visité depuis 15 jours · visite attendue tous les 7 jours',
        ),
        findsOneWidget,
      );
      expect(find.text('U Express – Boulogne-Billancourt'), findsOneWidget);
      expect(find.text('Classe B'), findsOneWidget);
      expect(
        find.text(
          'Pas visité depuis 25 jours · visite attendue tous les 21 jours',
        ),
        findsOneWidget,
      );
      expect(find.text('U Express – Paris'), findsOneWidget);
      expect(find.text('Classe E'), findsOneWidget);
      expect(
        find.text('Client inactif · dernière commande en septembre'),
        findsOneWidget,
      );
      expect(find.text('📍'), findsNWidgets(2));
      expect(find.text('💤'), findsOneWidget);
      expect(find.text('›'), findsNWidgets(3));
      // Aucune alerte prospect pour le promoteur.
      expect(find.textContaining('Prospect ·'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('les plus urgentes d’abord, rouges si le seuil est ≤ 10 jours', (
      tester,
    ) async {
      await monterFeuille(tester, Role.promoteur);
      expect(
        hauteurDe(tester, 'Carrefour Market – Versailles'),
        lessThan(hauteurDe(tester, 'U Express – Boulogne-Billancourt')),
      );
      expect(
        hauteurDe(tester, 'U Express – Boulogne-Billancourt'),
        lessThan(hauteurDe(tester, 'U Express – Paris')),
      );
      final f = fonds(tester);
      expect(f, hasLength(3));
      // Classe A++ (7 jours) : niveau haut, fond rouge pâle et liseré rouge.
      expect(f[0].fond, const Color(0xFFFEF2F2));
      expect(f[0].lisere, const Color(0xFFDC2626));
      // Classe B (21 jours) et client inactif : niveau moyen, fond bleuté et liseré orange.
      for (final moy in f.skip(1)) {
        expect(moy.fond, const Color(0xFFF8FAFF));
        expect(moy.lisere, const Color(0xFFF59E0B));
      }
    });

    testWidgets('pied sur la fréquence de visite attendue', (tester) async {
      await monterFeuille(tester, Role.promoteur);
      expect(
        find.text(
          'La fréquence de visite attendue dépend de la classification du client '
          '(A++ : tous les 7 jours, B : 21 jours, D : 35 jours…).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('la feuille suit le store : une visite retire l’alerte', (
      tester,
    ) async {
      await monterFeuille(tester, Role.promoteur);
      storeMonte(tester).demarrerVisite('m1');
      await tester.pumpAndSettle();
      expect(compteur('2'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsNothing);
      expect(find.text('U Express – Boulogne-Billancourt'), findsOneWidget);
    });
  });

  group('chef de secteur', () {
    testWidgets('« Alertes » : clients et prospects, 7 alertes', (
      tester,
    ) async {
      await monterFeuille(tester, Role.cs);
      expect(titre(tester), 'Alertes');
      expect(compteur('7'), findsOneWidget);
      // Ordre de la maquette : m1, p2, m8, p5, p9, p19, m5.
      final ordre = [
        'Carrefour Market – Versailles',
        'Carrefour – Paris',
        'U Express – Boulogne-Billancourt',
        'Carrefour HM – Mont-Saint-Aignan',
        'Carrefour HM – Cergy',
        'Carrefour HM – Évreux',
        'U Express – Paris',
      ];
      for (var i = 1; i < ordre.length; i++) {
        expect(
          hauteurDe(tester, ordre[i - 1]),
          lessThan(hauteurDe(tester, ordre[i])),
          reason: '${ordre[i - 1]} avant ${ordre[i]}',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('alertes prospects : RDV du jour, relance, à contacter', (
      tester,
    ) async {
      await monterFeuille(tester, Role.cs);
      expect(find.text('Prospect · Classe B'), findsNWidgets(3));
      expect(find.text('Prospect · Classe A'), findsOneWidget);
      expect(
        find.text('RDV prospect aujourd’hui à 11:30 · À contacter'),
        findsOneWidget,
      );
      expect(find.text('📅'), findsOneWidget);
      expect(
        find.text(
          'Prospect en négo sans action prévue depuis 6 jours · à relancer (120 k€/an)',
        ),
        findsOneWidget,
      );
      expect(find.text('💬'), findsOneWidget);
      expect(
        find.text('Contacté il y a 5 jours, pas de RDV obtenu · à contacter'),
        findsNWidgets(2),
      );
      expect(find.text('🎯'), findsNWidgets(2));
      // RDV du jour et relance sont hauts, « à contacter » est moyen.
      final f = fonds(tester);
      expect(f.map((x) => x.fond == const Color(0xFFFEF2F2)), [
        true, // m1
        true, // p2 RDV aujourd'hui
        false, // m8
        true, // p5 relance
        false, // p9
        false, // p19
        false, // m5
      ]);
    });

    testWidgets('le RDV du jour d’un prospect suit le jour du planning', (
      tester,
    ) async {
      await monterFeuille(tester, Role.cs);
      conteneurMonte(tester).read(jourPlanningProvider.notifier).choisir(3);
      await tester.pumpAndSettle();
      // Jeudi : le RDV de Carrefour – Paris n'est plus d'actualité, celui de Super U – Versailles l'est.
      expect(find.text('Carrefour – Paris'), findsNothing);
      expect(
        find.text('RDV prospect aujourd’hui à 10:00 · En négo'),
        findsOneWidget,
      );
    });
  });

  group('directeur', () {
    testWidgets(
      '« Alertes clients » : quatre alertes dont la livraison du jour',
      (tester) async {
        await monterFeuille(tester, Role.dir);
        expect(titre(tester), 'Alertes clients');
        expect(compteur('4'), findsOneWidget);
        expect(find.text('Monoprix – Caen'), findsOneWidget);
        expect(find.text('Classe C'), findsOneWidget);
        expect(
          find.text(
            "Commande CDE-2033 : livraison prévue aujourd'hui, pas encore livrée",
          ),
          findsOneWidget,
        );
        expect(find.text('🚚'), findsOneWidget);
        // Le directeur n'a pas d'alerte prospect.
        expect(find.textContaining('Prospect ·'), findsNothing);
      },
    );
  });

  group('aucune alerte', () {
    testWidgets('message « tout est à jour » et pastille à 0', (tester) async {
      await monterFeuille(tester, Role.promoteur, alertes: const []);
      expect(titre(tester), 'Alertes clients');
      expect(compteur('0'), findsOneWidget);
      expect(find.text('Aucune alerte : tout est à jour.'), findsOneWidget);
      expect(find.byType(Vide), findsOneWidget);
      expect(fonds(tester), isEmpty);
      // Le pied reste affiché.
      expect(
        find.textContaining('La fréquence de visite attendue'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('depuis la cloche de l’accueil', () {
    testWidgets('la cloche ouvre la feuille, le voile la ferme', (
      tester,
    ) async {
      await pumpEcran(tester, const AccueilScreen(), role: Role.promoteur);
      expect(feuille, findsNothing);
      await tester.tap(find.byType(Cloche));
      await tester.pumpAndSettle();
      expect(feuille, findsOneWidget);
      expect(titre(tester), 'Alertes clients');
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(feuille, findsNothing);
    });

    testWidgets('une alerte client ferme la feuille et ouvre la fiche', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await tester.tap(find.byType(Cloche));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: feuille,
          matching: find.text('U Express – Boulogne-Billancourt'),
        ),
      );
      await tester.pumpAndSettle();
      expect(feuille, findsNothing);
      expect(routeCourante(tester), 'magasin');
      expect(
        tester
            .widget<FicheMagasinScreen>(find.byType(FicheMagasinScreen))
            .magasinId,
        'm8',
      );
    });

    testWidgets('une alerte prospect ouvre la fiche du prospect', (
      tester,
    ) async {
      await lancerApp(tester, Role.cs);
      await tester.tap(find.byType(Cloche));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: feuille,
          matching: find.text('Carrefour HM – Mont-Saint-Aignan'),
        ),
      );
      await tester.pumpAndSettle();
      expect(feuille, findsNothing);
      expect(routeCourante(tester), 'prospect');
      expect(
        tester
            .widget<FicheProspectScreen>(find.byType(FicheProspectScreen))
            .prospectId,
        'p5',
      );
    });

    testWidgets('l’alerte d’une livraison du jour ouvre la fiche du client', (
      tester,
    ) async {
      await lancerApp(tester, Role.dir);
      await tester.tap(find.byType(Cloche));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: feuille, matching: find.text('Monoprix – Caen')),
      );
      await tester.pumpAndSettle();
      expect(routeCourante(tester), 'magasin');
      expect(
        tester
            .widget<FicheMagasinScreen>(find.byType(FicheMagasinScreen))
            .magasinId,
        'm7',
      );
    });
  });
}
