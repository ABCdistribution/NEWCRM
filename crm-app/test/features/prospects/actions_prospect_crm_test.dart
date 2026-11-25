import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/prospects_serveur.dart';
import 'package:crm_app/core/data/detail_prospect.dart';
import 'package:crm_app/core/envoi/envoi_provider.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/detail_prospect_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/fiche_prospect_screen.dart';
import 'package:crm_app/features/prospects/logic/actions_prospect.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../../support/faux_ecriture.dart';
import '../../support/lanceur_factice.dart';

/// Actions sur un prospect envoyées au CRM (note, étape, conversion, appel, e-mail), connecté seulement.

const _id = '22222222-2222-4222-8222-222222222222';

Utilisateur _moi(String role) => Utilisateur(
  id: 'moi',
  identifiant: 'x',
  nomAffiche: 'Nadia H.',
  email: null,
  roleApi: role,
);

ErreurApi _erreurApi(int statut) =>
    ErreurApi(TypeErreurApi.inattendue, statut: statut);

class _Banc {
  _Banc(this.ecriture, this.prospects, this.clients, this.envoi);

  final FauxEcriture ecriture;
  final ProspectsSynchroFaux prospects;
  final ClientsSynchroFaux clients;
  final FauxEnvoi envoi;
}

Future<_Banc> _monter(
  WidgetTester tester, {
  String roleApi = 'CHEF_SECTEUR',
  Role role = Role.cs,
  DetailProspect detail = const DetailProspect(timeline: []),
  LanceurFactice? lanceur,
  SurveillantFactice? surveillant,
}) async {
  DemoTemps.reel = true;
  definirProspectsServeur(const [
    Prospect(
      id: _id,
      nom: 'Super Proxi',
      raison: 'DUPONT SAS',
      classe: 'B',
      cp: '34400 Lunel',
      statut: StatutProspect.negociation,
      pot: 120,
      proba: 60,
      timeline: [],
    ),
  ]);
  addTearDown(() {
    DemoTemps.reel = false;
    definirProspectsServeur(null);
  });
  final b = _Banc(
    FauxEcriture(),
    ProspectsSynchroFaux(),
    ClientsSynchroFaux(),
    FauxEnvoi(),
  );
  await pumpEcran(
    tester,
    const FicheProspectScreen(prospectId: _id),
    role: role,
    overrides: [
      sessionProvider.overrideWith(() => SessionNotifier(_moi(roleApi))),
      apiEcritureProvider.overrideWithValue(b.ecriture),
      prospectsSynchroProvider.overrideWith(() => b.prospects),
      clientsProvider.overrideWith(() => b.clients),
      envoiProvider.overrideWith(() => b.envoi),
      detailProspectProvider.overrideWith((ref, id) => Stream.value(detail)),
      if (lanceur != null) lanceurExterneProvider.overrideWithValue(lanceur),
      if (surveillant != null)
        surveillantRetourProvider.overrideWithValue(surveillant),
    ],
  );
  return b;
}

Finder _action(String libelle) => find.descendant(
  of: find.byType(RangeeActions),
  matching: find.text(libelle),
);

Finder _dans(Type t, String texte) =>
    find.descendant(of: find.byType(t), matching: find.text(texte));

void main() {
  group('logique pure', () {
    test('droits : ceux des @Roles de l\'API', () {
      for (final r in ['CHEF_SECTEUR', 'DIRECTEUR_REGIONAL', 'ADMIN']) {
        expect(peutNoterProspect(r), isTrue, reason: r);
        expect(peutFaireAvancerProspect(r), isTrue, reason: r);
      }
      expect(peutNoterProspect('DIRECTION'), isTrue);
      expect(peutFaireAvancerProspect('DIRECTION'), isFalse);
      for (final r in ['COMMERCIAL', 'ADV', 'MARKETING', null]) {
        expect(peutNoterProspect(r), isFalse, reason: '$r');
        expect(peutFaireAvancerProspect(r), isFalse, reason: '$r');
      }
    });

    test(
      'corps du changement d\'étape : le motif seulement pour « Perdu »',
      () {
        expect(corpsChangementEtape(StatutProspect.contacte), {
          'statut': 'CONTACTE',
        });
        expect(
          corpsChangementEtape(StatutProspect.contacte, motif: MotifPerte.prix),
          {'statut': 'CONTACTE'},
        );
        expect(
          corpsChangementEtape(StatutProspect.perdu, motif: MotifPerte.autre),
          {'statut': 'PERDU', 'motifPerte': 'AUTRE'},
        );
        // MotifPerteProspect de l'API.
        expect(MotifPerte.values.map((m) => m.code).toSet(), {
          'PRIX',
          'CONCURRENCE',
          'PAS_DE_BESOIN',
          'SANS_REPONSE',
          'AUTRE',
        });
      },
    );

    test('routes et messages', () {
      expect(cheminProspect('a b'), '/prospects/a%20b');
      expect(cheminProspect(_id, 'convert'), '/prospects/$_id/convert');
      expect(
        messageErreurActionProspect(_erreurApi(403)),
        "Vous n'avez pas le droit de faire cela sur ce prospect.",
      );
      expect(
        messageErreurActionProspect(_erreurApi(404)),
        'Prospect introuvable dans votre périmètre.',
      );
      expect(
        messageErreurActionProspect(
          const ErreurApi(
            TypeErreurApi.inattendue,
            statut: 400,
            detail: 'motifPerte est requis',
          ),
        ),
        'motifPerte est requis',
      );
      expect(
        messageErreurActionProspect(const ErreurApi(TypeErreurApi.reseau)),
        'Serveur injoignable. Vérifiez votre connexion.',
      );
    });
  });

  group('changer d\'étape', () {
    testWidgets('PATCH du statut, fiche et liste relues, feuille fermée', (
      tester,
    ) async {
      final b = await _monter(tester);
      await tester.tap(find.text("Changer d'étape"));
      await tester.pumpAndSettle();
      await tester.tap(_dans(FeuilleBase, 'Contacté'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels, hasLength(1));
      expect(b.ecriture.appels.single.methode, 'PATCH');
      expect(b.ecriture.appels.single.chemin, '/prospects/$_id');
      expect(b.ecriture.corps(0), {'statut': 'CONTACTE'});
      expect(b.prospects.rafraichis, 1);
      expect(find.byType(FeuilleBase), findsNothing);
      expect(find.text('Étape : Contacté.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('l\'étape courante ne fait rien', (tester) async {
      final b = await _monter(tester);
      await tester.tap(find.text("Changer d'étape"));
      await tester.pumpAndSettle();
      await tester.tap(_dans(FeuilleBase, 'En négociation'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels, isEmpty);
      expect(find.byType(FeuilleBase), findsOneWidget);
    });

    testWidgets('« Perdu » demande le motif avant tout envoi', (tester) async {
      final b = await _monter(tester);
      await tester.tap(find.text("Changer d'étape"));
      await tester.pumpAndSettle();
      await tester.tap(_dans(FeuilleBase, 'Perdu'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels, isEmpty);
      expect(_dans(FeuilleBase, 'Motif de la perte'), findsOneWidget);
      await tester.tap(_dans(FeuilleBase, 'Concurrent en place'));
      await tester.pumpAndSettle();
      expect(b.ecriture.corps(0), {
        'statut': 'PERDU',
        'motifPerte': 'CONCURRENCE',
      });
      expect(b.prospects.rafraichis, 1);
      expect(find.text('Étape : Perdu.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('refus de l\'API : feuille ouverte, message, rien relu', (
      tester,
    ) async {
      final b = await _monter(tester);
      b.ecriture.pannes.add(_erreurApi(403));
      await tester.tap(find.text("Changer d'étape"));
      await tester.pumpAndSettle();
      await tester.tap(_dans(FeuilleBase, 'Contacté'));
      await tester.pumpAndSettle();
      expect(
        find.text("Vous n'avez pas le droit de faire cela sur ce prospect."),
        findsOneWidget,
      );
      expect(find.byType(FeuilleBase), findsOneWidget);
      expect(b.prospects.rafraichis, 0);
      // Le store local n'a pas bougé : le serveur gagne.
      final p = ProviderScope.containerOf(
        tester.element(find.byType(FicheProspectScreen)),
      ).read(prospectParIdProvider(_id))!;
      expect(p.statut, StatutProspect.negociation);
    });
  });

  group('passer en client', () {
    testWidgets('POST convert, listes relues, dialogue fermé', (tester) async {
      final b = await _monter(tester);
      await tester.tap(find.text('Passer en client'));
      await tester.pumpAndSettle();
      await tester.tap(_dans(Dialog, 'Passer en client'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels.single.methode, 'POST');
      expect(b.ecriture.appels.single.chemin, '/prospects/$_id/convert');
      expect(b.prospects.rafraichis, 1);
      expect(b.clients.rafraichis, 1);
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.text('Le prospect est maintenant un client.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('refus : dialogue ouvert avec le message, rien relu', (
      tester,
    ) async {
      final b = await _monter(tester);
      b.ecriture.pannes.add(_erreurApi(404));
      await tester.tap(find.text('Passer en client'));
      await tester.pumpAndSettle();
      await tester.tap(_dans(Dialog, 'Passer en client'));
      await tester.pumpAndSettle();
      expect(
        _dans(Dialog, 'Prospect introuvable dans votre périmètre.'),
        findsOneWidget,
      );
      expect(b.prospects.rafraichis, 0);
      expect(b.clients.rafraichis, 0);
    });
  });

  group('note', () {
    testWidgets('rangée dans la file d\'envoi, rien ajouté en local', (
      tester,
    ) async {
      final b = await _monter(tester);
      await tester.tap(_action('Note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Relancer en janvier ');
      await tester.tap(_dans(Dialog, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(b.envoi.activites, hasLength(1));
      final r = b.envoi.activites.single;
      expect(r.chemin, '/prospects/$_id/notes');
      expect(r.corps['remarque'], 'Relancer en janvier');
      expect(r.corps['idApk'], r.idApk);
      expect(r.cible, 'prospect:$_id');
      expect(b.ecriture.appels, isEmpty);
      expect(
        find.text('Note enregistrée. Envoi dès que le réseau le permet.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('note vide : rien n\'est rangé', (tester) async {
      final b = await _monter(tester);
      await tester.tap(_action('Note'));
      await tester.pumpAndSettle();
      await tester.tap(_dans(Dialog, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(b.envoi.activites, isEmpty);
      expect(find.byType(Dialog), findsOneWidget);
    });
  });

  group('appel et e-mail', () {
    testWidgets('journalisés après l\'ouverture de l\'application', (
      tester,
    ) async {
      final lanceur = LanceurFactice();
      final b = await _monter(
        tester,
        detail: const DetailProspect(
          timeline: [],
          telephone: '04 67 00 11 22',
          mail: 'contact@exemple.fr',
        ),
        lanceur: lanceur,
      );
      await tester.tap(_action('Appeler'));
      await tester.pumpAndSettle();
      expect(b.envoi.activites, isEmpty);
      await tester.tap(find.text('Ignorer'));
      await tester.pumpAndSettle();
      await tester.tap(_action('Mail'));
      await tester.pump();
      expect(lanceur.ouverts.map((u) => u.toString()), [
        'tel:0467001122',
        'mailto:contact@exemple.fr',
      ]);
      expect(b.envoi.activites.map((r) => r.chemin), [
        '/prospects/$_id/appels',
        '/prospects/$_id/emails',
      ]);
      expect(b.envoi.activites[0].corps.keys, {'idApk', 'dateAppel'});
      expect(b.envoi.activites[1].corps['destinataire'], 'contact@exemple.fr');
      expect(b.envoi.activites[0].idApk == b.envoi.activites[1].idApk, isFalse);
    });

    testWidgets('résultat de l\'appel envoyé avec l\'entrée', (tester) async {
      final b = await _monter(
        tester,
        detail: const DetailProspect(timeline: [], telephone: '0467001122'),
        lanceur: LanceurFactice(),
      );
      await tester.tap(_action('Appeler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Messagerie'));
      await tester.pumpAndSettle();
      final a = b.envoi.activites.single;
      expect(a.chemin, '/prospects/$_id/appels');
      expect(a.corps['resultat'], 'MESSAGERIE');
    });

    testWidgets('échec d\'ouverture : rien n\'est journalisé', (tester) async {
      final b = await _monter(
        tester,
        detail: const DetailProspect(timeline: [], telephone: '0467001122'),
        lanceur: LanceurFactice(reussit: false),
      );
      await tester.tap(_action('Appeler'));
      await tester.pump();
      expect(b.envoi.activites, isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('droits du rôle', () {
    testWidgets('direction : note possible, ni étape ni conversion', (
      tester,
    ) async {
      await _monter(tester, roleApi: 'DIRECTION', role: Role.dir);
      expect(_action('Note'), findsOneWidget);
      expect(find.text("Changer d'étape"), findsNothing);
      expect(find.text('Passer en client'), findsNothing);
    });

    testWidgets('promoteur : aucune action d\'écriture, rien journalisé', (
      tester,
    ) async {
      final lanceur = LanceurFactice();
      final b = await _monter(
        tester,
        roleApi: 'COMMERCIAL',
        role: Role.promoteur,
        detail: const DetailProspect(timeline: [], telephone: '0467001122'),
        lanceur: lanceur,
      );
      expect(_action('Note'), findsNothing);
      expect(find.text("Changer d'étape"), findsNothing);
      expect(find.text('Passer en client'), findsNothing);
      await tester.tap(_action('Appeler'));
      await tester.pump();
      expect(lanceur.ouverts, hasLength(1));
      expect(b.envoi.activites, isEmpty);
    });
  });
}
