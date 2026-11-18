import 'dart:async';

import 'package:crm_app/app.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/clients/fiche_magasin_screen.dart';
import 'package:crm_app/features/commandes/panier_screen.dart';
import 'package:crm_app/features/commandes/prise_commande_screen.dart';
import 'package:crm_app/features/equipe/chef_secteur_screen.dart';
import 'package:crm_app/features/equipe/promoteur_screen.dart';
import 'package:crm_app/features/equipe/semaine_cs_screen.dart';
import 'package:crm_app/features/prospects/fiche_prospect_screen.dart';
import 'package:crm_app/features/prospects/nouveau_prospect_screen.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:crm_app/features/visites/compte_rendu_screen.dart';
import 'package:crm_app/features/visites/visite_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_support.dart';

/// Titre de page attendu pour chaque onglet et chaque rôle.
String titreAttendu(OngletApp o, Role r) => switch (o) {
  OngletApp.accueil => 'Bonjour ${r.profil.prenom}',
  OngletApp.visites || OngletApp.secteurVisites => 'Visites',
  OngletApp.commandes || OngletApp.secteurCommandes => 'Commandes',
  OngletApp.clients => 'Clients',
  OngletApp.prospects => r == Role.dir ? 'Prospects' : 'Mes prospects',
  OngletApp.planning => 'Mon planning',
  OngletApp.catalogue => 'Référentiel produits',
  OngletApp.news => 'News',
  OngletApp.rapports => 'Mes rapports',
  OngletApp.equipe => 'Mon équipe',
};

Future<void> lancerEtChoisir(WidgetTester tester, Role role) async {
  await assurerInter(tester);
  utiliserTelephone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [modeDemoProvider.overrideWith(ModeDemoActif.new)],
      child: const CrmApp(),
    ),
  );
  await tester.pumpAndSettle();
  // Écran de choix du profil de démonstration.
  expect(find.text('DÉMO'), findsOneWidget);
  expect(find.text('Promoteur'), findsOneWidget);
  expect(find.text('Chef de secteur'), findsOneWidget);
  expect(find.text('Directeur régional'), findsOneWidget);
  await tester.tap(find.text(role.profil.libelle));
  await tester.pumpAndSettle();
  expect(find.byType(ShellScreen), findsOneWidget);
}

final boutonPlus = find.descendant(
  of: find.byType(AppNavBar),
  matching: find.bySemanticsLabel('Plus'),
);

Finder dansNav(String libelle) =>
    find.descendant(of: find.byType(AppNavBar), matching: find.text(libelle));

void main() {
  for (final role in Role.values) {
    testWidgets('parcours de tous les onglets : ${role.profil.libelle}', (
      tester,
    ) async {
      await lancerEtChoisir(tester, role);
      final config = configNavPour(role);

      // Barre de navigation : onglets directs.
      for (final o in config.barre) {
        expect(
          dansNav(o.libelle),
          findsOneWidget,
          reason: 'onglet ${o.libelle}',
        );
        await tester.tap(dansNav(o.libelle));
        await tester.pumpAndSettle();
        expect(
          find.text(titreAttendu(o, role)),
          findsWidgets,
          reason: 'titre de ${o.name}',
        );
        expect(tester.takeException(), isNull);
      }

      // Menu « + » : chaque entrée.
      for (final o in config.plus) {
        await tester.tap(boutonPlus);
        await tester.pumpAndSettle();
        final entree = find.descendant(
          of: find.byType(MenuPlus),
          matching: find.text(o.libelle),
        );
        expect(entree, findsOneWidget, reason: 'entrée « + » ${o.libelle}');
        await tester.tap(entree);
        await tester.pumpAndSettle();
        expect(find.byType(MenuPlus), findsNothing);
        expect(
          find.text(titreAttendu(o, role)),
          findsWidgets,
          reason: 'titre de ${o.name}',
        );
        expect(tester.takeException(), isNull);
      }

      // Retour à l'accueil.
      await tester.tap(dansNav('Accueil'));
      await tester.pumpAndSettle();
      expect(find.text('Bonjour ${role.profil.prenom}'), findsOneWidget);
    });
  }

  testWidgets(
    'la barre du promoteur : 5 onglets puis « + » avec Catalogue et News',
    (tester) async {
      await lancerEtChoisir(tester, Role.promoteur);
      for (final l in [
        'Accueil',
        'Visites',
        'Commandes',
        'Clients',
        'Planning',
      ]) {
        expect(dansNav(l), findsOneWidget);
      }
      expect(dansNav('Prospects'), findsNothing);
      await tester.tap(boutonPlus);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(MenuPlus),
          matching: find.text('Catalogue'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(MenuPlus), matching: find.text('News')),
        findsOneWidget,
      );
      // Un appui ailleurs referme le menu.
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
      expect(find.byType(MenuPlus), findsNothing);
    },
  );

  testWidgets('changer de profil depuis l’avatar de l’accueil', (tester) async {
    await lancerEtChoisir(tester, Role.promoteur);
    expect(find.text('Bonjour Julien'), findsOneWidget);
    await tester.tap(find.text('JM'));
    await tester.pumpAndSettle();
    expect(find.text('Changer de profil (démo)'), findsOneWidget);
    await tester.tap(find.text('Directeur régional'));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour Cindy'), findsOneWidget);
    expect(dansNav('Prospects'), findsOneWidget);
  });

  testWidgets('la cloche ouvre les alertes avec leur nombre', (tester) async {
    await lancerEtChoisir(tester, Role.dir);
    expect(find.text('4'), findsWidgets); // pastille de la cloche
    await tester.tap(find.bySemanticsLabel('Alertes'));
    await tester.pumpAndSettle();
    // Titre « Alertes clients » du directeur, avec la même pastille de nombre que la cloche.
    final feuille = find.byType(FeuilleBase);
    expect(feuille, findsOneWidget);
    expect(
      find.descendant(
        of: feuille,
        matching: find.textContaining('Alertes clients', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: feuille, matching: find.text('4')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tous les écrans empilés s’ouvrent et se ferment (AppRoutes)', (
    tester,
  ) async {
    await lancerEtChoisir(tester, Role.dir);
    BuildContext ctx() =>
        tester.element(find.byType(ShellScreen, skipOffstage: false));

    Future<void> verifier(
      Future<void> Function() ouvrir,
      String texte, {
      Type? ecran,
    }) async {
      final f = ouvrir();
      await tester.pumpAndSettle();
      expect(
        find.textContaining(texte, findRichText: true),
        findsWidgets,
        reason: texte,
      );
      if (ecran != null) {
        expect(find.byType(ecran), findsOneWidget, reason: '$ecran');
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BoutonRetour).first);
      await tester.pumpAndSettle();
      await f;
    }

    await verifier(
      () => AppRoutes.ficheMagasin(ctx(), 'm1'),
      'Carrefour Market – Versailles',
      ecran: FicheMagasinScreen,
    );
    await verifier(
      () => AppRoutes.ficheProspect(ctx(), 'p1'),
      'Super U – Versailles',
      ecran: FicheProspectScreen,
    );
    await verifier(
      () => AppRoutes.nouveauProspect(ctx()),
      'Nouveau prospect',
      ecran: NouveauProspectScreen,
    );
    await verifier(
      () => AppRoutes.compteRendu(ctx(), 'd0'),
      'Visite #218082',
      ecran: CompteRenduScreen,
    );
    // Une visite déjà terminée (`d0`) s'ouvre sur son compte rendu, pas sur les étapes.
    await verifier(
      () => AppRoutes.visite(ctx(), 'd0'),
      'Visite #218082',
      ecran: CompteRenduScreen,
    );
    await verifier(
      () => AppRoutes.priseCommande(ctx()),
      'Nouvelle commande',
      ecran: PriseCommandeScreen,
    );
    await verifier(
      () => AppRoutes.priseCommande(ctx(), magasinId: 'm1'),
      'Carrefour Market – Versailles',
      ecran: PriseCommandeScreen,
    );
    await verifier(
      () => AppRoutes.panierCommande(ctx()),
      'Panier',
      ecran: PanierScreen,
    );
    await verifier(
      () => AppRoutes.pageChefSecteur(ctx(), 'n'),
      'Nadia H.',
      ecran: ChefSecteurScreen,
    );
    await verifier(
      () => AppRoutes.pagePromoteur(ctx(), csId: 'n', nom: 'Léa P.'),
      'Léa P.',
      ecran: PromoteurScreen,
    );
    await verifier(
      () => AppRoutes.semaineChefSecteur(ctx(), csId: 'k', numSemaine: 44),
      'Semaine 44',
      ecran: SemaineCsScreen,
    );

    // Démarrer une visite crée un brouillon puis ouvre son écran d'étapes (numéro suivant : #218093).
    final f = AppRoutes.demarrerVisite(ctx(), 'm1');
    await tester.pumpAndSettle();
    expect(find.byType(VisiteScreen), findsOneWidget);
    expect(find.textContaining('Visite #218093'), findsOneWidget);
    AppRoutes.retourRacine(ctx());
    await tester.pumpAndSettle();
    await f;

    // Feuilles partagées.
    for (final ouvrir in <Future<void> Function()>[
      () => AppRoutes.detailLivraison(ctx(), 'CDE-2041'),
      () => AppRoutes.formulaireRdv(
        ctx(),
        cible: CiblePlanning.client,
        ref: 'm1',
        depuisFiche: true,
      ),
      () => AppRoutes.alertes(ctx()),
      () => AppRoutes.changerProfil(ctx()),
    ]) {
      final futur = ouvrir();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(195, 40)); // le voile ferme la feuille
      await tester.pumpAndSettle();
      await futur;
    }
  });

  testWidgets('allerOnglet vide la pile et change d’onglet', (tester) async {
    await lancerEtChoisir(tester, Role.cs);
    BuildContext ctx() =>
        tester.element(find.byType(ShellScreen, skipOffstage: false));
    unawaited(AppRoutes.ficheProspect(ctx(), 'p1'));
    await tester.pumpAndSettle();
    expect(find.byType(FicheProspectScreen), findsOneWidget);
    expect(find.text('Super U – Versailles'), findsWidgets);
    AppRoutes.allerOnglet(ctx(), OngletApp.prospects);
    await tester.pumpAndSettle();
    expect(find.byType(FicheProspectScreen), findsNothing);
    expect(find.text('Mes prospects'), findsWidgets);
  });
}
