import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/clients/fiche_magasin_screen.dart';
import 'package:crm_app/features/visites/compte_rendu_screen.dart';
import 'package:crm_app/features/visites/kit_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_visites.dart';

Future<void> ouvrirCompteRendu(
  WidgetTester tester,
  Role role,
  String visiteId,
) async {
  await lancerApp(tester, role);
  AppRoutes.compteRendu(contexteCoquille(tester), visiteId);
  await tester.pumpAndSettle();
}

void main() {
  group('Compte rendu (compteRendu l.1313-1333)', () {
    testWidgets('visite du promoteur terminée : toutes les rubriques', (
      tester,
    ) async {
      await ouvrirCompteRendu(tester, Role.promoteur, 'd0');
      expect(find.byType(CompteRenduScreen), findsOneWidget);
      expect(find.text('Visite #218082'), findsOneWidget);
      expect(find.text('réalisée par Julien M.'), findsOneWidget);
      expect(find.text('Envoyée'), findsOneWidget);
      expect(find.text('COMPTE RENDU DE LA VISITE'), findsOneWidget);
      expect(find.text('Visite DPH'), findsOneWidget);
      expect(find.text('Visite PEM'), findsOneWidget);

      expect(find.text('LE CLIENT'), findsOneWidget);
      expect(find.text('Enseigne'), findsOneWidget);
      expect(find.text('CARREFOUR IVRY-SUR-SEINE'), findsOneWidget);
      expect(find.text('Fiche client'), findsOneWidget);
      expect(find.text('Cliquez ici'), findsOneWidget);
      expect(find.text('Adresse'), findsOneWidget);
      expect(find.text('94200 IVRY-SUR-SEINE (FR)'), findsOneWidget);

      expect(find.text('LA VISITE'), findsOneWidget);
      expect(find.text('Réception visite'), findsOneWidget);
      expect(find.text('04/11/2026 11h36'), findsWidgets);
      expect(find.text('Réalisée par'), findsOneWidget);
      expect(find.text('Julien M.'), findsOneWidget);

      expect(find.text('COMMANDE LIÉE À LA VISITE DPH'), findsOneWidget);
      expect(find.text('Commande'), findsOneWidget);
      expect(find.text('#2018 : 2 340,00 € - 22/10/2026'), findsOneWidget);

      // la visite PEM est réalisée : pas de rubrique « Visite PEM »
      expect(find.text('VISITE PEM'), findsNothing);

      expect(find.text('DISTRIBUTION NUMÉRIQUE PAR KIT'), findsOneWidget);
      expect(find.text('COSMIA ZIPPED PLANE KIT ›'), findsOneWidget);
      expect(find.text('Kit racines brun ›'), findsOneWidget);
      expect(find.text('✓'), findsNWidgets(2 + 9));

      expect(find.text('CONCURRENCE'), findsOneWidget);
      expect(find.text('Marque concurrente A'), findsOneWidget);
      expect(find.text('2 m'), findsOneWidget);
      expect(find.text('Marque concurrente B'), findsOneWidget);
      expect(find.text('1,5 m'), findsOneWidget);

      expect(find.text('TIMING DE VISITE'), findsOneWidget);
      // début 9h30, puis +57, +104, +104, +120, +122, +122, +126, +128 minutes
      for (final h in [
        '04/11/2026 09h30',
        '04/11/2026 10h27',
        '04/11/2026 11h14',
        '04/11/2026 11h30',
        '04/11/2026 11h32',
        '04/11/2026 11h38',
      ]) {
        expect(find.text(h), findsWidgets, reason: h);
      }
      for (final e in EtapeDph.values) {
        expect(find.text(e.libelle), findsWidgets, reason: e.libelle);
      }
      expect(
        find.text("Visite validée : elle n'est plus modifiable."),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('visite sans visite PEM : la raison est donnée', (
      tester,
    ) async {
      // d00 (E.Leclerc – Paris) n'appartient qu'au chef de secteur et au directeur
      await ouvrirCompteRendu(tester, Role.dir, 'd00');
      expect(find.text('Visite #218081'), findsOneWidget);
      expect(find.text('réalisée par Cindy R.'), findsOneWidget);
      expect(find.text('Visite PEM · non réalisée'), findsOneWidget);
      expect(find.text('VISITE PEM'), findsOneWidget);
      expect(find.text('Pas de visite PEM car'), findsOneWidget);
      expect(find.text('Pas de rayon PEM'), findsOneWidget);
      expect(find.text('E.LECLERC PARIS'), findsOneWidget);
      expect(find.text('75011 PARIS (FR)'), findsOneWidget);
      // pas de commande liée
      expect(find.text('Aucune commande liée'), findsOneWidget);
      expect(find.text('Commande'), findsNothing);
    });

    testWidgets('visite d’un autre promoteur : lecture seule', (tester) async {
      await ouvrirCompteRendu(tester, Role.promoteur, 'x3');
      expect(find.text('Visite #218086'), findsOneWidget);
      expect(find.text('réalisée par Amine K.'), findsOneWidget);
      expect(find.text('Visite PEM · non réalisée'), findsOneWidget);
      expect(find.text('Rayon fermé ou en travaux'), findsOneWidget);
      expect(find.text('CARREFOUR MARKET VERSAILLES'), findsOneWidget);
      expect(
        find.text("Lecture seule : cette visite n'est pas la vôtre."),
        findsOneWidget,
      );
    });

    testWidgets('visite à envoyer : badge bleu', (tester) async {
      await ouvrirCompteRendu(tester, Role.dir, 'x7');
      expect(find.text('Visite #218090'), findsOneWidget);
      expect(find.text('À envoyer'), findsOneWidget);
      final badge = tester.widget<BadgeEtat>(find.byType(BadgeEtat));
      expect(badge.couleur, const Color(0xFF2563EB));
    });

    testWidgets('sans kit ni marque : rubriques vides', (tester) async {
      await lancerApp(tester, Role.promoteur);
      conteneurApp(tester)
          .read(crmProvider.notifier)
          .majVisite(
            'd0',
            (v) => v.copyWith(
              kits: const [],
              concurrence: const Concurrence(aucune: true),
            ),
          );
      AppRoutes.compteRendu(contexteCoquille(tester), 'd0');
      await tester.pumpAndSettle();
      expect(find.text('DISTRIBUTION NUMÉRIQUE PAR KIT'), findsNothing);
      expect(find.text('Aucune marque concurrente en rayon'), findsOneWidget);
      expect(find.text('Marque concurrente A'), findsNothing);
    });

    testWidgets(
      '« Cliquez ici » ouvre la fiche client, un kit sa composition',
      (tester) async {
        await ouvrirCompteRendu(tester, Role.promoteur, 'd0');
        await toucher(tester, find.text('Kit racines brun ›'));
        await tester.pumpAndSettle();
        expect(find.byType(KitDetailSheet), findsOneWidget);
        expect(
          find.text('Réf. 900024 · 4 produits dans le kit'),
          findsOneWidget,
        );
        await tester.tap(find.text('Fermer'));
        await tester.pumpAndSettle();

        await toucher(tester, find.text('Cliquez ici'));
        await tester.pumpAndSettle();
        final fiche = tester.widget<FicheMagasinScreen>(
          find.byType(FicheMagasinScreen),
        );
        expect(fiche.magasinId, 'm4');
      },
    );

    testWidgets('le retour revient à la liste', (tester) async {
      await ouvrirCompteRendu(tester, Role.cs, 'x0');
      expect(find.text('Visite #218083'), findsOneWidget);
      await tester.tap(find.byType(BoutonRetour));
      await tester.pumpAndSettle();
      expect(find.byType(CompteRenduScreen), findsNothing);
    });
  });
}
