import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/fiche_prospect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Fiche d'un prospect : maquette `fichePros` l.1776-1792 et `ongletMagasinsProspect` l.1768-1775.
Future<void> _ouvrir(WidgetTester tester, String id, Role role) =>
    pumpEcran(tester, FicheProspectScreen(prospectId: id), role: role);

ProviderContainer _store(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FicheProspectScreen)));

/// Les actions rapides de l'entête (leurs libellés se retrouvent ailleurs : « Note » dans la timeline).
Finder _action(String libelle) => find.descendant(
  of: find.byType(RangeeActions),
  matching: find.text(libelle),
);

/// Fait défiler jusqu'au widget puis le touche (le corps de la fiche dépasse l'écran de 780 dp).
Future<void> _toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

void main() {
  group('entête et carte d’étape', () {
    testWidgets('Super U – Versailles vu par le chef de secteur', (
      tester,
    ) async {
      await _ouvrir(tester, 'p1', Role.cs);
      expect(find.text('Prospect · En négo'), findsOneWidget);
      expect(find.text('Super U – Versailles'), findsOneWidget);
      expect(
        find.text(
          'SUPER U VERSAILLES · classe A · 78000 Versailles · Resp. Nadia H.',
        ),
        findsOneWidget,
      );
      for (final a in ['Appeler', 'Mail', 'Itinéraire', 'Planifier', 'Note']) {
        expect(_action(a), findsOneWidget, reason: a);
      }
      expect(find.text('Étape de prospection'), findsOneWidget);
      expect(find.text('Probabilité 60 %'), findsOneWidget);
      for (final n in ['À contacter', 'RDV pris', 'En négo', 'Référencé']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(
        find.text('Fiche créée'),
        findsNWidgets(2),
      ); // barre d'étapes et timeline
      expect(find.text('Potentiel 180 k€/an'), findsOneWidget);
      expect(find.text("Changer d'étape"), findsOneWidget);
      expect(find.text('Passer en client'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quatre segments sur cinq pour « En négociation »', (
      tester,
    ) async {
      await _ouvrir(tester, 'p1', Role.cs);
      expect(tester.widget<EtapesBarre>(find.byType(EtapesBarre)).segments, 4);
    });

    testWidgets('cinq segments pour « Référencé »', (tester) async {
      await _ouvrir(tester, 'p4', Role.dir);
      expect(tester.widget<EtapesBarre>(find.byType(EtapesBarre)).segments, 5);
    });

    testWidgets(
      'un prospect déjà référencé n’a pas « Passer en client » et affiche son contact',
      (tester) async {
        await _ouvrir(tester, 'p4', Role.dir);
        expect(find.text('Prospect · Référencé'), findsOneWidget);
        expect(find.text('Passer en client'), findsNothing);
        expect(find.text("Changer d'étape"), findsOneWidget);
        expect(find.text('Probabilité 100 %'), findsOneWidget);
        expect(
          find.text('Potentiel 150 k€/an   Contact M. Diallo'),
          findsOneWidget,
        );
        expect(
          find.text(
            'U EXPRESS ROUEN · classe C · 76000 Rouen · Resp. Karim B.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('le directeur voit les prospects de toute la région', (
      tester,
    ) async {
      await _ouvrir(tester, 'p3', Role.dir);
      expect(find.text('Prospect · RDV pris'), findsOneWidget);
      expect(find.text('Auchan – Rouen'), findsOneWidget);
      expect(find.text('Probabilité 40 %'), findsOneWidget);
    });

    testWidgets('un prospect inconnu ne casse pas l’écran', (tester) async {
      await _ouvrir(tester, 'p99', Role.cs);
      expect(find.text('Prospect introuvable.'), findsOneWidget);
    });
  });

  group('timeline', () {
    testWidgets('le RDV du planning remplace « RDV de négociation prévu »', (
      tester,
    ) async {
      await _ouvrir(tester, 'p1', Role.cs);
      expect(find.text('Timeline de prospection'), findsOneWidget);
      expect(find.text('depuis le 2 oct.'), findsOneWidget);
      expect(find.text('RDV prévu'), findsOneWidget);
      expect(find.text('Jeu 10:00'), findsOneWidget);
      expect(
        find.text('Négociation'),
        findsOneWidget,
      ); // note de la ligne de planning
      expect(find.text('RDV de négociation prévu'), findsNothing);
      for (final t in [
        'Visite · présentation gamme',
        'Étape → En négo',
        'Appel · prise de RDV',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Source : terrain · par Nadia H.'), findsOneWidget);
      // Le RDV prévu passe avant l'historique.
      expect(
        tester.getTopLeft(find.text('RDV prévu')).dy,
        lessThan(
          tester.getTopLeft(find.text('Visite · présentation gamme')).dy,
        ),
      );
    });

    testWidgets('sans RDV au planning, la timeline reste celle du prospect', (
      tester,
    ) async {
      await _ouvrir(tester, 'p5', Role.cs);
      expect(find.text('RDV prévu'), findsNothing);
      expect(find.text('Visite · présentation gamme'), findsOneWidget);
      expect(find.text("Demande un budget d'implantation"), findsOneWidget);
    });

    testWidgets(
      'un RDV sans note affiche « Visite planifiée dans mon planning »',
      (tester) async {
        await _ouvrir(tester, 'p2', Role.cs);
        expect(find.text('RDV prévu'), findsOneWidget);
        expect(find.text('Mer 11:30'), findsOneWidget);
        expect(find.text('Visite planifiée dans mon planning'), findsOneWidget);
      },
    );

    testWidgets('un RDV déjà fait n’est plus « prévu »', (tester) async {
      await _ouvrir(tester, 'p3', Role.dir);
      expect(find.text('RDV prévu'), findsNothing);
      expect(find.text('Appel · prise de RDV'), findsOneWidget);
    });
  });

  group('onglet Magasins', () {
    testWidgets(
      'Super U : deux clients hors secteur et six magasins à prospecter',
      (tester) async {
        await _ouvrir(tester, 'p1', Role.cs);
        await tester.tap(find.text('Magasins'));
        await tester.pumpAndSettle();
        expect(find.text('Timeline de prospection'), findsNothing);
        expect(find.text("Magasins de l'enseigne"), findsOneWidget);
        expect(find.text('8 points de vente'), findsOneWidget);
        expect(
          find.text('2 clients · 0 prospects · 6 à prospecter'),
          findsOneWidget,
        );
        expect(find.text('Super U – Amiens'), findsOneWidget);
        expect(
          find.text('82 avenue Jean Jaurès, 80000 Amiens · Classe C'),
          findsOneWidget,
        );
        expect(find.text('Super U – Avignon'), findsOneWidget);
        expect(find.text('84000 Avignon · Classe E'), findsOneWidget);
        expect(find.text('Client'), findsNWidgets(2));
        expect(find.text('À prospecter'), findsNWidgets(6));
        // Villes proposées, décalées de la longueur de l'identifiant (« p1 » : 2).
        for (final (ville, cp) in [
          ('Pont-Audemer', '27500'),
          ('Saint-Lô', '50000'),
          ('Bayeux', '14400'),
          ('Fécamp', '76400'),
          ('Le Havre', '76600'),
          ('Dieppe', '76200'),
        ]) {
          expect(find.text('Super U – $ville'), findsOneWidget, reason: ville);
          expect(find.text(cp), findsOneWidget, reason: cp);
        }
        expect(
          find.text(
            "Liste fournie par l'API · aucune action possible sur les magasins pour l'instant.",
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Carrefour HM : clients, prospects de l’enseigne et villes à prospecter',
      (tester) async {
        await _ouvrir(tester, 'p5', Role.cs);
        await tester.tap(find.text('Magasins'));
        await tester.pumpAndSettle();
        expect(find.text('8 points de vente'), findsOneWidget);
        expect(
          find.text('2 clients · 2 prospects · 4 à prospecter'),
          findsOneWidget,
        );
        expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
        expect(find.text('Carrefour – Paris'), findsOneWidget);
        expect(find.text('Carrefour HM – Cergy'), findsOneWidget);
        expect(find.text('75011 Paris'), findsOneWidget);
        expect(find.text('Carrefour HM – Pont-Audemer'), findsOneWidget);
        expect(find.text('Carrefour HM – Fécamp'), findsOneWidget);
      },
    );

    testWidgets('un prospect de l’enseigne ouvre sa fiche, puis on revient', (
      tester,
    ) async {
      await _ouvrir(tester, 'p5', Role.cs);
      await tester.tap(find.text('Magasins'));
      await tester.pumpAndSettle();
      await _toucher(tester, find.text('Carrefour HM – Cergy'));
      await tester.pumpAndSettle();
      expect(find.text('Prospect · À contacter'), findsOneWidget);
      expect(
        find.text(
          'CARREFOUR HM CERGY · classe B · 95000 Cergy · Resp. Nadia H.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(BoutonRetour).first);
      await tester.pumpAndSettle();
      expect(find.text("Magasins de l'enseigne"), findsOneWidget);
    });

    testWidgets(
      'un client de l’enseigne ouvre sa fiche, un magasin à prospecter non',
      (tester) async {
        await _ouvrir(tester, 'p5', Role.cs);
        await tester.tap(find.text('Magasins'));
        await tester.pumpAndSettle();
        await _toucher(tester, find.text('Carrefour HM – Fécamp'));
        await tester.pumpAndSettle();
        expect(
          find.text("Magasins de l'enseigne"),
          findsOneWidget,
        ); // aucune action
        await _toucher(tester, find.text('Carrefour Market – Versailles'));
        await tester.pumpAndSettle();
        expect(
          find.text("Magasins de l'enseigne"),
          findsNothing,
        ); // la fiche client est ouverte
      },
    );

    testWidgets(
      'un prospect de l’enseigne en attente d’envoi n’ouvre pas de fiche',
      (tester) async {
        await _ouvrir(tester, 'p5', Role.cs);
        _store(tester)
            .read(crmProvider.notifier)
            .majProspect('p9', (p) => p.copyWith(attente: true));
        await tester.tap(find.text('Magasins'));
        await tester.pumpAndSettle();
        await _toucher(tester, find.text('Carrefour HM – Cergy'));
        await tester.pump();
        expect(
          find.text(
            "Ce prospect n'est pas encore envoyé : sa fiche s'ouvrira dès son envoi.",
          ),
          findsOneWidget,
        );
        expect(find.text("Magasins de l'enseigne"), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('on revient à la timeline en touchant « Timeline »', (
      tester,
    ) async {
      await _ouvrir(tester, 'p1', Role.cs);
      await tester.tap(find.text('Magasins'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      expect(find.text('Timeline de prospection'), findsOneWidget);
      expect(find.text("Magasins de l'enseigne"), findsNothing);
    });
  });

  group('actions', () {
    testWidgets('Appeler, Mail et Itinéraire affichent leur message', (
      tester,
    ) async {
      await _ouvrir(tester, 'p1', Role.cs);
      for (final (action, message) in [
        ('Appeler', "Lancement de l'appel téléphonique."),
        (
          'Mail',
          'Ouverture de la messagerie : nouveau mail au contact du client.',
        ),
        (
          'Itinéraire',
          "Ouverture de l'application de cartes (adresse renseignée).",
        ),
      ]) {
        await tester.tap(_action(action));
        await tester.pump();
        expect(find.text(message), findsOneWidget, reason: action);
      }
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.text("Ouverture de l'application de cartes (adresse renseignée)."),
        findsNothing,
      );
    });

    testWidgets('Planifier ouvre le formulaire de planning, Note le dialogue', (
      tester,
    ) async {
      await _ouvrir(tester, 'p1', Role.cs);
      await tester.tap(_action('Planifier'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      await tester.tap(_action('Note'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle note'), findsOneWidget);
    });

    testWidgets('les deux boutons de la barre basse ouvrent leur feuille', (
      tester,
    ) async {
      await _ouvrir(tester, 'p1', Role.cs);
      await tester.tap(find.text("Changer d'étape").last);
      await tester.pumpAndSettle();
      expect(find.text('En négociation'), findsOneWidget);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passer en client'));
      await tester.pumpAndSettle();
      expect(find.text('Passer en client ?'), findsOneWidget);
    });
  });
}
