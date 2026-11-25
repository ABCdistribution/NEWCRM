import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/clients/fiche_magasin_screen.dart';
import 'package:crm_app/features/commandes/prise_commande_screen.dart';
import 'package:crm_app/features/planning/formulaire_rdv_sheet.dart';
import 'package:crm_app/features/prospects/fiche_prospect_screen.dart';
import 'package:crm_app/features/visites/compte_rendu_screen.dart';
import 'package:crm_app/features/visites/state/actions_visite.dart';
import 'package:crm_app/features/visites/visite_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_support.dart';
import 'aide_integration.dart';

/// Parcours qui traversent plusieurs lots : une action faite dans un lot doit se voir dans les écrans des autres
/// (maquette `demo-appli.html` : tout passe par l'état `S`, ici par `crmProvider`).

void main() {
  group(
    'C1 · « Planifier » des fiches (clients, prospects) → formulaire du planning',
    () {
      testWidgets(
        'fiche client du chef de secteur : feuille de la fiche, visite: false, la ligne arrive dans le planning et l’accueil',
        (tester) async {
          await lancerApp(tester, Role.cs);
          final m = store(tester).magasins.first;
          final avant = lignesDuJour(store(tester).etapes, 2).length;
          await ouvrir(tester, () => AppRoutes.ficheMagasin(ctx(tester), m.id));
          expect(find.byType(FicheMagasinScreen), findsOneWidget);

          await tester.tap(find.text('Planifier'));
          await tester.pumpAndSettle();
          final feuille = tester.widget<FormulaireRdvSheet>(
            find.byType(FormulaireRdvSheet),
          );
          expect(feuille.visite, isFalse);
          expect(feuille.depuisFiche, isTrue);
          expect(feuille.cible, CiblePlanning.client);
          expect(feuille.refCible, m.id);
          expect(
            find.text('Planifier · ${nomEtClasse(m.nom, m.classe)}'),
            findsOneWidget,
          );

          await tester.tap(find.text('Ajouter la ligne'));
          await tester.pumpAndSettle();
          // Retour à l'onglet Planning, sur le jour de la ligne, qui montre la nouvelle ligne.
          expect(find.byType(FormulaireRdvSheet), findsNothing);
          expect(find.byType(FicheMagasinScreen), findsNothing);
          expect(ongletCourant(tester), OngletApp.planning);
          final lignes = lignesDuJour(store(tester).etapes, 2);
          expect(lignes.length, avant + 1);
          final nouvelle = lignes.firstWhere((e) => e.ref == m.id);
          expect(nouvelle.cible, CiblePlanning.client);
          // Le type de la feuille (« Visite simple ») remplace le `visite: false` de départ, comme dans la maquette.
          expect(nouvelle.visite, isTrue);
          expect(find.text(m.nom), findsWidgets);

          // L'accueil compte la nouvelle ligne dans « RDV du jour ».
          await tester.tap(nav('Accueil'));
          await tester.pumpAndSettle();
          final faites = lignes.where((e) => e.fait).length;
          expect(find.text('$faites/${lignes.length}'), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
        },
      );

      testWidgets(
        'fiche prospect : la ligne planifiée devient « RDV prévu » de sa timeline et sa prochaine action',
        (tester) async {
          await lancerApp(tester, Role.cs);
          final p = store(tester).prospects.firstWhere(
            (pr) =>
                !store(tester).etapes.any(
                  (e) => e.cible == CiblePlanning.prospect && e.ref == pr.id,
                ) &&
                pr.statut != StatutProspect.gagne &&
                pr.statut != StatutProspect.perdu,
          );
          await ouvrir(
            tester,
            () => AppRoutes.ficheProspect(ctx(tester), p.id),
          );
          expect(find.text('RDV prévu'), findsNothing);
          await tester.tap(find.text('Planifier'));
          await tester.pumpAndSettle();
          final feuille = tester.widget<FormulaireRdvSheet>(
            find.byType(FormulaireRdvSheet),
          );
          expect(feuille.visite, isFalse);
          expect(feuille.cible, CiblePlanning.prospect);
          expect(feuille.refCible, p.id);
          await tester.tap(find.text('Ajouter la ligne'));
          await tester.pumpAndSettle();
          expect(ongletCourant(tester), OngletApp.planning);
          final ligne = store(tester).etapes.firstWhere((e) => e.ref == p.id);
          expect(ligne.cible, CiblePlanning.prospect);

          // La fiche du prospect montre ce RDV en tête de sa timeline.
          await ouvrir(
            tester,
            () => AppRoutes.ficheProspect(ctx(tester), p.id),
          );
          expect(find.text('RDV prévu'), findsOneWidget);
          expect(
            find.text('Visite planifiée dans mon planning'),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 3));
        },
      );
    },
  );

  group('C2 · kilométrage de départ à la première visite démarrée', () {
    testWidgets('depuis l’accueil (tournée du jour), une seule fois', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      expect(find.text('Kilométrage de départ'), findsNothing);
      await tester.tap(find.text('Démarrer la visite'));
      await tester.pumpAndSettle();
      expect(find.byType(VisiteScreen), findsOneWidget);
      await fermerKilometrage(tester);

      // Un autre client depuis une fiche client : plus de dialogue.
      AppRoutes.retourRacine(ctx(tester));
      await tester.pumpAndSettle();
      await ouvrir(tester, () => AppRoutes.ficheMagasin(ctx(tester), 'm8'));
      await tester.tap(find.text('＋ Visite'));
      await tester.pumpAndSettle();
      expect(find.byType(VisiteScreen), findsOneWidget);
      expect(find.text('Kilométrage de départ'), findsNothing);
    });

    testWidgets('depuis une fiche client', (tester) async {
      await lancerApp(tester, Role.promoteur);
      await ouvrir(tester, () => AppRoutes.ficheMagasin(ctx(tester), 'm1'));
      await tester.tap(find.text('＋ Visite'));
      await tester.pumpAndSettle();
      expect(find.byType(VisiteScreen), findsOneWidget);
      await fermerKilometrage(tester);
    });

    testWidgets(
      'un brouillon rouvert depuis la liste des visites ne repose pas la question',
      (tester) async {
        await lancerApp(tester, Role.promoteur);
        await ouvrir(tester, () => AppRoutes.demarrerVisite(ctx(tester), 'm1'));
        await fermerKilometrage(tester);
        AppRoutes.retourRacine(ctx(tester));
        await tester.pumpAndSettle();
        await tester.tap(nav('Visites'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Carrefour Market – Versailles').first);
        await tester.pumpAndSettle();
        expect(find.byType(VisiteScreen), findsOneWidget);
        expect(find.text('Kilométrage de départ'), findsNothing);
      },
    );

    for (final role in [Role.cs, Role.dir]) {
      testWidgets('${role.profil.libelle} : aucun kilométrage', (tester) async {
        await lancerApp(tester, role);
        await ouvrir(
          tester,
          () => AppRoutes.demarrerVisite(
            ctx(tester),
            store(tester).magasins.first.id,
          ),
        );
        expect(find.byType(VisiteScreen), findsOneWidget);
        expect(find.text('Kilométrage de départ'), findsNothing);
      });
    }
  });

  group('C3 · équipe → feuille du planning (planCible) → planning de l’équipe', () {
    testWidgets(
      'chef de secteur : ajouter, modifier puis supprimer une visite sur la page d’un promoteur',
      (tester) async {
        await lancerApp(tester, Role.cs);
        await ouvrir(
          tester,
          () =>
              AppRoutes.pagePromoteur(ctx(tester), csId: 'n', nom: 'Julien M.'),
        );
        final avant = store(tester).planDe('Julien M.').length;
        final jour = conteneur(tester).read(jourPlanningProvider);
        final dejaAffichees = lignesDuJour(
          store(tester).planDe('Julien M.'),
          jour,
          sem: 0,
        ).length;

        await tester.tap(find.text('＋ Ajouter une ligne'));
        await tester.pumpAndSettle();
        expect(
          find.text('Planifier une visite client · Julien M.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Ajouter la visite'));
        await tester.pumpAndSettle();
        expect(find.byType(FormulaireRdvSheet), findsNothing);
        var plan = store(tester).planDe('Julien M.');
        expect(plan.length, avant + 1);
        final ajoutee = plan.last;
        expect(ajoutee.sem, 0);
        expect(ajoutee.jour, jour);
        expect(ajoutee.cible, CiblePlanning.client);
        // La page du promoteur montre aussitôt la ligne et le nouveau décompte du jour.
        expect(find.text(ajoutee.titre), findsWidgets);
        expect(lignesDuJour(plan, jour, sem: 0).length, dejaAffichees + 1);

        // Modification : un appui sur la ligne ouvre la feuille de la ligne, la consigne est enregistrée.
        await tester.tap(find.text(ajoutee.titre).first);
        await tester.pumpAndSettle();
        expect(find.text('Modifier la visite · Julien M.'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, '').last,
          'Refaire la tête de gondole',
        );
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();
        plan = store(tester).planDe('Julien M.');
        expect(plan.length, avant + 1);
        expect(plan.last.note, 'Refaire la tête de gondole');
        expect(find.text('Refaire la tête de gondole'), findsOneWidget);

        // Suppression.
        await tester.tap(find.text(ajoutee.titre).first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Supprimer la visite'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer la visite'));
        await tester.pumpAndSettle();
        expect(store(tester).planDe('Julien M.').length, avant);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'directeur : la page d’un chef de secteur affiche son planning à jour',
      (tester) async {
        await lancerApp(tester, Role.dir);
        await ouvrir(tester, () => AppRoutes.pageChefSecteur(ctx(tester), 'k'));
        final jour = conteneur(tester).read(jourPlanningProvider);
        final nom = chefsSecteurDemo.firstWhere((c) => c.id == 'k').nom;
        final avant = store(tester).planDe(nom);
        final titres = lignesDuJour(avant, jour, sem: 0).map((e) => e.titre);
        for (final t in titres) {
          expect(find.text(t), findsWidgets);
        }
        if (titres.isEmpty) {
          expect(find.text('Aucune ligne ce jour.'), findsOneWidget);
        }
        // Une ligne composée pour ce chef de secteur (feuille du lot planning) s'affiche sans rouvrir la page.
        conteneur(tester)
            .read(crmProvider.notifier)
            .ajouterEtape(
              EtapePlanning(
                id: 'zz1',
                jour: jour,
                heure: '17:45',
                cible: CiblePlanning.libre,
                titre: 'Débrief régional',
                sem: 0,
              ),
              pour: nom,
            );
        await tester.pumpAndSettle();
        expect(find.text('Débrief régional'), findsOneWidget);
        expect(find.text('17:45'), findsOneWidget);
        expect(find.text('Aucune ligne ce jour.'), findsNothing);
        // Page en lecture seule : pas de « Ajouter une ligne ».
        expect(find.text('＋ Ajouter une ligne'), findsNothing);
      },
    );
  });

  group('C4 · commande lancée depuis une visite → retour à la visite', () {
    testWidgets('la visite affiche « Commande #… » et la commande est partout', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      await ouvrir(tester, () => AppRoutes.demarrerVisite(ctx(tester), 'm1'));
      await fermerKilometrage(tester);
      final visite = store(tester).visites.first;

      // Les deux photos et la réponse « pas de commande à mettre en rayon » ouvrent le chemin vers l'étape « Commande
      // liée à la visite » (photos prises : simulées par l'action qui suit chaque capture).
      final actions = ActionsVisite(
        conteneur(tester).read(crmProvider.notifier),
        visite.id,
      );
      actions.ajouterPhoto(EtapeDph.arrivee);
      actions.ajouterPhoto(EtapeDph.rayonArrivee);
      actions.definirCommandeEnRayon(oui: false);
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Suivant ›'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Étape 5 / 7'), findsOneWidget);
      await tester.tap(find.text('Oui'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aucune commande prise pour le moment.'),
        findsOneWidget,
      );

      await tester.tap(find.text('🛒 Prendre la commande'));
      await tester.pumpAndSettle();
      expect(find.byType(PriseCommandeScreen), findsOneWidget);
      final premiere = find.byType(LigneProduit).first;
      await tester.tap(
        find.descendant(of: premiere, matching: find.text('＋ Ajouter')),
      );
      await tester.pump();
      await tester.tap(find.text('Voir le panier ›'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('✓ Valider'));
      await tester.pumpAndSettle();

      // Retour sur la visite (et non sur la liste des commandes), qui porte la commande.
      expect(find.byType(VisiteScreen), findsOneWidget);
      expect(find.byType(PriseCommandeScreen), findsNothing);
      final etat = store(tester);
      final commande = etat.commandes.first;
      expect(commande.magasinId, 'm1');
      final liee = etat.visiteParId(visite.id)!.cmd!;
      expect(liee.id, commande.id.replaceFirst('CDE-', ''));
      expect(find.textContaining('Commande #${liee.id} : '), findsOneWidget);
      expect(find.text('Aucune commande prise pour le moment.'), findsNothing);
      await tester.pump(const Duration(seconds: 3));

      // Le compte rendu de la même visite montre la commande liée.
      await ouvrir(tester, () => AppRoutes.compteRendu(ctx(tester), visite.id));
      expect(find.byType(CompteRenduScreen), findsOneWidget);
      expect(find.textContaining('#${liee.id} : '), findsOneWidget);
    });
  });

  group('C5 · compte rendu → « Cliquez ici » → fiche client', () {
    for (final (role, onglet) in [
      (Role.promoteur, 'Aperçu'),
      (Role.cs, 'Suivi'),
      (Role.dir, 'Suivi'),
    ]) {
      testWidgets('${role.profil.libelle} : onglet « $onglet »', (
        tester,
      ) async {
        await lancerApp(tester, role);
        await ouvrir(tester, () => AppRoutes.compteRendu(ctx(tester), 'd0'));
        await tester.ensureVisible(find.text('Cliquez ici'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cliquez ici'));
        await tester.pumpAndSettle();
        expect(find.byType(FicheMagasinScreen), findsOneWidget);
        // L'onglet sélectionné est celui du rôle : « Aperçu » pour le promoteur, « Suivi » pour l'encadrement.
        final pills = tester.widget<OngletsPills>(
          find.descendant(
            of: find.byType(FicheMagasinScreen),
            matching: find.byType(OngletsPills),
          ),
        );
        expect(pills.libelles[pills.index], onglet);
      });
    }
  });

  group('C6 · planning et accueil → fiche du prospect ou du client', () {
    testWidgets(
      'chef de secteur : une ligne prospect ouvre la fiche sur l’onglet Prospects',
      (tester) async {
        await lancerApp(tester, Role.cs);
        final ligne = store(
          tester,
        ).etapes.firstWhere((e) => e.cible == CiblePlanning.prospect);
        final prospect = store(tester).prospectParId(ligne.ref!)!;
        // Depuis le planning.
        await tester.tap(nav('Planning'));
        await tester.pumpAndSettle();
        final jour = ligne.jour;
        await tester.tap(find.text(joursCourts[jour]));
        await tester.pumpAndSettle();
        await tester.tap(find.text(ligne.titre).first);
        await tester.pumpAndSettle();
        expect(find.byType(FicheProspectScreen), findsOneWidget);
        expect(find.text(prospect.nom), findsWidgets);
        AppRoutes.retourRacine(ctx(tester));
        await tester.pumpAndSettle();
        expect(ongletCourant(tester), OngletApp.prospects);
      },
    );

    testWidgets(
      'chef de secteur : une ligne client ouvre la fiche, onglet Suivi',
      (tester) async {
        await lancerApp(tester, Role.cs);
        final ligne = store(
          tester,
        ).etapes.firstWhere((e) => e.cible == CiblePlanning.client);
        await tester.tap(nav('Planning'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(joursCourts[ligne.jour]));
        await tester.pumpAndSettle();
        await tester.tap(find.text(ligne.titre).first);
        await tester.pumpAndSettle();
        expect(find.byType(FicheMagasinScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FicheMagasinScreen),
            matching: find.text('Suivi'),
          ),
          findsOneWidget,
        );
        AppRoutes.retourRacine(ctx(tester));
        await tester.pumpAndSettle();
        expect(ongletCourant(tester), OngletApp.planning);
      },
    );

    for (final role in [Role.cs, Role.dir]) {
      testWidgets(
        '${role.profil.libelle} : l’accueil ouvre le prospect sur l’onglet Prospects et le client sur la fiche',
        (tester) async {
          await lancerApp(tester, role);
          final etapes = store(tester).etapes;
          final prospect = etapes.firstWhere(
            (e) => e.cible == CiblePlanning.prospect,
          );
          final client = etapes.firstWhere(
            (e) => e.cible == CiblePlanning.client,
          );

          // Ligne prospect : le jour de la ligne est celui de l'accueil, qui la liste.
          conteneur(
            tester,
          ).read(jourPlanningProvider.notifier).choisir(prospect.jour);
          await tester.pumpAndSettle();
          await tester.tap(find.text(prospect.titre).first);
          await tester.pumpAndSettle();
          expect(find.byType(FicheProspectScreen), findsOneWidget);
          AppRoutes.retourRacine(ctx(tester));
          await tester.pumpAndSettle();
          expect(ongletCourant(tester), OngletApp.prospects);

          // Ligne client : la fiche s'ouvre sur « Suivi » et l'onglet courant ne change pas.
          await tester.tap(nav('Accueil'));
          await tester.pumpAndSettle();
          conteneur(
            tester,
          ).read(jourPlanningProvider.notifier).choisir(client.jour);
          await tester.pumpAndSettle();
          await tester.tap(find.text(client.titre).first);
          await tester.pumpAndSettle();
          expect(find.byType(FicheMagasinScreen), findsOneWidget);
          final pills = tester.widget<OngletsPills>(
            find.descendant(
              of: find.byType(FicheMagasinScreen),
              matching: find.byType(OngletsPills),
            ),
          );
          expect(pills.libelles[pills.index], 'Suivi');
          AppRoutes.retourRacine(ctx(tester));
          await tester.pumpAndSettle();
          expect(ongletCourant(tester), OngletApp.accueil);
        },
      );
    }
  });
}
