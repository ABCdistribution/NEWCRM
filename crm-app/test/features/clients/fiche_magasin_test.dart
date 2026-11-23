import 'package:crm_app/core/data/fiche_client.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/fiche_client_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/clients/fiche_magasin_screen.dart';
import 'package:crm_app/features/clients/note_client_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../../support/lanceur_factice.dart';
import 'aide_clients.dart';

/// Fiche d'un client : `ficheMag` l.1808-1824, `blocObjMag` l.1800-1804, actions l.1752-1755 et l.1987-2003.
/// Client du CRM (non démo) : seules les données qu'il porte sont utilisables.
const _magasinCrm = Magasin(
  id: 'cr',
  nom: 'Auchan – Lyon',
  statut: 'Client actif',
  classe: 'B',
  adresse: '5 rue Haute, 69000 Lyon',
  ca: '—',
  evo: '',
  cde: '—',
  cdeDate: '',
  visites: 0,
  objectif: 0,
  reel: true,
);

void main() {
  Future<void> ouvrir(WidgetTester tester, Role role, String id) =>
      pumpEcran(tester, FicheMagasinScreen(magasinId: id), role: role);

  Finder libelleAction(String l) =>
      find.descendant(of: find.byType(RangeeActions), matching: find.text(l));

  Future<void> tapAction(WidgetTester tester, String l) async {
    await tester.tap(libelleAction(l));
    await tester.pump();
  }

  Future<void> choisirOnglet(WidgetTester tester, String l) async {
    // Les onglets sont sous les chiffres clés : la page défile.
    final onglet = find.descendant(
      of: find.byType(OngletsPills),
      matching: find.text(l),
    );
    await tester.ensureVisible(onglet);
    await tester.pumpAndSettle();
    await tester.tap(onglet);
    await tester.pumpAndSettle();
  }

  group('promoteur : Carrefour Market – Versailles (m1)', () {
    testWidgets('entête, actions, chiffres clés et objectifs', (tester) async {
      await ouvrir(tester, Role.promoteur, 'm1');
      expect(find.text('Client · À relancer'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(
        find.text('Classe A++ · 104 avenue des Champs, 78000 Versailles'),
        findsOneWidget,
      );
      // `actionsSales` : Appeler, Mail, Itinéraire, ＋ Visite (quatre boutons, pas de rangée de six).
      expect(libelleAction('Appeler'), findsOneWidget);
      expect(libelleAction('Mail'), findsOneWidget);
      expect(libelleAction('Itinéraire'), findsOneWidget);
      expect(libelleAction('＋ Visite'), findsOneWidget);
      expect(libelleAction('Planifier'), findsNothing);
      expect(libelleAction('Commande'), findsNothing);
      expect(libelleAction('Visite'), findsNothing);
      // KPI.
      expect(find.text('CA 12 mois'), findsOneWidget);
      expect(find.text('29,4 k€'), findsOneWidget);
      expect(find.text('−14 %'), findsOneWidget);
      expect(find.text('Dernière cde'), findsOneWidget);
      expect(find.text('958 €'), findsOneWidget);
      // « 26 oct. » : sous la dernière commande des chiffres clés et date de la commande CDE-2027 du suivi.
      expect(find.text('26 oct.'), findsNWidgets(2));
      expect(find.text('Visites / mois'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('obj. 2'), findsOneWidget);
      // Objectifs et OP.
      expect(find.text('CA / objectif du mois'), findsOneWidget);
      expect(find.text('Opérations promotionnelles (OP)'), findsOneWidget);
      expect(find.text('2 nov. → 15 nov.'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      // Barre basse.
      expect(find.text('Ajouter une note'), findsOneWidget);
      expect(find.text('Démarrer une visite'), findsOneWidget);
      expect(find.text('Planifier une visite'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('objectif du mois et OP, valeurs de la formule de la maquette', (
      tester,
    ) async {
      // m1 : n = 158, objectif 3 000 + (158 % 9) × 450 = 5 250, CA 4 570 (87 %), OP 1 et 3.
      await ouvrir(tester, Role.promoteur, 'm1');
      expect(find.text('${eur(4570)} / ${eur(5250)}'), findsOneWidget);
      expect(find.text('87 %'), findsOneWidget);
      expect(find.text('Remise -20 % gamme soin'), findsOneWidget);
      expect(find.text('2 achetés = 1 offert maquillage'), findsOneWidget);
      expect(find.text('1 oct. → 31 oct.'), findsOneWidget);
      expect(find.text('Terminée'), findsOneWidget);
      expect(find.text('Tête de gondole PEM Noël'), findsNothing);
    });

    testWidgets('les trois OP quand elles s’appliquent, À venir en bleu', (
      tester,
    ) async {
      // m5 : n = 162 → objectif 3 000, CA 1 890 (63 %), trois OP.
      await ouvrir(tester, Role.promoteur, 'm5');
      expect(find.text('63 %'), findsOneWidget);
      expect(find.text('Tête de gondole PEM Noël'), findsOneWidget);
      expect(find.text('16 nov. → 6 déc.'), findsOneWidget);
      expect(find.text('À venir'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Terminée'), findsOneWidget);
    });

    testWidgets('onglets : Aperçu, Contacts, Commandes, Notes', (tester) async {
      await ouvrir(tester, Role.promoteur, 'm1');
      for (final l in ['Aperçu', 'Contacts', 'Commandes', 'Notes']) {
        expect(
          find.descendant(
            of: find.byType(OngletsPills),
            matching: find.text(l),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Suivi'), findsNothing);
      expect(find.text('Infos'), findsNothing);
    });

    testWidgets('« Aperçu » : suivi avec la dernière commande du store', (
      tester,
    ) async {
      await ouvrir(tester, Role.promoteur, 'm1');
      expect(find.text('Visite chef de secteur prévue'), findsOneWidget);
      expect(find.text('lun. 2 nov.'), findsOneWidget);
      expect(
        find.text('Relance baisse de CA avec le chef de rayon'),
        findsOneWidget,
      );
      // Commande la plus récente de m1 : CDE-2027 (pas livrée).
      expect(find.text('Commande CDE-2027'), findsOneWidget);
      expect(find.text('958,70 € HT · Pas livrée'), findsOneWidget);
      expect(find.text('Alerte rupture'), findsOneWidget);
      expect(find.text('Sérum éclat 30 ml absent du rayon'), findsOneWidget);
      expect(find.text('Visite promoteur'), findsOneWidget);
      expect(
        find.text('Relevé linéaire · 12 facings · photos'),
        findsOneWidget,
      );
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('10 sept.'), findsOneWidget);
    });

    testWidgets('une nouvelle commande apparaît sur la fiche', (tester) async {
      await ouvrir(tester, Role.promoteur, 'm1');
      conteneurDe(tester)
          .read(crmProvider.notifier)
          .ajouterCommande(
            const Commande(
              id: 'CDE-2042',
              magasinId: 'm1',
              date: '4 nov.',
              ht: '210,00 €',
              lignes: 2,
              statut: StatutLivraison.pasLivree,
              eta: 'lun. 9 nov.',
              colis: 1,
              evenements: [],
              src: 'Appli',
            ),
          );
      await tester.pumpAndSettle();
      expect(find.text('Commande CDE-2042'), findsOneWidget);
      expect(find.text('210,00 € HT · Pas livrée'), findsOneWidget);
    });

    testWidgets('« Commandes » : de la plus récente à la plus ancienne', (
      tester,
    ) async {
      await ouvrir(tester, Role.promoteur, 'm1');
      await choisirOnglet(tester, 'Commandes');
      expect(find.text('958,70 € HT'), findsOneWidget);
      expect(find.text('CDE-2027 · 26 oct. · EDI'), findsOneWidget);
      expect(find.text('1 420,00 € HT'), findsOneWidget);
      expect(find.text('CDE-1984 · 5 oct.'), findsOneWidget);
      expect(find.text('1 105,40 € HT'), findsOneWidget);
      expect(find.text('CDE-1930 · 14 sept. · EDI'), findsOneWidget);
      expect(find.text('Pas livrée'), findsOneWidget);
      expect(find.text('Livrée'), findsNWidgets(2));
      final y2027 = tester.getTopLeft(find.text('958,70 € HT')).dy;
      final y1984 = tester.getTopLeft(find.text('1 420,00 € HT')).dy;
      final y1930 = tester.getTopLeft(find.text('1 105,40 € HT')).dy;
      expect(y2027 < y1984 && y1984 < y1930, isTrue);
      // L'onglet « Aperçu » n'est plus affiché.
      expect(find.text('Alerte rupture'), findsNothing);
    });

    testWidgets('un appui sur une commande ouvre le suivi du transport', (
      tester,
    ) async {
      await ouvrir(tester, Role.promoteur, 'm1');
      await choisirOnglet(tester, 'Commandes');
      await tester.tap(find.text('CDE-1984 · 5 oct.'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Commandes » : un client sans commande', (tester) async {
      await ouvrir(tester, Role.promoteur, 'm5');
      await choisirOnglet(tester, 'Commandes');
      expect(find.text('Aucune commande pour ce client.'), findsOneWidget);
    });

    testWidgets('« Contacts » et « Notes »', (tester) async {
      await ouvrir(tester, Role.promoteur, 'm1');
      await choisirOnglet(tester, 'Contacts');
      expect(find.text('Aucun contact renseigné.'), findsOneWidget);
      await choisirOnglet(tester, 'Notes');
      expect(
        find.text('Nouveau chef de rayon arrivé, à rencontrer · 10 sept.'),
        findsOneWidget,
      );
      expect(
        find.text('Demande une implantation tête de gondole · 2 sept.'),
        findsOneWidget,
      );
      await choisirOnglet(tester, 'Aperçu');
      expect(find.text('Alerte rupture'), findsOneWidget);
    });

    testWidgets(
      "Itinéraire ouvre l'adresse du client ; Appeler et Mail sont inactifs sans donnée",
      (tester) async {
        final lanceur = LanceurFactice();
        await pumpEcran(
          tester,
          const FicheMagasinScreen(magasinId: 'm1'),
          overrides: [lanceurExterneProvider.overrideWithValue(lanceur)],
        );
        await tapAction(tester, 'Appeler');
        await tapAction(tester, 'Mail');
        expect(lanceur.ouverts, isEmpty);
        await tapAction(tester, 'Itinéraire');
        expect(lanceur.ouverts, [
          Uri.parse(
            'geo:0,0?q=104%20avenue%20des%20Champs%2C%2078000%20Versailles',
          ),
        ]);
        expect(find.text("Impossible d'ouvrir l'application."), findsNothing);
      },
    );

    testWidgets(
      'client du CRM : Appeler ouvre tel:, Mail ouvre mailto: (contact à défaut de la fiche)',
      (tester) async {
        final lanceur = LanceurFactice();
        await pumpEcran(
          tester,
          const FicheMagasinScreen(magasinId: 'cr'),
          overrides: [
            lanceurExterneProvider.overrideWithValue(lanceur),
            magasinParIdProvider.overrideWith((ref, id) => _magasinCrm),
            ficheClientProvider.overrideWith(
              (ref, id) => Stream.value(
                const FicheClient(
                  contacts: [
                    ContactClient(nom: 'Léa Martin'),
                    ContactClient(
                      nom: 'Paul Durand',
                      telephone: '06 12 34 56 78',
                      mail: 'paul@exemple.fr',
                    ),
                  ],
                  notes: [],
                  visites: [],
                  commandes: [],
                  visitesMois: 0,
                ),
              ),
            ),
          ],
        );
        await tapAction(tester, 'Appeler');
        await tapAction(tester, 'Mail');
        await tapAction(tester, 'Itinéraire');
        expect(lanceur.ouverts.map((u) => u.toString()), [
          'tel:0612345678',
          'mailto:paul@exemple.fr',
          'geo:0,0?q=5%20rue%20Haute%2C%2069000%20Lyon',
        ]);
      },
    );

    testWidgets('le numéro de la fiche passe avant celui des contacts', (
      tester,
    ) async {
      final lanceur = LanceurFactice();
      await pumpEcran(
        tester,
        const FicheMagasinScreen(magasinId: 'cr'),
        overrides: [
          lanceurExterneProvider.overrideWithValue(lanceur),
          magasinParIdProvider.overrideWith((ref, id) => _magasinCrm),
          ficheClientProvider.overrideWith(
            (ref, id) => Stream.value(
              const FicheClient(
                contacts: [],
                notes: [],
                visites: [],
                commandes: [],
                visitesMois: 0,
                telephone: '+33 1 23 45 67 89',
                mail: 'magasin@exemple.fr',
              ),
            ),
          ),
        ],
      );
      await tapAction(tester, 'Appeler');
      await tapAction(tester, 'Mail');
      expect(lanceur.ouverts.map((u) => u.toString()), [
        'tel:+33123456789',
        'mailto:magasin@exemple.fr',
      ]);
    });

    testWidgets(
      'client du CRM sans adresse ni coordonnées : les trois actions sont inactives',
      (tester) async {
        final lanceur = LanceurFactice();
        await pumpEcran(
          tester,
          const FicheMagasinScreen(magasinId: 'cr'),
          overrides: [
            lanceurExterneProvider.overrideWithValue(lanceur),
            magasinParIdProvider.overrideWith(
              (ref, id) => Magasin(
                id: _magasinCrm.id,
                nom: _magasinCrm.nom,
                statut: _magasinCrm.statut,
                classe: '—',
                adresse: '',
                ca: '—',
                evo: '',
                cde: '—',
                cdeDate: '',
                visites: 0,
                objectif: 0,
                reel: true,
              ),
            ),
            ficheClientProvider.overrideWith((ref, id) => Stream.value(null)),
          ],
        );
        for (final a in ['Appeler', 'Mail', 'Itinéraire']) {
          await tapAction(tester, a);
        }
        expect(lanceur.ouverts, isEmpty);
      },
    );

    testWidgets("aucune application pour l'adresse : toast d'erreur", (
      tester,
    ) async {
      final lanceur = LanceurFactice(reussit: false);
      await pumpEcran(
        tester,
        const FicheMagasinScreen(magasinId: 'm1'),
        overrides: [lanceurExterneProvider.overrideWithValue(lanceur)],
      );
      await tapAction(tester, 'Itinéraire');
      await tester.pump();
      expect(lanceur.ouverts, hasLength(1));
      expect(find.text("Impossible d'ouvrir l'application."), findsOneWidget);
      await laisserPasserToast(tester);
    });

    testWidgets('« ＋ Visite » démarre un brouillon et ouvre la visite', (
      tester,
    ) async {
      final routes = await pumpEcranObserve(
        tester,
        const FicheMagasinScreen(magasinId: 'm1'),
        role: Role.promoteur,
      );
      final avant = conteneurDe(tester).read(crmProvider).visites.length;
      await tester.tap(libelleAction('＋ Visite'));
      await tester.pumpAndSettle();
      final visites = conteneurDe(tester).read(crmProvider).visites;
      expect(visites.length, avant + 1);
      expect(visites.first.magasinId, 'm1');
      expect(visites.first.etat, EtatVisite.brouillon);
      expect(visites.first.par, 'Julien M.');
      expect(routes.noms, contains('visite'));
    });

    testWidgets('« Démarrer une visite » reprend le brouillon existant', (
      tester,
    ) async {
      final routes = await pumpEcranObserve(
        tester,
        const FicheMagasinScreen(magasinId: 'm1'),
        role: Role.promoteur,
      );
      final store = conteneurDe(tester).read(crmProvider.notifier);
      final id = store.demarrerVisite('m1');
      final avant = conteneurDe(tester).read(crmProvider).visites.length;
      await tester.tap(find.text('Démarrer une visite'));
      await tester.pumpAndSettle();
      expect(conteneurDe(tester).read(crmProvider).visites.length, avant);
      expect(routes.noms, contains('visite'));
      expect(
        conteneurDe(tester)
            .read(crmProvider)
            .visites
            .where((v) => v.magasinId == 'm1' && v.etat == EtatVisite.brouillon)
            .map((v) => v.id),
        [id],
      );
    });

    testWidgets('« Ajouter une note » ouvre le dialogue', (tester) async {
      await ouvrir(tester, Role.promoteur, 'm1');
      await tester.tap(find.text('Ajouter une note'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteClientDialog), findsOneWidget);
      expect(find.text('Nouvelle note'), findsOneWidget);
    });

    testWidgets('le retour ferme la fiche', (tester) async {
      final routes = await pumpEcranObserve(
        tester,
        const Scaffold(body: SizedBox()),
        role: Role.promoteur,
      );
      final ctx = tester.element(find.byType(Scaffold));
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'magasin'),
          builder: (_) => const FicheMagasinScreen(magasinId: 'm1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      await tester.tap(find.byType(BoutonRetour));
      await tester.pumpAndSettle();
      expect(find.text('Carrefour Market – Versailles'), findsNothing);
      expect(routes.noms, contains('magasin'));
    });
  });

  group('chef de secteur : Carrefour Market – Versailles (m1)', () {
    testWidgets('six actions, onglets de l’encadrement', (tester) async {
      await ouvrir(tester, Role.cs, 'm1');
      for (final l in [
        'Appeler',
        'Mail',
        'Planifier',
        'Visite',
        'Commande',
        'Itinéraire',
      ]) {
        expect(libelleAction(l), findsOneWidget, reason: l);
      }
      expect(libelleAction('＋ Visite'), findsNothing);
      for (final l in ['Suivi', 'Commandes', 'Contacts', 'Infos']) {
        expect(
          find.descendant(
            of: find.byType(OngletsPills),
            matching: find.text(l),
          ),
          findsOneWidget,
          reason: l,
        );
      }
      expect(find.text('Aperçu'), findsNothing);
      expect(find.text('Notes'), findsNothing);
      // Onglet « Suivi » ouvert : le suivi est affiché.
      expect(find.text('Visite chef de secteur prévue'), findsOneWidget);
      expect(find.text('Ajouter une note'), findsOneWidget);
      expect(find.text('Planifier une visite'), findsOneWidget);
      expect(find.text('Démarrer une visite'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Infos » : adresse et classe', (tester) async {
      await ouvrir(tester, Role.cs, 'm1');
      await choisirOnglet(tester, 'Infos');
      expect(find.text('Adresse'), findsOneWidget);
      // L'adresse est aussi sous le nom, dans l'entête.
      expect(
        find.text('104 avenue des Champs, 78000 Versailles'),
        findsOneWidget,
      );
      expect(find.text('Classe'), findsOneWidget);
      expect(find.text('A++'), findsOneWidget);
      expect(find.text('Visite chef de secteur prévue'), findsNothing);
    });

    testWidgets('« Visite » démarre une visite', (tester) async {
      final routes = await pumpEcranObserve(
        tester,
        const FicheMagasinScreen(magasinId: 'm1'),
        role: Role.cs,
      );
      await tester.tap(libelleAction('Visite'));
      await tester.pumpAndSettle();
      final visites = conteneurDe(tester).read(crmProvider).visites;
      expect(visites.first.magasinId, 'm1');
      expect(visites.first.par, 'Nadia H.');
      expect(routes.noms, contains('visite'));
    });

    testWidgets('« Commande » ouvre la prise de commande de ce client', (
      tester,
    ) async {
      final routes = await pumpEcranObserve(
        tester,
        const FicheMagasinScreen(magasinId: 'm1'),
        role: Role.cs,
      );
      await tester.tap(libelleAction('Commande'));
      await tester.pumpAndSettle();
      expect(routes.noms, contains('cmd'));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '« Planifier » et « Planifier une visite » ouvrent la feuille de RDV',
      (tester) async {
        await ouvrir(tester, Role.cs, 'm1');
        await tester.tap(libelleAction('Planifier'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        await tester.tapAt(const Offset(195, 20));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);

        await tester.tap(find.text('Planifier une visite'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets("Itinéraire ouvre l'adresse ; Appeler inactif sans donnée", (
      tester,
    ) async {
      final lanceur = LanceurFactice();
      await pumpEcran(
        tester,
        const FicheMagasinScreen(magasinId: 'm1'),
        role: Role.cs,
        overrides: [lanceurExterneProvider.overrideWithValue(lanceur)],
      );
      await tapAction(tester, 'Appeler');
      expect(lanceur.ouverts, isEmpty);
      await tapAction(tester, 'Itinéraire');
      expect(lanceur.ouverts.single.scheme, 'geo');
    });
  });

  group('directeur', () {
    testWidgets('fiche d’un client de la région (client inactif)', (
      tester,
    ) async {
      await ouvrir(tester, Role.dir, 'm5');
      expect(find.text('Client inactif'), findsOneWidget);
      expect(find.text('U Express – Paris'), findsOneWidget);
      expect(
        find.text('Classe E · 46 avenue Victor Hugo, 75011 Paris'),
        findsOneWidget,
      );
      expect(find.text('−41 %'), findsOneWidget);
      expect(find.text('310 €'), findsOneWidget);
      expect(find.text('3 sept.'), findsOneWidget);
      expect(find.text('obj. 1'), findsOneWidget);
      expect(libelleAction('Commande'), findsOneWidget);
      expect(find.text('Planifier une visite'), findsOneWidget);
    });

    testWidgets('fiche d’un client hors région : chiffres « — »', (
      tester,
    ) async {
      await ouvrir(tester, Role.dir, 'x1c');
      expect(find.text('Auchan – Avignon'), findsOneWidget);
      expect(find.text('Classe B · 84000 Avignon'), findsOneWidget);
      expect(find.text('Client actif'), findsOneWidget);
      // CA 12 mois et dernière commande : « — », sans évolution ni date.
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0'), findsOneWidget);
      expect(find.text('obj. 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('le pourcentage de l’objectif est plafonné à 100 %', (
      tester,
    ) async {
      // m3 : objectif 6 150, CA 6 330 → 103 % dans la formule, 100 % affiché.
      await ouvrir(tester, Role.dir, 'm3');
      expect(find.text('${eur(6330)} / ${eur(6150)}'), findsOneWidget);
      expect(find.text('100 %'), findsOneWidget);
    });

    testWidgets('« Commandes » d’un client du directeur', (tester) async {
      await ouvrir(tester, Role.dir, 'm10');
      await choisirOnglet(tester, 'Commandes');
      expect(find.text('1 540,00 € HT'), findsOneWidget);
      expect(find.text('CDE-2041 · 3 nov.'), findsOneWidget);
      expect(find.text('Pas livrée'), findsOneWidget);
    });
  });

  testWidgets('un client inconnu ne plante pas', (tester) async {
    await ouvrir(tester, Role.promoteur, 'zzz');
    expect(find.text('Client introuvable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
