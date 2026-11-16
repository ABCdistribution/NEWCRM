import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/planning/formulaire_rdv_sheet.dart';
import 'package:crm_app/features/planning/planning_screen.dart';
import 'package:crm_app/features/planning/state/planning_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Formulaire de RDV : maquette `formulaire` l.1938-1957, `formulairePromoteur` l.1926-1937, `lireFormulaire`
/// l.1959-1971 et actions `f-cible`, `f-soiree`, `f-ok`, `f-suppr` l.2059-2070.

ProviderContainer conteneur(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(PlanningScreen, skipOffstage: false)),
);

CrmEtat etat(WidgetTester tester) => conteneur(tester).read(crmProvider);

/// Texte situé dans la feuille du formulaire (et non dans la page du planning dessous).
Finder dans(String texte) => find.descendant(
  of: find.byType(FormulaireRdvSheet),
  matching: find.text(texte),
);

/// Monte l'onglet Planning du rôle, prêt à ouvrir le formulaire par `AppRoutes`.
Future<void> monterPlanning(WidgetTester tester, Role role) =>
    pumpEcran(tester, const PlanningScreen(), role: role);

Future<void> ouvrir(
  WidgetTester tester, {
  CiblePlanning? cible,
  String? ref,
  bool depuisFiche = false,
  String? etapeId,
  String? planCible,
  int? semaine,
}) async {
  final ctx = tester.element(find.byType(PlanningScreen, skipOffstage: false));
  AppRoutes.formulaireRdv(
    ctx,
    cible: cible,
    ref: ref,
    depuisFiche: depuisFiche,
    etapeId: etapeId,
    planCible: planCible,
    semaine: semaine,
  );
  await tester.pumpAndSettle();
}

/// Ouvre la liste déroulante `index` (dans l'ordre d'affichage) et choisit l'option au texte `option`.
Future<void> choisir(WidgetTester tester, Finder liste, String option) async {
  await tester.ensureVisible(liste);
  await tester.tap(liste);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Saisit `texte` dans le champ placé sous l'étiquette `label`.
Future<void> ecrire(WidgetTester tester, String label, String texte) async {
  final colonne = find
      .ancestor(of: find.text(label), matching: find.byType(Column))
      .first;
  final champ = find.descendant(
    of: colonne,
    matching: find.byType(TextFormField),
  );
  await tester.ensureVisible(champ);
  await tester.enterText(champ, texte);
  await tester.pump();
}

void main() {
  group('nouvelle ligne sur son propre planning', () {
    testWidgets('champs du formulaire « Nouveau RDV » (chef de secteur)', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester);
      expect(find.text('Nouveau RDV'), findsOneWidget);
      for (final s in ['Prospect', 'Libre', 'ADM']) {
        expect(dans(s), findsOneWidget);
      }
      expect(
        dans('Client'),
        findsNWidgets(2),
      ); // le segment et l'étiquette de la liste
      expect(find.text('Adresse (facultatif)'), findsOneWidget);
      expect(find.text('Jour'), findsOneWidget);
      expect(find.text('Heure'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
      expect(find.text('Mer 4 nov.'), findsOneWidget);
      expect(find.text('Type de visite'), findsOneWidget);
      expect(find.text('Visite simple'), findsOneWidget);
      expect(find.text('Soirée étape'), findsOneWidget);
      expect(find.text('Observations'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Ajouter la ligne'), findsOneWidget);
      expect(find.text('Visite effectuée'), findsNothing);
      expect(find.text('Supprimer la ligne'), findsNothing);
      // Premier client du secteur par défaut.
      expect(find.text('Carrefour Market – Versailles'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('le jour proposé est celui du planning', (tester) async {
      await monterPlanning(tester, Role.cs);
      await tester.tap(find.text('Jeu'));
      await tester.pumpAndSettle();
      await ouvrir(tester);
      expect(find.text('Jeu 5 nov.'), findsOneWidget);
    });

    testWidgets('ajouter un client par défaut : ligne, toast, onglet Planning', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      final avant = etat(tester).etapes.length;
      await ouvrir(tester);
      await tester.tap(find.text('Ajouter la ligne'));
      await tester.pump();
      expect(find.text('Ligne ajoutée au planning.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final e = etat(tester).etapes;
      expect(e.length, avant + 1);
      final nouvelle = e.last;
      expect(nouvelle.cible, CiblePlanning.client);
      expect(nouvelle.ref, 'm1');
      expect(nouvelle.titre, 'Carrefour Market – Versailles');
      expect(nouvelle.jour, 2);
      expect(nouvelle.heure, '');
      expect(nouvelle.visite, isTrue);
      expect(nouvelle.rdv, isFalse);
      expect(nouvelle.fait, isFalse);
      expect(nouvelle.sem, isNull);
      expect(nouvelle.id, startsWith('e'));
      // La feuille est fermée, on est sur l'onglet Planning avec la ligne sans heure (« — »).
      expect(find.text('Nouveau RDV'), findsNothing);
      expect(conteneur(tester).read(ongletProvider), OngletApp.planning);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('3 RDV'), findsOneWidget);
    });

    testWidgets('ligne libre : le lieu est obligatoire', (tester) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester);
      await tester.tap(dans('Libre'));
      await tester.pumpAndSettle();
      expect(find.text('Client ou lieu'), findsOneWidget);
      expect(find.text('ex. Chez Marcel'), findsOneWidget);
      expect(find.text('Adresse (facultatif)'), findsOneWidget);
      // Le choix du client disparaît.
      expect(find.text('Carrefour Market – Versailles'), findsNothing);

      final avant = etat(tester).etapes.length;
      await toucher(tester, find.text('Ajouter la ligne'));
      expect(find.text('Indiquez le client ou le lieu.'), findsOneWidget);
      expect(etat(tester).etapes.length, avant);

      await ecrire(tester, 'Client ou lieu', '  Chez Marcel ');
      await toucher(tester, find.text('Ajouter la ligne'));
      final e = etat(tester).etapes.last;
      expect(e.cible, CiblePlanning.libre);
      expect(e.titre, 'Chez Marcel');
      expect(e.ref, isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Chez Marcel'), findsOneWidget);
      expect(find.text('Libre'), findsOneWidget);
    });

    testWidgets('ADM : pas de type, d’adresse ni de soirée', (tester) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester);
      await tester.tap(dans('ADM'));
      await tester.pumpAndSettle();
      expect(find.text('Type de visite'), findsNothing);
      expect(find.text('Soirée étape'), findsNothing);
      expect(find.text('Adresse (facultatif)'), findsNothing);
      expect(find.text('Jour'), findsOneWidget);
      expect(find.text('Observations'), findsOneWidget);
      await ecrire(tester, 'Observations', 'Notes de frais');
      await toucher(tester, find.text('Ajouter la ligne'));
      final e = etat(tester).etapes.last;
      expect(e.cible, CiblePlanning.adm);
      expect(e.titre, 'Administratif');
      expect(e.note, 'Notes de frais');
      // Comme la maquette, la ligne garde l'indicateur « visite » par défaut.
      expect(e.visite, isTrue);
    });

    testWidgets('prospect : liste des prospects du secteur', (tester) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester);
      await tester.tap(dans('Prospect'));
      await tester.pumpAndSettle();
      expect(dans('Super U – Versailles'), findsOneWidget);
      await toucher(tester, find.text('Ajouter la ligne'));
      final e = etat(tester).etapes.last;
      expect(e.cible, CiblePlanning.prospect);
      expect(e.ref, 'p1');
      expect(e.titre, 'Super U – Versailles');
    });

    testWidgets('type de visite : un seul indicateur à la fois', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester);
      await choisir(
        tester,
        find.byType(DropdownButtonFormField<String>).last,
        'Accompagnement',
      );
      await toucher(tester, find.text('Ajouter la ligne'));
      var e = etat(tester).etapes.last;
      expect(
        [e.visite, e.acc, e.rdv, e.appel, e.remp],
        [false, true, false, false, false],
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await ouvrir(tester);
      await choisir(
        tester,
        find.byType(DropdownButtonFormField<String>).last,
        'Appel téléphonique',
      );
      await toucher(tester, find.text('Ajouter la ligne'));
      e = etat(tester).etapes.last;
      expect(
        [e.visite, e.acc, e.rdv, e.appel, e.remp],
        [false, false, false, true, false],
      );
    });

    testWidgets('soirée étape : lieu et adresse obligatoires', (tester) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester);
      expect(find.text('Lieu de la soirée étape (obligatoire)'), findsNothing);
      await toucher(tester, find.text('Soirée étape'));
      expect(
        find.text('Lieu de la soirée étape (obligatoire)'),
        findsOneWidget,
      );
      expect(
        find.text('Adresse de la soirée étape (obligatoire)'),
        findsOneWidget,
      );

      await toucher(tester, find.text('Ajouter la ligne'));
      expect(
        find.text("Soirée étape : le lieu et l'adresse sont obligatoires."),
        findsOneWidget,
      );
      final avant = etat(tester).etapes.length;

      await ecrire(tester, 'Lieu de la soirée étape (obligatoire)', 'Lyon');
      await ecrire(
        tester,
        'Adresse de la soirée étape (obligatoire)',
        '2 rue Basse',
      );
      await toucher(tester, find.text('Ajouter la ligne'));
      final e = etat(tester).etapes.last;
      expect(etat(tester).etapes.length, avant + 1);
      expect(e.soiree, isTrue);
      expect(e.soireeLieu, 'Lyon');
      expect(e.soireeAdr, '2 rue Basse');
    });

    testWidgets('décocher la soirée efface le lieu et l’adresse', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester);
      await toucher(tester, find.text('Soirée étape'));
      await ecrire(tester, 'Lieu de la soirée étape (obligatoire)', 'Lyon');
      await toucher(tester, find.text('Soirée étape'));
      expect(find.text('Lieu de la soirée étape (obligatoire)'), findsNothing);
      await toucher(tester, find.text('Ajouter la ligne'));
      final e = etat(tester).etapes.last;
      expect(e.soiree, isFalse);
      expect(e.soireeLieu, '');
      expect(e.soireeAdr, '');
    });

    testWidgets('heure choisie dans le sélecteur d’heure', (tester) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester);
      await tester.tap(find.text('--:--'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      // Saisie au clavier : 08 h 45.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final champs = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(champs.at(0), '8');
      await tester.enterText(champs.at(1), '45');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('08:45'), findsOneWidget);
      await toucher(tester, find.text('Ajouter la ligne'));
      expect(etat(tester).etapes.last.heure, '08:45');
    });

    testWidgets('annuler ne change rien', (tester) async {
      await monterPlanning(tester, Role.cs);
      final avant = etat(tester).etapes;
      await ouvrir(tester);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau RDV'), findsNothing);
      expect(etat(tester).etapes, avant);
      expect(conteneur(tester).read(ongletProvider), OngletApp.accueil);
    });

    testWidgets('le directeur choisit parmi tous les clients de la région', (
      tester,
    ) async {
      await monterPlanning(tester, Role.dir);
      await ouvrir(tester);
      final liste = find.byType(DropdownButtonFormField<String>).first;
      await choisir(tester, liste, 'U Express – Paris');
      await toucher(tester, find.text('Ajouter la ligne'));
      final e = etat(tester).etapes.last;
      expect(e.ref, 'm5');
      expect(e.titre, 'U Express – Paris');
    });
  });

  group('modification et suppression', () {
    testWidgets('ligne ADM : « Visite effectuée » la passe en fait', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester, etapeId: 'e7');
      expect(find.text('Modifier la ligne'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Visite effectuée'), findsOneWidget);
      expect(find.text('Supprimer la ligne'), findsOneWidget);
      expect(
        find.text('Compte rendu'),
        findsNWidgets(2),
      ); // carte du planning et champ du formulaire
      await toucher(tester, find.text('Visite effectuée'));
      await toucher(tester, find.text('Enregistrer'));
      expect(find.text('Ligne enregistrée.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final e = etat(tester).etapeParId('e7')!;
      expect(e.fait, isTrue);
      expect(e.cible, CiblePlanning.adm);
      expect(etat(tester).etapes.length, 5);
      expect(find.text('Fait ✓'), findsOneWidget);
    });

    testWidgets('ligne prospect : champs préremplis, changer l’heure', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester, etapeId: 'e6');
      expect(dans('11:30'), findsOneWidget);
      expect(find.text('Mer 4 nov.'), findsOneWidget);
      expect(dans('RDV'), findsOneWidget);
      await tester.tap(dans('11:30'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final champs = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(champs.at(0), '10');
      await tester.enterText(champs.at(1), '15');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await toucher(tester, find.text('Enregistrer'));
      final e = etat(tester).etapeParId('e6')!;
      expect(e.heure, '10:15');
      expect(e.cible, CiblePlanning.prospect);
      expect(e.ref, 'p2');
      expect(e.rdv, isTrue);
      expect(e.visite, isFalse);
    });

    testWidgets('changer de jour déplace la ligne et le planning suit', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester, etapeId: 'e7');
      await choisir(
        tester,
        find.byType(DropdownButtonFormField<int>),
        'Ven 6 nov.',
      );
      await toucher(tester, find.text('Enregistrer'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(etat(tester).etapeParId('e7')!.jour, 4);
      // Le planning affiche maintenant le vendredi.
      expect(conteneur(tester).read(jourPlanningProvider), 4);
      expect(find.text('Administratif'), findsOneWidget);
    });

    testWidgets('supprimer la ligne', (tester) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(tester, etapeId: 'e7');
      await toucher(tester, find.text('Supprimer la ligne'));
      expect(find.text('Ligne supprimée.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(etat(tester).etapeParId('e7'), isNull);
      expect(etat(tester).etapes.length, 4);
      expect(find.text('Modifier la ligne'), findsNothing);
      expect(find.text('Administratif'), findsNothing);
    });

    testWidgets('modifier une ligne libre : le lieu est celui de la ligne', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      conteneur(tester)
          .read(crmProvider.notifier)
          .ajouterEtape(
            const EtapePlanning(
              id: 'lib1',
              jour: 2,
              heure: '12:00',
              cible: CiblePlanning.libre,
              titre: 'Chez Marcel',
            ),
          );
      await tester.pumpAndSettle();
      await ouvrir(tester, etapeId: 'lib1');
      expect(find.text('Chez Marcel'), findsWidgets);
      await ecrire(tester, 'Client ou lieu', 'Chez Paul');
      await toucher(tester, find.text('Enregistrer'));
      expect(etat(tester).etapeParId('lib1')!.titre, 'Chez Paul');
    });
  });

  group('depuis une fiche client ou prospect', () {
    testWidgets('client : titre « Planifier · … », cible masquée', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(
        tester,
        cible: CiblePlanning.client,
        ref: 'm4',
        depuisFiche: true,
      );
      expect(
        find.text('Planifier · Carrefour – Ivry-sur-Seine'),
        findsOneWidget,
      );
      expect(dans('Prospect'), findsNothing);
      expect(dans('Libre'), findsNothing);
      expect(dans('ADM'), findsNothing);
      expect(find.text('Adresse (facultatif)'), findsNothing);
      expect(find.text('Soirée étape'), findsNothing);
      expect(find.text('Type de visite'), findsOneWidget);
      expect(find.text('Jour'), findsOneWidget);
      expect(find.text('Heure'), findsOneWidget);
      expect(find.text('Observations'), findsOneWidget);

      await toucher(tester, find.text('Ajouter la ligne'));
      final e = etat(tester).etapes.last;
      expect(e.cible, CiblePlanning.client);
      expect(e.ref, 'm4');
      expect(e.titre, 'Carrefour – Ivry-sur-Seine');
      expect(e.visite, isTrue);
      expect(e.soiree, isFalse);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(conteneur(tester).read(ongletProvider), OngletApp.planning);
    });

    testWidgets('prospect', (tester) async {
      await monterPlanning(tester, Role.cs);
      await ouvrir(
        tester,
        cible: CiblePlanning.prospect,
        ref: 'p1',
        depuisFiche: true,
      );
      expect(find.text('Planifier · Super U – Versailles'), findsOneWidget);
      await choisir(
        tester,
        find.byType(DropdownButtonFormField<String>).last,
        'RDV',
      );
      await toucher(tester, find.text('Ajouter la ligne'));
      final e = etat(tester).etapes.last;
      expect(e.cible, CiblePlanning.prospect);
      expect(e.ref, 'p1');
      expect(e.rdv, isTrue);
      expect(e.visite, isFalse);
    });
  });

  group('planning d’un promoteur composé par l’encadrement', () {
    testWidgets('formulaire « Planifier une visite client · Léa P. »', (
      tester,
    ) async {
      await monterPlanning(tester, Role.dir);
      await ouvrir(tester, planCible: 'Léa P.', semaine: 0);
      expect(find.text('Planifier une visite client · Léa P.'), findsOneWidget);
      expect(dans('Client'), findsOneWidget);
      expect(find.text('Jour'), findsOneWidget);
      expect(find.text('Heure'), findsOneWidget);
      expect(
        find.text('Consigne pour le promoteur (facultatif)'),
        findsOneWidget,
      );
      expect(find.text('Ajouter la visite'), findsOneWidget);
      // Pas de cible, d'adresse, de type ni de soirée.
      expect(dans('Prospect'), findsNothing);
      expect(find.text('Type de visite'), findsNothing);
      expect(find.text('Soirée étape'), findsNothing);
      expect(find.text('Supprimer la visite'), findsNothing);
      // Clients des visites de Léa P. : Rouen en premier.
      expect(find.text('Carrefour Market – Rouen'), findsWidgets);
      expect(find.text('Mer 4 nov.'), findsOneWidget);
    });

    testWidgets('ajouter la visite : planning de Léa P., pas le sien', (
      tester,
    ) async {
      await monterPlanning(tester, Role.dir);
      final siennes = etat(tester).etapes;
      final avant = etat(tester).planDe('Léa P.').length;
      await ouvrir(tester, planCible: 'Léa P.', semaine: 0);
      await ecrire(
        tester,
        'Consigne pour le promoteur (facultatif)',
        'Relever les facings',
      );
      await toucher(tester, find.text('Ajouter la visite'));
      expect(find.text('Ligne ajoutée au planning.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final plan = etat(tester).planDe('Léa P.');
      expect(plan.length, avant + 1);
      final e = plan.last;
      expect(e.cible, CiblePlanning.client);
      expect(e.ref, 'm2');
      expect(e.titre, 'Carrefour Market – Rouen');
      expect(e.visite, isTrue);
      expect(e.rdv, isFalse);
      expect(e.sem, 0);
      expect(e.note, 'Relever les facings');
      expect(etat(tester).etapes, siennes);
      // La feuille se ferme sans changer d'onglet.
      expect(find.text('Planifier une visite client · Léa P.'), findsNothing);
      expect(conteneur(tester).read(ongletProvider), OngletApp.accueil);
    });

    testWidgets('semaine suivante : dates de la semaine 46', (tester) async {
      await monterPlanning(tester, Role.dir);
      await ouvrir(tester, planCible: 'Léa P.', semaine: 1);
      expect(find.text('Mer 11 nov.'), findsOneWidget);
      await toucher(tester, find.text('Ajouter la visite'));
      expect(etat(tester).planDe('Léa P.').last.sem, 1);
    });

    testWidgets('modifier puis supprimer une visite', (tester) async {
      await monterPlanning(tester, Role.dir);
      final premiere = etat(tester).planDe('Léa P.').first;
      await ouvrir(tester, planCible: 'Léa P.', etapeId: premiere.id);
      expect(find.text('Modifier la visite · Léa P.'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      await ecrire(
        tester,
        'Consigne pour le promoteur (facultatif)',
        'Nouvelle consigne',
      );
      await toucher(tester, find.text('Enregistrer'));
      expect(etat(tester).planDe('Léa P.').first.note, 'Nouvelle consigne');
      // La ligne déjà faite le reste.
      expect(etat(tester).planDe('Léa P.').first.fait, isTrue);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      final avant = etat(tester).planDe('Léa P.').length;
      await ouvrir(tester, planCible: 'Léa P.', etapeId: premiere.id);
      await toucher(tester, find.text('Supprimer la visite'));
      expect(etat(tester).planDe('Léa P.').length, avant - 1);
      expect(
        etat(tester).planDe('Léa P.').where((e) => e.id == premiere.id),
        isEmpty,
      );
    });

    testWidgets('le planning d’un chef de secteur se compose de même', (
      tester,
    ) async {
      await monterPlanning(tester, Role.dir);
      await ouvrir(tester, planCible: 'Karim B.', semaine: 0);
      expect(
        find.text('Planifier une visite client · Karim B.'),
        findsOneWidget,
      );
      await toucher(tester, find.text('Ajouter la visite'));
      expect(etat(tester).planDe('Karim B.').last.sem, 0);
    });
  });

  group('semaine validée', () {
    testWidgets('le formulaire ne s’ouvre pas : message de verrouillage', (
      tester,
    ) async {
      await monterPlanning(tester, Role.cs);
      conteneur(
        tester,
      ).read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
      await tester.pumpAndSettle();
      await ouvrir(tester);
      expect(find.text('Nouveau RDV'), findsNothing);
      expect(
        find.text("Rapport validé : plus rien n'est modifiable."),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('modifier une ligne est aussi verrouillé', (tester) async {
      await monterPlanning(tester, Role.cs);
      conteneur(
        tester,
      ).read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Administratif'));
      await tester.pump();
      expect(find.text('Modifier la ligne'), findsNothing);
      expect(
        find.text("Rapport validé : plus rien n'est modifiable."),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
