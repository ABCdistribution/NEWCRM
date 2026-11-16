import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/equipe/chef_secteur_screen.dart';
import 'package:crm_app/features/equipe/equipe_screen.dart';
import 'package:crm_app/features/equipe/promoteur_screen.dart';
import 'package:crm_app/features/equipe/secteur_screen.dart';
import 'package:crm_app/features/equipe/semaine_cs_screen.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Parcours de bout en bout dans l'application complète : menu « + », puis les écrans de l'équipe empilés.
final _boutonPlus = find.descendant(
  of: find.byType(AppNavBar),
  matching: find.bySemanticsLabel('Plus'),
);

Future<void> _allerDansMenu(WidgetTester tester, String libelle) async {
  await tester.tap(_boutonPlus);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(MenuPlus), matching: find.text(libelle)),
  );
  await tester.pumpAndSettle();
}

Future<void> _toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

ProviderContainer _conteneur(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ShellScreen, skipOffstage: false)),
);

void main() {
  testWidgets('directeur : Équipe, chef de secteur, semaine, retour', (
    tester,
  ) async {
    await lancerApp(tester, Role.dir);
    await _allerDansMenu(tester, 'Équipe');
    expect(find.byType(EquipeScreen), findsOneWidget);
    expect(find.text('3 chefs de secteur · 8 promoteurs'), findsOneWidget);

    await _toucher(tester, find.text('Nadia H.'));
    expect(find.byType(ChefSecteurScreen), findsOneWidget);
    // L'écran empilé recouvre la barre de navigation.
    expect(find.byType(AppNavBar), findsNothing);

    await _toucher(tester, find.text('Semaine 45 · en cours'));
    expect(find.byType(SemaineCsScreen), findsOneWidget);
    expect(find.text('Prévu 5 · Réalisé 3 (60 %)'), findsOneWidget);

    await _toucher(tester, find.byType(BoutonRetour));
    expect(find.byType(SemaineCsScreen), findsNothing);
    expect(find.byType(ChefSecteurScreen), findsOneWidget);

    // La page défile avec son entête : on remonte jusqu'au bouton retour.
    await _toucher(tester, find.byType(BoutonRetour));
    expect(find.byType(ChefSecteurScreen), findsNothing);
    expect(find.byType(AppNavBar), findsOneWidget);
    expect(find.byType(EquipeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'directeur : promoteurs d’un chef de secteur puis page promoteur',
    (tester) async {
      await lancerApp(tester, Role.dir);
      await _allerDansMenu(tester, 'Équipe');
      await _toucher(tester, find.text('Karim B.'));
      await tester.tap(find.text('Promoteurs'));
      await tester.pumpAndSettle();
      await _toucher(tester, find.text('Yanis R.'));
      expect(find.byType(PromoteurScreen), findsOneWidget);
      expect(find.text('Promoteur · 3 clients'), findsOneWidget);
      expect(find.text('10/10'), findsOneWidget);
      // Retour à la racine : on retrouve la barre de navigation.
      AppRoutes.retourRacine(tester.element(find.byType(PromoteurScreen)));
      await tester.pumpAndSettle();
      expect(find.byType(PromoteurScreen), findsNothing);
      expect(find.byType(AppNavBar), findsOneWidget);
    },
  );

  testWidgets(
    'la ligne ajoutée au planning du directeur apparaît chez Nadia H.',
    (tester) async {
      await lancerApp(tester, Role.dir);
      _conteneur(tester)
          .read(crmProvider.notifier)
          .ajouterEtape(
            const EtapePlanning(
              id: 'zz3',
              jour: 2,
              heure: '17:45',
              cible: CiblePlanning.libre,
              titre: 'Réunion de région',
            ),
          );
      await tester.pumpAndSettle();
      await _allerDansMenu(tester, 'Équipe');
      await _toucher(tester, find.text('Nadia H.'));
      // Le planning de Nadia H. est celui du profil (maquette : `planOf`).
      expect(find.text('Réunion de région'), findsOneWidget);
      expect(find.text('17:45'), findsOneWidget);
      // Mercredi passe de 3 à 4 lignes.
      expect(find.text('4 RDV'), findsOneWidget);
    },
  );

  testWidgets('chef de secteur : Équipe liste ses promoteurs', (tester) async {
    await lancerApp(tester, Role.cs);
    await _allerDansMenu(tester, 'Équipe');
    expect(find.text('3 promoteurs · Île-de-France'), findsOneWidget);
    await _toucher(tester, find.text('Amine K.'));
    expect(find.byType(PromoteurScreen), findsOneWidget);
    expect(find.text('9/9'), findsOneWidget);
    expect(find.text('Vous pouvez modifier ce planning.'), findsOneWidget);
  });

  testWidgets('chef de secteur : Visites et Commandes du secteur', (
    tester,
  ) async {
    await lancerApp(tester, Role.cs);
    await _allerDansMenu(tester, 'Visites');
    expect(find.byType(SecteurScreen), findsOneWidget);
    expect(
      find.text('24 visites · les plus récentes en premier'),
      findsOneWidget,
    );
    // La feuille des filtres s'ouvre au-dessus de la barre de navigation.
    await tester.tap(find.byType(BoutonFiltre));
    await tester.pumpAndSettle();
    expect(find.text('Toutes les visites de mon secteur'), findsOneWidget);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(find.text('Toutes les visites de mon secteur'), findsNothing);

    await _allerDansMenu(tester, 'Commandes');
    expect(
      find.text('13 commandes · les plus récentes en premier'),
      findsOneWidget,
    );
    expect(find.text('Commandes du secteur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le directeur n’a pas les onglets du secteur', (tester) async {
    await lancerApp(tester, Role.dir);
    await tester.tap(_boutonPlus);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(MenuPlus),
        matching: find.text('Commandes'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(MenuPlus), matching: find.text('Équipe')),
      findsOneWidget,
    );
  });
}
