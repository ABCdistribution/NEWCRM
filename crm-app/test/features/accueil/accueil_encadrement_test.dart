import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/accueil/accueil_screen.dart';
import 'package:crm_app/features/accueil/widgets/carte_etape_accueil.dart';
import 'package:crm_app/features/clients/fiche_magasin_screen.dart';
import 'package:crm_app/features/prospects/fiche_prospect_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../../support/lanceur_factice.dart';
import 'aide_accueil.dart';

/// Accueil du chef de secteur « Nadia H. » et du directeur « Cindy R. » : maquette `pageAccueil` l.671-687,
/// `blocProspectsCS` l.665-670, `prochaineAction` l.716-719, actions `onglet`, `ouvrir-etape`, `itineraire`,
/// `fiche-prospect` (l.1980, 1989, 2002, 2022).
///
/// Jour affiché : mercredi (2). Planning de Nadia ce jour-là : 11:30 Carrefour – Paris (prospect p2, RDV) et
/// 16:00 Administratif ; celui de Cindy y ajoute 09:00 Carrefour – Rouen (client m3).
void main() {
  Future<void> monter(
    WidgetTester tester,
    Role role, {
    LanceurExterne? lanceur,
  }) => pumpEcran(
    tester,
    const AccueilScreen(),
    role: role,
    overrides: [
      if (lanceur != null) lanceurExterneProvider.overrideWithValue(lanceur),
    ],
  );

  /// Cartes d'étape affichées, avec leur titre et leur état « prochain ».
  Map<String, bool> etapes(WidgetTester tester) => {
    for (final c in tester.widgetList<CarteEtapeAccueil>(
      find.byType(CarteEtapeAccueil),
    ))
      c.etape.titre: c.prochain,
  };

  group('chef de secteur', () {
    testWidgets('entête : Bonjour Nadia, rôle avec ★ et date', (tester) async {
      await monter(tester, Role.cs);
      expect(find.text('Bonjour Nadia'), findsOneWidget);
      expect(find.textContaining('Chef de secteur'), findsOneWidget);
      expect(find.textContaining('· mer. 4 nov.'), findsOneWidget);
      expect(find.text('★'), findsOneWidget);
      expect(find.text('★★'), findsNothing);
      expect(find.text('NH'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tuiles : RDV du jour, Prospects, CA / objectif du mois', (
      tester,
    ) async {
      await monter(tester, Role.cs);
      expect(find.text('RDV du jour'), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);
      expect(find.widgetWithText(Tuile, 'Prospects'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(Tuile, 'Prospects'),
          matching: find.text('12'),
        ),
        findsOneWidget,
      );
      expect(find.text('CA / objectif du mois'), findsOneWidget);
      // Julien 4 200 + Léa 3 100 + Amine 5 800 sur 4 900 + 4 350 + 5 700.
      expect(find.text('13 100 € / 14 950 €'), findsOneWidget);
      final barre = tester.widget<BarreObjectif>(find.byType(BarreObjectif));
      expect([barre.real, barre.cible], [13100, 14950]);
    });

    testWidgets('« Prospects à suivre » : trois prospects, négo d’abord', (
      tester,
    ) async {
      await monter(tester, Role.cs);
      expect(find.text('Prospects à suivre'), findsOneWidget);
      expect(find.text('Voir tous'), findsOneWidget);
      // En négociation, par potentiel × probabilité : 180 × 60, 160 × 60, 130 × 55.
      final noms = [
        'Super U – Versailles',
        'E.Leclerc – Mantes-la-Jolie',
        'Carrefour HM – Barentin',
      ];
      for (final n in noms) {
        expect(find.text(n), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text(noms[0])).dy,
        lessThan(tester.getTopLeft(find.text(noms[1])).dy),
      );
      expect(
        tester.getTopLeft(find.text(noms[1])).dy,
        lessThan(tester.getTopLeft(find.text(noms[2])).dy),
      );
      expect(find.text('Classe A · probabilité 60 %'), findsNWidgets(2));
      expect(find.text('Classe A · probabilité 55 %'), findsOneWidget);
      expect(find.text('En négo'), findsNWidgets(3));
      expect(find.textContaining('180 k€/an'), findsOneWidget);
      expect(find.textContaining('160 k€/an'), findsOneWidget);
      expect(find.textContaining('130 k€/an'), findsOneWidget);
      // Prochaine action : seul Super U – Versailles a un RDV prévu (jeudi 10:00).
      expect(find.text('📅 RDV · Jeu 10:00'), findsOneWidget);
      // Les prospects autres que ces trois ne figurent pas.
      expect(find.text('Carrefour HM – Évreux'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ma tournée du jour : prochaine étape, itinéraire, à venir', (
      tester,
    ) async {
      await monter(tester, Role.cs);
      expect(find.text('Ma tournée du jour'), findsOneWidget);
      expect(find.text('Voir mon planning'), findsOneWidget);
      expect(etapes(tester), {
        'Carrefour – Paris': true,
        'Administratif': false,
      });
      expect(find.text('11:30 · Prospect · RDV'), findsOneWidget);
      expect(find.text('16:00 · ADM · Compte rendu'), findsOneWidget);
      expect(find.text('Prochain'), findsOneWidget);
      expect(find.text('📍'), findsOneWidget);
      expect(find.text('Itinéraire'), findsOneWidget);
      expect(find.text('À venir'), findsOneWidget);
      expect(find.text('🕒'), findsOneWidget);
      expect(
        find.text('Aucune étape aujourd\'hui. Ajoutez un RDV ci-dessous.'),
        findsNothing,
      );
    });

    testWidgets("« Itinéraire » ouvre l'adresse de l'étape", (tester) async {
      final lanceur = LanceurFactice();
      await monter(tester, Role.cs, lanceur: lanceur);
      await tester.ensureVisible(find.text('Itinéraire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Itinéraire'));
      await tester.pump();
      expect(lanceur.ouverts, hasLength(1));
      expect(lanceur.ouverts.single.scheme, 'geo');
      // Le bouton n'ouvre pas la fiche de l'étape.
      expect(routeCourante(tester), '/');
    });

    testWidgets("« Itinéraire » : toast d'erreur si aucune application", (
      tester,
    ) async {
      await monter(tester, Role.cs, lanceur: LanceurFactice(reussit: false));
      await tester.ensureVisible(find.text('Itinéraire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Itinéraire'));
      await tester.pump();
      expect(find.text("Impossible d'ouvrir l'application."), findsOneWidget);
      await laisserPasserToast(tester);
    });

    testWidgets('aucune étape ce jour : message vide et tuile 0/0', (
      tester,
    ) async {
      await monter(tester, Role.cs);
      conteneurMonte(tester).read(jourPlanningProvider.notifier).choisir(4);
      await tester.pumpAndSettle();
      expect(
        find.text("Aucune étape aujourd'hui. Ajoutez un RDV ci-dessous."),
        findsOneWidget,
      );
      expect(find.text('0/0'), findsOneWidget);
      expect(find.byType(CarteEtapeAccueil), findsNothing);
    });

    testWidgets('lundi : l’étape faite est cochée, sans prochaine étape', (
      tester,
    ) async {
      await monter(tester, Role.cs);
      conteneurMonte(tester).read(jourPlanningProvider.notifier).choisir(0);
      await tester.pumpAndSettle();
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsOneWidget);
      expect(
        find.text('09:30 · Client · RDV · Point linéaire soin'),
        findsOneWidget,
      );
      expect(find.text('Fait'), findsOneWidget);
      expect(find.text('✓'), findsOneWidget);
      expect(find.text('Prochain'), findsNothing);
      expect(find.text('Itinéraire'), findsNothing);
    });

    testWidgets('marquer l’étape faite met l’accueil à jour', (tester) async {
      await monter(tester, Role.cs);
      storeMonte(tester).majEtape('e6', (e) => e.copyWith(fait: true));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      expect(etapes(tester), {
        'Carrefour – Paris': false,
        'Administratif': true,
      });
      expect(find.text('Fait'), findsOneWidget);
      expect(find.text('Prochain'), findsOneWidget);
    });

    testWidgets('une étape ajoutée au planning passe en tête de la tournée', (
      tester,
    ) async {
      await monter(tester, Role.cs);
      storeMonte(tester).ajouterEtape(
        const EtapePlanning(
          id: 'e-test',
          jour: 2,
          heure: '08:00',
          cible: CiblePlanning.libre,
          titre: 'Petit-déjeuner fournisseur',
          note: 'Salon',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0/3'), findsOneWidget);
      expect(find.text('08:00 · Libre · Salon'), findsOneWidget);
      expect(etapes(tester).keys.first, 'Petit-déjeuner fournisseur');
      expect(etapes(tester)['Petit-déjeuner fournisseur'], isTrue);
      expect(etapes(tester)['Carrefour – Paris'], isFalse);
    });

    testWidgets('changer l’étape d’un prospect met le bloc à jour', (
      tester,
    ) async {
      await monter(tester, Role.cs);
      storeMonte(tester).changerEtapeProspect('p1', StatutProspect.gagne);
      await tester.pumpAndSettle();
      // Super U – Versailles est référencé : il quitte les prospects à suivre, le suivant (en négo) le remplace.
      expect(find.text('Super U – Versailles'), findsNothing);
      expect(find.text('Carrefour HM – Barentin'), findsOneWidget);
      expect(find.text('Carrefour HM – Évreux'), findsNothing);
      expect(find.text('Intermarché – Elbeuf'), findsNothing);
      expect(find.text('Carrefour HM – Mont-Saint-Aignan'), findsOneWidget);
    });

    testWidgets('sans prospect : titre et lien seuls, tuile à 0', (
      tester,
    ) async {
      await monter(tester, Role.cs);
      storeMonte(tester).mutate((e) => e.copyWith(prospects: const []));
      await tester.pumpAndSettle();
      expect(find.text('Prospects à suivre'), findsOneWidget);
      expect(find.text('Voir tous'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(Tuile, 'Prospects'),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('un prospect pas encore envoyé n’ouvre pas sa fiche', (
      tester,
    ) async {
      await monter(tester, Role.cs);
      storeMonte(tester).ajouterProspect(
        const Prospect(
          id: 'p24',
          nom: 'Leclerc – Test',
          raison: 'LECLERC TEST',
          classe: 'A',
          cp: '78000 Versailles',
          statut: StatutProspect.negociation,
          pot: 500,
          proba: 60,
          timeline: [],
          attente: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Leclerc – Test'), findsOneWidget);
      await tester.ensureVisible(find.text('Leclerc – Test'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leclerc – Test'));
      await tester.pump();
      expect(
        find.text(
          "Ce prospect n'est pas encore envoyé : sa fiche s'ouvrira dès son envoi.",
        ),
        findsOneWidget,
      );
      expect(routeCourante(tester), '/');
      await laisserPasserToast(tester);
    });
  });

  group('chef de secteur : navigation', () {
    testWidgets('« Voir tous » ouvre l’onglet Prospects', (tester) async {
      await lancerApp(tester, Role.cs);
      await toucher(tester, find.text('Voir tous'));
      expect(conteneurMonte(tester).read(ongletProvider), OngletApp.prospects);
    });

    testWidgets('la tuile Prospects ouvre l’onglet Prospects', (tester) async {
      await lancerApp(tester, Role.cs);
      await toucher(tester, find.widgetWithText(Tuile, 'Prospects'));
      expect(conteneurMonte(tester).read(ongletProvider), OngletApp.prospects);
    });

    testWidgets('« Voir mon planning » ouvre l’onglet Planning', (
      tester,
    ) async {
      await lancerApp(tester, Role.cs);
      await toucher(tester, find.text('Voir mon planning'));
      expect(conteneurMonte(tester).read(ongletProvider), OngletApp.planning);
    });

    testWidgets('un prospect à suivre ouvre sa fiche', (tester) async {
      await lancerApp(tester, Role.cs);
      await toucher(tester, find.text('E.Leclerc – Mantes-la-Jolie'));
      expect(routeCourante(tester), 'prospect');
      expect(
        tester
            .widget<FicheProspectScreen>(find.byType(FicheProspectScreen))
            .prospectId,
        'p17',
      );
      // La fiche s'ouvre par-dessus l'accueil : l'onglet ne change pas.
      expect(conteneurMonte(tester).read(ongletProvider), OngletApp.accueil);
    });

    testWidgets('une étape sur un prospect ouvre sa fiche sur Prospects', (
      tester,
    ) async {
      await lancerApp(tester, Role.cs);
      await toucher(tester, find.text('Carrefour – Paris'));
      expect(routeCourante(tester), 'prospect');
      expect(
        tester
            .widget<FicheProspectScreen>(find.byType(FicheProspectScreen))
            .prospectId,
        'p2',
      );
      // Maquette : `ouvrirFiche` pose l'onglet Prospects sous la fiche.
      expect(conteneurMonte(tester).read(ongletProvider), OngletApp.prospects);
    });

    testWidgets('une étape sur un client ouvre sa fiche sur l’accueil', (
      tester,
    ) async {
      await lancerApp(tester, Role.cs);
      conteneurMonte(tester).read(jourPlanningProvider.notifier).choisir(0);
      await tester.pumpAndSettle();
      await toucher(tester, find.text('Carrefour – Ivry-sur-Seine'));
      expect(routeCourante(tester), 'magasin');
      expect(
        tester
            .widget<FicheMagasinScreen>(find.byType(FicheMagasinScreen))
            .magasinId,
        'm4',
      );
      expect(conteneurMonte(tester).read(ongletProvider), OngletApp.accueil);
    });

    testWidgets('une étape administrative n’ouvre rien', (tester) async {
      await lancerApp(tester, Role.cs);
      await toucher(tester, find.text('Administratif'));
      expect(routeCourante(tester), '/');
      expect(conteneurMonte(tester).read(ongletProvider), OngletApp.accueil);
    });
  });

  group('directeur', () {
    testWidgets('entête : Bonjour Cindy, rôle avec ★★', (tester) async {
      await monter(tester, Role.dir);
      expect(find.text('Bonjour Cindy'), findsOneWidget);
      expect(find.textContaining('Directeur régional'), findsOneWidget);
      expect(find.text('★★'), findsOneWidget);
      expect(find.text('CR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tuiles : pas de Prospects, CA / objectif de la région', (
      tester,
    ) async {
      await monter(tester, Role.dir);
      expect(find.text('RDV du jour'), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      expect(find.widgetWithText(Tuile, 'Prospects'), findsNothing);
      expect(find.text('CA / objectif · région'), findsOneWidget);
      // Les huit promoteurs des trois chefs de secteur.
      expect(find.text('29 800 € / 35 650 €'), findsOneWidget);
      final barre = tester.widget<BarreObjectif>(find.byType(BarreObjectif));
      expect([barre.real, barre.cible], [29800, 35650]);
    });

    testWidgets('pas de bloc « Prospects à suivre »', (tester) async {
      await monter(tester, Role.dir);
      expect(find.text('Prospects à suivre'), findsNothing);
      expect(find.text('Voir tous'), findsNothing);
    });

    testWidgets(
      'ma tournée du jour : trois étapes, la première est la prochaine',
      (tester) async {
        await monter(tester, Role.dir);
        expect(find.text('Ma tournée du jour'), findsOneWidget);
        expect(etapes(tester), {
          'Carrefour – Rouen': true,
          'Carrefour – Paris': false,
          'Administratif': false,
        });
        expect(find.text('09:00 · Client'), findsOneWidget);
        expect(find.text('11:30 · Prospect · RDV'), findsOneWidget);
        expect(find.text('16:00 · ADM · Compte rendu'), findsOneWidget);
        expect(find.text('Itinéraire'), findsOneWidget);
        expect(find.text('À venir'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('une étape sur un client ouvre sa fiche', (tester) async {
      await lancerApp(tester, Role.dir);
      await toucher(tester, find.text('Carrefour – Rouen'));
      expect(routeCourante(tester), 'magasin');
      expect(
        tester
            .widget<FicheMagasinScreen>(find.byType(FicheMagasinScreen))
            .magasinId,
        'm3',
      );
    });

    testWidgets('« Voir mon planning » ouvre l’onglet Planning', (
      tester,
    ) async {
      await lancerApp(tester, Role.dir);
      await toucher(tester, find.text('Voir mon planning'));
      expect(conteneurMonte(tester).read(ongletProvider), OngletApp.planning);
    });

    testWidgets('le jour choisi dans le planning change la tournée', (
      tester,
    ) async {
      await monter(tester, Role.dir);
      conteneurMonte(tester).read(jourPlanningProvider.notifier).choisir(1);
      await tester.pumpAndSettle();
      // Mardi : Carrefour Market – Rouen (fait) et Carrefour Market – Versailles (à faire).
      expect(find.text('1/2'), findsOneWidget);
      expect(etapes(tester), {
        'Carrefour Market – Rouen': false,
        'Carrefour Market – Versailles': true,
      });
    });
  });
}
