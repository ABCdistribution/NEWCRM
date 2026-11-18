import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/accueil/accueil_logique.dart';
import 'package:crm_app/features/commandes/prise_commande_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/visites/aide_visites.dart' as visites;
import '../support/app_test_support.dart';
import 'aide_integration.dart';

/// L'effet d'une action faite dans un lot doit se voir dans les écrans des autres lots : prospect créé ou changé
/// d'étape, client passé en client, commande ajoutée, visite terminée, ligne de planning faite.
void main() {
  testWidgets(
    'prospect créé : page Prospects, tuile de l’accueil et formulaire de planning',
    (tester) async {
      await lancerApp(tester, Role.cs);
      final avant = store(tester).prospects.length;
      await ouvrir(tester, () => AppRoutes.nouveauProspect(ctx(tester)));
      final champs = find.byType(TextFormField);
      await tester.enterText(champs.at(0), 'Monoprix Lunel');
      await tester.enterText(champs.at(1), 'Monoprix Lunel SAS');
      await tester.ensureVisible(find.text('＋ Créer le prospect'));
      await tester.tap(find.text('＋ Créer le prospect'));
      await tester.pumpAndSettle();

      final etat = store(tester);
      expect(etat.prospects.length, avant + 1);
      final cree = etat.prospects.last;
      expect(cree.nom, 'Monoprix Lunel');
      expect(cree.attente, isTrue);
      // La page Prospects est affichée, avec la nouvelle carte.
      expect(ongletCourant(tester), OngletApp.prospects);
      expect(find.text('Monoprix Lunel'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      // Le formulaire de planning (lot planning) le propose parmi les prospects.
      await ouvrir(
        tester,
        () =>
            AppRoutes.formulaireRdv(ctx(tester), cible: CiblePlanning.prospect),
      );
      final liste = tester.widget<ChampListe<String>>(
        find.byWidgetPredicate(
          (w) => w is ChampListe<String> && w.label == 'Prospect',
        ),
      );
      expect(liste.options[cree.id], 'Monoprix Lunel');
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();

      // La tuile « Prospects » de l'accueil compte le nouveau prospect.
      await tester.tap(nav('Accueil'));
      await tester.pumpAndSettle();
      final tuile = tester.widget<Tuile>(
        find.byWidgetPredicate((w) => w is Tuile && w.libelle == 'Prospects'),
      );
      expect(tuile.valeur, '${avant + 1}');
    },
  );

  testWidgets(
    'étape changée puis passage en client : planning, accueil et fiche suivent',
    (tester) async {
      await lancerApp(tester, Role.cs);
      final ligne = store(tester).etapes.firstWhere(
        (e) =>
            e.cible == CiblePlanning.prospect &&
            store(tester).prospectParId(e.ref!)?.groupe !=
                GroupeProspect.enNego,
      );
      final p = store(tester).prospectParId(ligne.ref!)!;

      // Le planning montre « Prospect » tant que le prospect n'est pas en négociation.
      await tester.tap(nav('Planning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(joursCourts[ligne.jour]));
      await tester.pumpAndSettle();
      expect(find.text('Négo'), findsNothing);

      // Lot prospects : changer d'étape depuis la fiche.
      await ouvrir(tester, () => AppRoutes.ficheProspect(ctx(tester), p.id));
      await tester.tap(find.text("Changer d'étape"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('En négociation'));
      await tester.pumpAndSettle();
      expect(
        store(tester).prospectParId(p.id)!.statut,
        StatutProspect.negociation,
      );
      expect(find.text('Étape → En négociation'), findsOneWidget);
      AppRoutes.retourRacine(ctx(tester));
      await tester.pumpAndSettle();

      // Lot planning : la carte de la ligne passe en « Négo ».
      expect(ongletCourant(tester), OngletApp.planning);
      expect(find.text('Négo'), findsOneWidget);

      // Lot accueil : les trois prospects à suivre sont ceux du store (les négociations d'abord).
      await tester.tap(nav('Accueil'));
      await tester.pumpAndSettle();
      final suivis = prospectsASuivre(store(tester).prospects);
      expect(suivis.length, 3);
      for (final x in suivis) {
        expect(find.text(x.nom), findsOneWidget);
      }

      // Le premier passe en client (lot prospects) : l'accueil ne le propose plus et en propose un autre.
      final q = suivis.first;
      await ouvrir(tester, () => AppRoutes.ficheProspect(ctx(tester), q.id));
      await tester.tap(find.widgetWithText(AppBouton, 'Passer en client'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppBouton, 'Passer en client').last);
      await tester.pumpAndSettle();
      expect(store(tester).prospectParId(q.id)!.statut, StatutProspect.gagne);
      expect(find.widgetWithText(AppBouton, 'Passer en client'), findsNothing);
      AppRoutes.retourRacine(ctx(tester));
      await tester.pumpAndSettle();
      final apres = prospectsASuivre(store(tester).prospects);
      expect(apres.map((x) => x.id), isNot(contains(q.id)));
      expect(find.text(q.nom), findsNothing);
      for (final x in apres) {
        expect(find.text(x.nom), findsOneWidget);
      }
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('ligne de planning faite : accueil et fiche du prospect', (
    tester,
  ) async {
    await lancerApp(tester, Role.cs);
    final ligne = store(
      tester,
    ).etapes.firstWhere((e) => e.cible == CiblePlanning.prospect && !e.fait);
    final p = store(tester).prospectParId(ligne.ref!)!;
    final avantFaites = lignesDuJour(
      store(tester).etapes,
      2,
    ).where((e) => e.fait).length;

    // Lot planning : « Visite effectuée » sur la ligne.
    await tester.tap(nav('Planning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(joursCourts[ligne.jour]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('✎').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visite effectuée'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(
      store(tester).etapes.firstWhere((e) => e.id == ligne.id).fait,
      isTrue,
    );
    expect(find.text('Fait ✓'), findsWidgets);

    // Lot accueil : « RDV du jour » compte la ligne faite (si elle est du jour affiché).
    await tester.tap(nav('Accueil'));
    await tester.pumpAndSettle();
    final duJour = lignesDuJour(store(tester).etapes, 2);
    final nbFaites = duJour.where((e) => e.fait).length;
    if (ligne.jour == 2) expect(nbFaites, avantFaites + 1);
    expect(find.text('$nbFaites/${duJour.length}'), findsOneWidget);

    // Lot prospects : le RDV prévu de la timeline vient des lignes pas encore faites.
    final autre = store(tester).etapes.any(
      (e) => e.cible == CiblePlanning.prospect && e.ref == p.id && !e.fait,
    );
    await ouvrir(tester, () => AppRoutes.ficheProspect(ctx(tester), p.id));
    expect(find.text('RDV prévu'), autre ? findsOneWidget : findsNothing);
  });

  testWidgets(
    'commande ajoutée : onglet Commandes, suivi de l’accueil et fiche du client',
    (tester) async {
      await lancerApp(tester, Role.promoteur);
      final avantEnCours = livraisonsEnCours(store(tester)).length;
      await ouvrir(
        tester,
        () => AppRoutes.priseCommande(ctx(tester), magasinId: 'm1'),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(LigneProduit).first,
          matching: find.text('＋ Ajouter'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Voir le panier ›'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('✓ Valider'));
      await tester.pumpAndSettle();
      final commande = store(tester).commandes.first;
      expect(commande.magasinId, 'm1');
      await tester.pump(const Duration(seconds: 3));

      // Sans visite : retour sur l'onglet Commandes, qui montre la nouvelle commande.
      expect(ongletCourant(tester), OngletApp.commandes);
      expect(find.textContaining(commande.id), findsWidgets);

      // L'accueil compte une livraison en cours de plus.
      await tester.tap(nav('Accueil'));
      await tester.pumpAndSettle();
      expect(
        find.text('🚚 Suivi des livraisons · ${avantEnCours + 1} en cours'),
        findsOneWidget,
      );

      // La fiche du client la liste dans « Commandes ».
      await ouvrir(tester, () => AppRoutes.ficheMagasin(ctx(tester), 'm1'));
      await tester.tap(find.text('Commandes'));
      await tester.pumpAndSettle();
      expect(find.textContaining(commande.id), findsWidgets);
    },
  );

  testWidgets(
    'visite terminée : tournée de l’accueil, liste des visites, fiche et alertes',
    (tester) async {
      await lancerApp(tester, Role.promoteur);
      final avant = lignesTournee(
        store(tester),
      ).where((l) => l.etat == EtatTournee.realisee).length;

      // Lot visites : démarrer chez un client de la tournée, tout horodater puis valider.
      await ouvrir(tester, () => AppRoutes.demarrerVisite(ctx(tester), 'm1'));
      await fermerKilometrage(tester);
      final id = store(tester).visites.first.id;
      // L'accueil la voit « En cours » (brouillon du 4 nov.).
      expect(
        lignesTournee(
          store(tester),
        ).firstWhere((l) => l.magasin.id == 'm1').etat,
        EtatTournee.enCours,
      );
      visites.completerVisite(tester, id);
      await tester.pumpAndSettle();
      await visites.terminerLeParcours(tester);
      expect(find.text('Valider la visite ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppBouton, 'Valider'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Lot accueil : la visite chez m1 est « Réalisée », la tuile « Visites » compte une visite de plus.
      expect(
        store(tester).visites.firstWhere((v) => v.id == id).etat,
        isNot(EtatVisite.brouillon),
      );
      expect(
        lignesTournee(
          store(tester),
        ).firstWhere((l) => l.magasin.id == 'm1').etat,
        EtatTournee.realisee,
      );
      expect(ongletCourant(tester), OngletApp.accueil);
      final tuile = tester.widget<Tuile>(
        find.byWidgetPredicate((w) => w is Tuile && w.libelle == 'Visites'),
      );
      expect(tuile.valeur, '${avant + 1}');

      // Lot visites : la liste la montre « À envoyer » (puis « Envoyée » après l'envoi simulé).
      await tester.tap(nav('Visites'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Pastille && (w.label == 'À envoyer' || w.label == 'Envoyée'),
        ),
        findsWidgets,
      );
    },
  );
}
