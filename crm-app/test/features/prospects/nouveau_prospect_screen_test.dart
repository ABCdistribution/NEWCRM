import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav_bar.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/logic/vue_prospects.dart';
import 'package:crm_app/features/prospects/nouveau_prospect_screen.dart';
import 'package:crm_app/features/prospects/prospects_screen.dart';
import 'package:crm_app/features/prospects/state/prospects_state.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Formulaire « Nouveau prospect » : maquette `nouveauProspect` l.1718-1736 et création `np-creer` l.2005-2021.

/// Ordre des champs de saisie du formulaire.
const int _enseigne = 0,
    _raison = 1,
    _ville = 2,
    _cp = 3,
    _tel = 4,
    _email = 5,
    _proba = 6,
    _pot = 7;

/// Lance l'application avec ce profil, ouvre l'onglet Prospects puis le formulaire par le bouton flottant.
Future<void> _ouvrirFormulaire(WidgetTester tester, Role role) async {
  await lancerApp(tester, role);
  await tester.tap(
    find.descendant(
      of: find.byType(AppNavBar),
      matching: find.text('Prospects'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('＋ Nouveau prospect'));
  await tester.pumpAndSettle();
}

Future<void> _saisir(WidgetTester tester, int champ, String texte) =>
    tester.enterText(find.byType(TextFormField).at(champ), texte);

/// Ouvre une liste déroulante (repérée par son texte actuel) et choisit une option.
Future<void> _choisir(WidgetTester tester, String actuel, String option) async {
  await tester.ensureVisible(find.text(actuel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(actuel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _creer(WidgetTester tester) async {
  await tester.tap(find.text('＋ Créer le prospect'));
  await tester.pump();
}

ProviderContainer _store(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ShellScreen, skipOffstage: false)),
);

List<Prospect> _prospects(WidgetTester tester) =>
    _store(tester).read(prospectsProvider);

void main() {
  group('formulaire', () {
    testWidgets('connecté au CRM : pas de secteurs de démonstration', (
      tester,
    ) async {
      DemoTemps.reel = true;
      addTearDown(() => DemoTemps.reel = false);
      await pumpEcran(tester, const NouveauProspectScreen(), role: Role.cs);
      expect(find.text('Secteur'), findsNothing);
      expect(find.text('— aucun —'), findsNothing);
      expect(find.text('Source'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'sections, champs, valeurs par défaut et boutons de la maquette',
      (tester) async {
        await _ouvrirFormulaire(tester, Role.cs);
        expect(find.byType(NouveauProspectScreen), findsOneWidget);
        expect(find.text('Nouveau prospect'), findsOneWidget);
        expect(find.text('* champs obligatoires'), findsOneWidget);
        expect(find.text('IDENTITÉ'), findsOneWidget);
        expect(find.text('QUALIFICATION'), findsOneWidget);
        for (final l in [
          'Enseigne *',
          'Raison sociale *',
          'Ville',
          'Code postal',
          'Téléphone',
          'Email',
          'Secteur',
          'Source',
          'Classe du client',
          'Étape',
          'Probabilité (%)',
          'Potentiel CA/an (€)',
        ]) {
          expect(find.text(l), findsOneWidget, reason: l);
        }
        expect(find.text('Ex. Super Proxi Lunel'), findsOneWidget);
        expect(find.text('Ex. SUPERMARCHÉ DUPONT SAS'), findsOneWidget);
        for (final v in [
          '— aucun —',
          '— non précisée —',
          '— non renseignée —',
          'Nouveau',
        ]) {
          expect(find.text(v), findsOneWidget, reason: v);
        }
        expect(find.text('Annuler'), findsOneWidget);
        expect(find.text('＋ Créer le prospect'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(8));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('les listes proposent les choix de la maquette', (
      tester,
    ) async {
      await _ouvrirFormulaire(tester, Role.cs);
      for (final (actuel, options) in [
        (
          '— aucun —',
          ['Île-de-France', 'Normandie / Hauts-de-France', 'Sud-Est'],
        ),
        ('— non précisée —', ['Salon', 'Recommandation', 'Terrain', 'Web']),
        (
          '— non renseignée —',
          [for (final c in 'ABCDEFG'.split('')) 'Classe $c'],
        ),
        (
          'Nouveau',
          ['Contacté', 'Visite', 'Proposition', 'Négociation', 'Gagné'],
        ),
      ]) {
        await tester.ensureVisible(find.text(actuel));
        await tester.pumpAndSettle();
        await tester.tap(find.text(actuel));
        await tester.pumpAndSettle();
        for (final o in options) {
          expect(find.text(o), findsWidgets, reason: o);
        }
        await tester.tap(find.text(actuel).last); // referme en gardant le choix
        await tester.pumpAndSettle();
      }
    });

    testWidgets(
      '« Annuler » revient à la liste sans créer ; le formulaire repart vide',
      (tester) async {
        await _ouvrirFormulaire(tester, Role.cs);
        await _saisir(tester, _enseigne, 'Brouillon perdu');
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(find.text('Nouveau prospect'), findsNothing);
        expect(find.byType(ProspectsScreen), findsOneWidget);
        expect(_prospects(tester), hasLength(12));
        await tester.tap(find.text('＋ Nouveau prospect'));
        await tester.pumpAndSettle();
        expect(find.text('Brouillon perdu'), findsNothing);
      },
    );

    testWidgets('la flèche de retour du formulaire annule aussi', (
      tester,
    ) async {
      await _ouvrirFormulaire(tester, Role.cs);
      await tester.tap(find.byType(BoutonRetour));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau prospect'), findsNothing);
    });
  });

  group('validation', () {
    testWidgets('enseigne et raison sociale sont obligatoires', (tester) async {
      await _ouvrirFormulaire(tester, Role.cs);
      expect(find.text('Enseigne requise'), findsNothing);
      await _creer(tester);
      expect(find.text('Enseigne requise'), findsOneWidget);
      expect(find.text('Raison sociale requise'), findsOneWidget);
      expect(_prospects(tester), hasLength(12));
      expect(
        find.text('Prospect créé. Envoi dès que le réseau le permet.'),
        findsNothing,
      );
      // Des espaces seuls ne suffisent pas ; une erreur disparaît quand le champ est valide.
      await _saisir(tester, _enseigne, '   ');
      await _saisir(tester, _raison, 'Dupont SAS');
      await _creer(tester);
      expect(find.text('Enseigne requise'), findsOneWidget);
      expect(find.text('Raison sociale requise'), findsNothing);
      await _saisir(tester, _enseigne, 'Super Proxi');
      await _creer(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Enseigne requise'), findsNothing);
    });

    testWidgets('email, probabilité et potentiel sont contrôlés', (
      tester,
    ) async {
      await _ouvrirFormulaire(tester, Role.cs);
      await _saisir(tester, _enseigne, 'Super Proxi');
      await _saisir(tester, _raison, 'Dupont SAS');
      await _saisir(tester, _email, 'pas-un-email');
      await _saisir(tester, _proba, '150');
      await _saisir(tester, _pot, 'beaucoup');
      await _creer(tester);
      expect(find.text('Email invalide'), findsOneWidget);
      expect(find.text('Entre 0 et 100'), findsOneWidget);
      expect(find.text('Montant invalide'), findsOneWidget);
      expect(_prospects(tester), hasLength(12));
      // Autres valeurs refusées : probabilité décimale ou négative, montant avec espace.
      await _saisir(tester, _proba, '12,5');
      await _saisir(tester, _pot, '1 500');
      await _saisir(tester, _email, 'a@b');
      await _creer(tester);
      expect(find.text('Email invalide'), findsOneWidget);
      expect(find.text('Entre 0 et 100'), findsOneWidget);
      expect(find.text('Montant invalide'), findsOneWidget);
      // Valeurs limites acceptées : 0 %, 100 %, virgule décimale.
      await _saisir(tester, _email, 'contact@superproxi.fr');
      await _saisir(tester, _proba, '100');
      await _saisir(tester, _pot, '1500,5');
      await _creer(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(_prospects(tester), hasLength(13));
      expect(_prospects(tester).last.proba, 100);
    });
  });

  group('création', () {
    testWidgets(
      'chef de secteur : le prospect entre « en attente d’envoi » et la liste s’ouvre',
      (tester) async {
        await _ouvrirFormulaire(tester, Role.cs);
        // La page Prospects avait des filtres : la création les remet à zéro.
        _store(
          tester,
        ).read(vueProspectsProvider.notifier).choisir(VueProspects.tous);
        _store(
          tester,
        ).read(filtreGroupeProvider.notifier).definir(GroupeProspect.rdvPris);
        await _saisir(tester, _enseigne, '  Super Proxi  ');
        await _saisir(tester, _raison, 'Supermarché Dupont SAS');
        await _saisir(tester, _ville, 'Lunel');
        await _saisir(tester, _cp, '34400');
        await _saisir(tester, _tel, '0467000000');
        await _saisir(tester, _email, 'contact@superproxi.fr');
        await _saisir(tester, _pot, '4500');
        await _choisir(tester, '— aucun —', 'Sud-Est');
        await _choisir(tester, '— non précisée —', 'Salon');
        await _choisir(tester, '— non renseignée —', 'Classe B');
        await _choisir(tester, 'Nouveau', 'Négociation');
        await _creer(tester);
        await tester.pumpAndSettle();

        // Effets sur le store.
        final liste = _prospects(tester);
        expect(liste, hasLength(13));
        final p = liste.last;
        expect(p.id, 'p13');
        expect(p.nom, 'Super Proxi – Lunel');
        expect(p.raison, 'SUPERMARCHÉ DUPONT SAS');
        expect(p.classe, 'B');
        expect(p.cp, '34400 Lunel');
        expect(p.statut, StatutProspect.negociation);
        expect(p.proba, 60); // probabilité par défaut de l'étape
        expect(p.pot, 4.5); // 4 500 € = 4,5 k€
        expect(p.contact, isNull);
        expect(p.attente, isTrue);
        expect(
          p.secteurId,
          's1',
        ); // le secteur saisi n'a pas d'effet, comme dans la maquette
        expect(p.cs, 'Nadia H.');
        expect(p.timeline, hasLength(1));
        expect(p.timeline.first.titre, 'Fiche créée');
        expect(p.timeline.first.date, 'auj.');
        expect(p.timeline.first.detail, 'Source : salon · par Nadia H.');
        expect(p.timeline.first.icone, IconeEvenement.plus);
        expect(p.timeline.first.couleur, 0xFF6B7280);

        // Retour sur l'onglet Prospects, vue « Mes prospects », sans filtre, avec le toast.
        expect(find.text('Nouveau prospect'), findsNothing);
        expect(find.byType(ProspectsScreen), findsOneWidget);
        expect(
          find.text('Prospect créé. Envoi dès que le réseau le permet.'),
          findsOneWidget,
        );
        expect(_store(tester).read(vueProspectsProvider), VueProspects.liste);
        expect(_store(tester).read(filtreGroupeProvider), isNull);
        expect(find.text('Super Proxi – Lunel'), findsOneWidget);
        expect(find.text("📤 En attente d'envoi"), findsOneWidget);
        expect(find.text('Potentiel 4,5 k€/an'), findsOneWidget);
        expect(
          find.text('2 points de vente · potentiel 184,5 k€/an'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'sans les champs facultatifs : valeurs par défaut de la maquette',
      (tester) async {
        await _ouvrirFormulaire(tester, Role.cs);
        await _saisir(tester, _enseigne, 'Super Proxi');
        await _saisir(tester, _raison, 'Dupont');
        await _creer(tester);
        await tester.pump(const Duration(seconds: 3));
        final p = _prospects(tester).last;
        expect(p.nom, 'Super Proxi'); // pas de ville : pas de « – »
        expect(p.raison, 'DUPONT');
        expect(p.classe, '—');
        expect(p.cp, '');
        expect(p.statut, StatutProspect.nouveau);
        expect(p.proba, 10);
        expect(p.pot, 0);
        expect(p.timeline.first.detail, 'Source : non précisée · par Nadia H.');
      },
    );

    testWidgets('une probabilité saisie l’emporte sur celle de l’étape', (
      tester,
    ) async {
      await _ouvrirFormulaire(tester, Role.cs);
      await _saisir(tester, _enseigne, 'Super Proxi');
      await _saisir(tester, _raison, 'Dupont');
      await _saisir(tester, _proba, '85');
      await _choisir(tester, 'Nouveau', 'Gagné');
      await _creer(tester);
      await tester.pump(const Duration(seconds: 3));
      final p = _prospects(tester).last;
      expect(p.statut, StatutProspect.gagne);
      expect(p.proba, 85);
    });

    testWidgets(
      'le prospect créé est dans « Mes prospects » et son identifiant est unique',
      (tester) async {
        await _ouvrirFormulaire(tester, Role.cs);
        await _saisir(tester, _enseigne, 'Premier');
        await _saisir(tester, _raison, 'Premier SAS');
        await _creer(tester);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.tap(find.text('＋ Nouveau prospect'));
        await tester.pumpAndSettle();
        await _saisir(tester, _enseigne, 'Second');
        await _saisir(tester, _raison, 'Second SAS');
        await _creer(tester);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        final ids = _prospects(tester).map((p) => p.id).toList();
        expect(
          ids.toSet(),
          hasLength(ids.length),
        ); // p14 est pris : la maquette l'attribuait quand même
        expect(ids.last, 'p20');
        expect(find.text('Premier'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        expect(
          find.text('3 points de vente · potentiel 180 k€/an'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'un prospect en attente d’envoi n’ouvre pas de fiche depuis la liste',
      (tester) async {
        await _ouvrirFormulaire(tester, Role.cs);
        await _saisir(tester, _enseigne, 'Super Proxi');
        await _saisir(tester, _raison, 'Dupont');
        await _creer(tester);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Super Proxi'));
        await tester.pump();
        expect(
          find.text(
            "Ce prospect n'est pas encore envoyé : sa fiche s'ouvrira dès son envoi.",
          ),
          findsOneWidget,
        );
        expect(find.text('Étape de prospection'), findsNothing);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'directeur : identifiant à la suite des 23 prospects et signature « par Cindy R. »',
      (tester) async {
        await _ouvrirFormulaire(tester, Role.dir);
        await _saisir(tester, _enseigne, 'Super Proxi');
        await _saisir(tester, _raison, 'Dupont');
        await _saisir(tester, _ville, 'Lunel');
        await _choisir(tester, '— non précisée —', 'Recommandation');
        await _creer(tester);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        final p = _prospects(tester).last;
        expect(p.id, 'p24');
        expect(p.cs, 'Cindy R.');
        expect(
          p.timeline.first.detail,
          'Source : recommandation · par Cindy R.',
        );
        // Le directeur la retrouve dans « Mes prospects » (3 points de vente : 2 existants + celui-ci).
        expect(find.text('Super Proxi – Lunel'), findsOneWidget);
        expect(
          find.text('3 points de vente · potentiel 150 k€/an'),
          findsOneWidget,
        );
      },
    );
  });
}
