import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/equipe/semaine_cs_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Une semaine du rapport d'un chef de secteur (maquette : `pageSemaineCS` l.817-835, `compareSemaine` l.788-797).
Future<void> _ouvrir(WidgetTester tester, String csId, int semaine) =>
    pumpEcran(
      tester,
      SemaineCsScreen(csId: csId, numSemaine: semaine),
      role: Role.dir,
    );

Future<void> _basculerPrevision(WidgetTester tester, String libelle) async {
  await tester.ensureVisible(find.text(libelle));
  await tester.pumpAndSettle();
  await tester.tap(find.text(libelle));
  await tester.pumpAndSettle();
}

void main() {
  group('semaine en cours (45)', () {
    testWidgets('prévu, réalisé à ce jour et écarts', (tester) async {
      await _ouvrir(tester, 'n', 45);
      expect(find.text('Semaine 45 · en cours'), findsOneWidget);
      expect(find.text('Nadia H. · 2 – 6 novembre'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text("RAPPORT D'ACTIVITÉ"), findsOneWidget);
      expect(find.text('Prévu 5 · Réalisé 3 (60 %)'), findsOneWidget);
      expect(find.text('ÉCARTS AVEC LA PRÉVISION'), findsOneWidget);
      // Retiré d'abord, puis ajouté (ordre de `ecartsListe`).
      expect(find.text('Carrefour Market – Rouen'), findsOneWidget);
      expect(
        find.text('Retiré du planning, non réalisé · prévu jeu. 14:00'),
        findsOneWidget,
      );
      expect(find.text('Auchan – Rouen'), findsOneWidget);
      expect(
        find.text('Ajouté (non prévu) · visite non prévue'),
        findsOneWidget,
      );
      final retire = tester.getTopLeft(find.text('Carrefour Market – Rouen'));
      final ajoute = tester.getTopLeft(find.text('Auchan – Rouen'));
      expect(retire.dy, lessThan(ajoute.dy));
      // Semaine en cours : pas encore validée.
      expect(find.textContaining('Validé automatiquement'), findsNothing);
      expect(find.text('Lecture seule.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la prévision enregistrée se déplie et se replie', (
      tester,
    ) async {
      await _ouvrir(tester, 'n', 45);
      expect(find.text('▼ Voir la prévision'), findsOneWidget);
      expect(find.text('PRÉVISION ENREGISTRÉE'), findsNothing);
      await _basculerPrevision(tester, '▼ Voir la prévision');
      expect(find.text('▲ Masquer la prévision'), findsOneWidget);
      expect(find.text('PRÉVISION ENREGISTRÉE'), findsOneWidget);
      // Le jour dans le rond, le titre, puis « jour heure ».
      expect(find.text('Mar'), findsNWidgets(2));
      expect(find.text('Mar 09:00'), findsOneWidget);
      expect(find.text('Mer 10:00'), findsOneWidget);
      expect(find.text('Jeu 14:00'), findsOneWidget);
      expect(find.text('Ven 09:30'), findsOneWidget);
      expect(find.text('Super U – Versailles'), findsOneWidget);
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsOneWidget);
      await _basculerPrevision(tester, '▲ Masquer la prévision');
      expect(find.text('PRÉVISION ENREGISTRÉE'), findsNothing);
      expect(find.text('▼ Voir la prévision'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Karim B. : aucun écart', (tester) async {
      await _ouvrir(tester, 'k', 45);
      expect(find.text('Karim B. · 2 – 6 novembre'), findsOneWidget);
      expect(find.text('Prévu 4 · Réalisé 3 (75 %)'), findsOneWidget);
      expect(
        find.text("Aucun écart : tout s'est passé comme prévu."),
        findsOneWidget,
      );
    });

    testWidgets('Sophie L. : prévision non renseignée', (tester) async {
      await _ouvrir(tester, 's', 45);
      expect(
        find.text(
          'Prévision non renseignée cette semaine : pas de comparaison possible.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Prévu'), findsNothing);
      await _basculerPrevision(tester, '▼ Voir la prévision');
      expect(find.text('Aucune prévision enregistrée.'), findsOneWidget);
    });
  });

  group('semaines validées automatiquement', () {
    testWidgets('semaine 44 de Nadia H. : le réalisé ligne à ligne', (
      tester,
    ) async {
      await _ouvrir(tester, 'n', 44);
      expect(find.text('Semaine 44'), findsOneWidget);
      expect(find.text('Nadia H. · 26 – 30 octobre'), findsOneWidget);
      expect(find.text('Validé auto'), findsOneWidget);
      expect(find.text('Prévu 6 · Réalisé 5 (83 %)'), findsOneWidget);
      expect(find.text("CE QUI S'EST RÉELLEMENT PASSÉ"), findsOneWidget);
      expect(find.text('Comme prévu · Lun 09:30'), findsOneWidget);
      expect(find.text('Comme prévu · Ven 10:00'), findsOneWidget);
      expect(
        find.text('Déplacé · prévu Mar 14:30 → réalisé Mer 15:00'),
        findsOneWidget,
      );
      expect(find.text('Non prévu · Jeu 14:00'), findsOneWidget);
      expect(find.text('PRÉVU MAIS NON RÉALISÉ'), findsOneWidget);
      expect(find.text('Monoprix – Caen'), findsOneWidget);
      expect(find.text('Prévu, non réalisé · Mer 11:00'), findsOneWidget);
      expect(
        find.text('Validé automatiquement le lun. 2 nov. à 04:00'),
        findsOneWidget,
      );
      // Les écarts résumés ne sont pas listés : la comparaison les remplace.
      expect(find.text('ÉCARTS AVEC LA PRÉVISION'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semaine 44 de Nadia H. : la prévision enregistrée', (
      tester,
    ) async {
      await _ouvrir(tester, 'n', 44);
      await _basculerPrevision(tester, '▼ Voir la prévision');
      expect(find.text('PRÉVISION ENREGISTRÉE'), findsOneWidget);
      expect(find.text('Lun 09:30'), findsOneWidget);
      expect(find.text('Mar 14:30'), findsOneWidget);
      expect(find.text('Mer 11:00'), findsOneWidget);
      expect(find.text('Jeu 09:00'), findsOneWidget);
    });

    testWidgets('semaine 44 de Karim B. : tout comme prévu', (tester) async {
      await _ouvrir(tester, 'k', 44);
      expect(find.text('Prévu 12 · Réalisé 12 (100 %)'), findsOneWidget);
      expect(
        find.text("Aucun écart : tout s'est passé comme prévu."),
        findsOneWidget,
      );
      expect(
        find.text('Validé automatiquement le lun. 2 nov. à 04:00'),
        findsOneWidget,
      );
    });

    testWidgets('semaine 41 : deux prévus non réalisés', (tester) async {
      await _ouvrir(tester, 'n', 41);
      expect(find.text('Nadia H. · 5 – 9 octobre'), findsOneWidget);
      expect(find.text('Prévu 13 · Réalisé 11 (85 %)'), findsOneWidget);
      expect(find.text('Carrefour – Versailles'), findsOneWidget);
      expect(find.text('Super U – Versailles'), findsOneWidget);
      expect(
        find.text('Retiré du planning, non réalisé · prévu vendredi'),
        findsNWidgets(2),
      );
      expect(
        find.text('Validé automatiquement le lun. 12 oct. à 04:00'),
        findsOneWidget,
      );
    });

    testWidgets('semaine 42 de Nadia H. : aucun écart', (tester) async {
      await _ouvrir(tester, 'n', 42);
      expect(find.text('Prévu 15 · Réalisé 15 (100 %)'), findsOneWidget);
      expect(
        find.text("Aucun écart : tout s'est passé comme prévu."),
        findsOneWidget,
      );
    });

    testWidgets('semaine 39 : prévision non renseignée', (tester) async {
      await _ouvrir(tester, 'n', 39);
      expect(find.text('Semaine 39'), findsOneWidget);
      expect(find.text('Nadia H. · 21 – 25 septembre'), findsOneWidget);
      expect(
        find.text(
          'Prévision non renseignée cette semaine : pas de comparaison possible.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Validé automatiquement le lun. 28 sept. à 04:00'),
        findsOneWidget,
      );
    });

    testWidgets('les semaines de Sophie L. sont toutes sans comparaison', (
      tester,
    ) async {
      await _ouvrir(tester, 's', 43);
      expect(
        find.text(
          'Prévision non renseignée cette semaine : pas de comparaison possible.',
        ),
        findsOneWidget,
      );
      expect(find.text('Prévu 14 · Réalisé 13 (93 %)'), findsNothing);
    });
  });

  testWidgets('le bouton retour ferme l’écran', (tester) async {
    await _ouvrir(tester, 'n', 45);
    expect(find.byType(BoutonRetour), findsOneWidget);
  });
}
