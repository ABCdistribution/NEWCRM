import 'dart:async';

import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/fiche_client.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:crm_app/core/sync/fiche_client_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/commandes/commandes_screen.dart';
import 'package:crm_app/features/commandes/logic/attente_crm.dart';
import 'package:crm_app/features/commandes/panier_screen.dart';
import 'package:crm_app/features/commandes/state/attente_provider.dart';
import 'package:crm_app/features/commandes/state/commande_provider.dart';
import 'package:crm_app/features/commandes/state/sous_onglet_commandes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'support_attente_crm.dart';
import 'support_commandes.dart';

const _promoteur = Utilisateur(
  id: 'u',
  identifiant: 'x',
  nomAffiche: 'Jean DUPONT',
  email: null,
  roleApi: 'COMMERCIAL',
);

late FauxServeurCommandes _serveur;

ProviderContainer _conteneur(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CommandesScreen)));

/// Affiche l'écran Commandes d'un promoteur connecté ; les commandes en attente du CRM sont celles de `_serveur`.
Future<ProviderContainer> _ouvrir(
  WidgetTester tester, {
  Map<String, FicheClient?> fiches = const {},
}) async {
  definirAttentesServeur([
    for (final j in _serveur.commandes.values) ?commandeAttenteDepuisJson(j),
  ]);
  await pumpEcran(
    tester,
    const CommandesScreen(),
    role: Role.promoteur,
    overrides: [
      sessionProvider.overrideWith(() => SessionNotifier(_promoteur)),
      apiClientProvider.overrideWithValue(_serveur),
      apiEcritureProvider.overrideWithValue(_serveur),
      ficheClientProvider.overrideWith((ref, id) => Stream.value(fiches[id])),
    ],
  );
  final c = _conteneur(tester);
  // La copie en mémoire du notifier part des mêmes commandes que la liste affichée.
  c.read(commandesAttenteSynchroProvider.notifier).appliquer([
    for (final j in _serveur.commandes.values) j,
  ]);
  return c;
}

Finder _pastille(String t) =>
    find.byWidgetPredicate((w) => w is Pastille && w.label == t);

void main() {
  setUpAll(chargerInter);

  setUp(() {
    _serveur = FauxServeurCommandes()
      ..commandes['c1'] = detailAttente(
        'c1',
        clientId: 'm8',
        date: '2026-11-10T09:30:00.000Z',
        commentaire: 'Prévenir le chef de rayon',
        nePasLivrerAvant: '2026-11-16',
        motifNePasLivrerAvant: 'Inventaire',
      )
      ..commandes['c2'] = detailAttente(
        'c2',
        clientId: 'm1',
        date: '2026-11-12T15:00:00.000Z',
        emailValidation: 'chef@exemple.fr',
        emailEnvoyeLe: '2026-11-12T16:00:00.000Z',
        lignes: [ligneAttente('a1', 6, prix: 10)],
      );
  });

  tearDown(() {
    definirAttentesServeur(null);
    DemoTemps.reel = false;
  });

  group('Liste « En attente »', () {
    testWidgets('sous-onglets avec compteur ; la liste suit le CRM', (
      tester,
    ) async {
      await _ouvrir(tester);
      expect(find.text('Suivi'), findsOneWidget);
      expect(find.text('En attente (2)'), findsOneWidget);
      // Le suivi reste l'écran de départ : pas de carte en attente, pas de section locale de démonstration.
      expect(find.text('⏸ En attente'), findsNothing);
      expect(find.text('Commandes en attente'), findsNothing);

      await toucher(tester, find.text('En attente (2)'));
      expect(find.text('2 commandes en attente'), findsOneWidget);
      expect(find.text('Client, n° de commande…'), findsNothing);
      expect(_pastille('⏸ En attente'), findsNWidgets(2));
      expect(_pastille('✉ Envoyée à chef@exemple.fr'), findsOneWidget);
      // La consigne de livraison de c1 est sur sa carte.
      expect(_pastille('⏳ pas avant 16/11'), findsOneWidget);
      // La plus récente (c2, magasin m1) d'abord.
      final noms = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((t) => t.contains('Boulogne') || t.contains('Versailles'))
          .toList();
      expect(noms.first, contains('Versailles'));
      expect(noms.last, contains('Boulogne'));
      // Date, lignes et total indicatif (22,62 × 12 + 16,28 × 24).
      expect(find.textContaining('2 lignes · 662,16 € HT'), findsOneWidget);
      expect(
        find.textContaining(
          libelleDateAttente(
            DateTime.parse('2026-11-10T09:30:00.000Z').toLocal(),
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('1 ligne · 60,00 € HT'), findsOneWidget);
    });

    testWidgets('aucune commande en attente', (tester) async {
      _serveur.commandes.clear();
      await _ouvrir(tester);
      expect(find.text('En attente (0)'), findsOneWidget);
      await toucher(tester, find.text('En attente (0)'));
      expect(find.text('Aucune commande en attente.'), findsOneWidget);
    });

    testWidgets('supprimer : confirmation, puis DELETE', (tester) async {
      final c = await _ouvrir(tester);
      await toucher(tester, find.text('En attente (2)'));
      await toucher(tester, find.text('Supprimer').first);
      expect(find.text('Supprimer cette commande ?'), findsOneWidget);
      await toucher(
        tester,
        find.descendant(
          of: find.byType(DialogueBase),
          matching: find.text('Supprimer'),
        ),
      );
      expect(_serveur.ecritures.single.$1, 'DELETE');
      expect(_serveur.ecritures.single.$2, '/commandes/apk/c2');
      expect(find.text('Commande en attente supprimée.'), findsOneWidget);
      expect(c.read(attentesCrmProvider).map((x) => x.id), ['c1']);
      expect(find.text('En attente (1)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Modifier une commande en attente', () {
    Future<ProviderContainer> ouvrirPanier(WidgetTester tester) async {
      final c = await _ouvrir(tester);
      await toucher(tester, find.text('En attente (2)'));
      await toucher(tester, find.text('Modifier').last);
      return c;
    }

    testWidgets('un appui sur la commande la rouvre dans le panier', (
      tester,
    ) async {
      final c = await ouvrirPanier(tester);
      expect(find.text('Panier'), findsOneWidget);
      expect(find.text('U Express – Boulogne-Billancourt'), findsOneWidget);
      expect(find.text('Shampooing antipelliculaire'), findsOneWidget);
      expect(find.text('Rouge mat 101'), findsOneWidget);
      expect(find.text('662,16 €'), findsOneWidget);
      expect(find.text('Prévenir le chef de rayon'), findsOneWidget);
      expect(find.text('⏳ Ne pas livrer avant le 16 nov.'), findsOneWidget);
      expect(find.text('Motif : Inventaire'), findsOneWidget);
      expect(find.text('⏸ Enregistrer en attente'), findsOneWidget);
      expect(find.text('✉ Envoyer par mail'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
      expect(c.read(commandeEnCoursProvider)!.crm!.id, 'c1');
    });

    testWidgets('enregistrer : PATCH de ce qui change seulement', (
      tester,
    ) async {
      final c = await ouvrirPanier(tester);
      await tester.enterText(
        find.byKey(const ValueKey('note-adv')).first,
        'Nouvelle remarque',
      );
      await toucher(tester, find.text('⏸ Enregistrer en attente'));
      final (methode, chemin, corps) = _serveur.ecritures.single;
      expect(methode, 'PATCH');
      expect(chemin, '/commandes/apk/c1');
      expect(corps, {'commentaire': 'Nouvelle remarque'});
      expect(c.read(commandeEnCoursProvider), isNull);
      expect(c.read(sousOngletCommandesProvider), SousOngletCommandes.attente);
      expect(find.text('Commande enregistrée en attente.'), findsOneWidget);
      expect(find.text('Panier'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('retirer la consigne : nePasLivrerAvant null', (tester) async {
      await ouvrirPanier(tester);
      await toucher(tester, find.text('Ne pas livrer avant une date précise'));
      await toucher(tester, find.text('⏸ Enregistrer en attente'));
      expect(_serveur.ecritures.single.$3, {'nePasLivrerAvant': null});
      expect(_serveur.commandes['c1']!['nePasLivrerAvant'], isNull);
      expect(_serveur.commandes['c1']!['motifNePasLivrerAvant'], isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('ancien format : relue, puis migrée à l’enregistrement', (
      tester,
    ) async {
      _serveur.commandes['c1'] = detailAttente(
        'c1',
        clientId: 'm8',
        date: '2026-11-10T09:30:00.000Z',
        commentaire:
            '⏳ Ne pas livrer avant le 2026-11-16 · Inventaire\nPrévenir le chef de rayon',
      );
      await ouvrirPanier(tester);
      expect(find.text('⏳ Ne pas livrer avant le 16 nov.'), findsOneWidget);
      expect(find.text('Prévenir le chef de rayon'), findsOneWidget);
      expect(find.textContaining('Ne pas livrer avant le 2026'), findsNothing);
      await toucher(tester, find.text('⏸ Enregistrer en attente'));
      expect(_serveur.ecritures.single.$3, {
        'commentaire': 'Prévenir le chef de rayon',
        'nePasLivrerAvant': '2026-11-16',
        'motifNePasLivrerAvant': 'Inventaire',
      });
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('échec du CRM : message de l’API, la commande reste ouverte', (
      tester,
    ) async {
      final c = await ouvrirPanier(tester);
      await tester.enterText(
        find.byKey(const ValueKey('note-adv')).first,
        'Autre',
      );
      _serveur.erreurEcriture = ErreurApi.depuisReponse(
        409,
        '{"message":"Commande déjà validée : modification impossible"}',
      );
      await toucher(tester, find.text('⏸ Enregistrer en attente'));
      expect(
        find.text('Commande déjà validée : modification impossible'),
        findsOneWidget,
      );
      expect(find.text('Panier'), findsOneWidget);
      expect(c.read(commandeEnCoursProvider), isNotNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'valider : PATCH si modifiée, puis valider ; elle sort de la liste',
      (tester) async {
        final c = await ouvrirPanier(tester);
        await tester.enterText(
          find.byKey(const ValueKey('note-adv')).first,
          'Dernière précision',
        );
        await toucher(tester, find.text('✓ Valider'));
        expect(_serveur.ecritures.map((e) => '${e.$1} ${e.$2}'), [
          'PATCH /commandes/apk/c1',
          'POST /commandes/apk/c1/valider',
        ]);
        expect(c.read(commandeEnCoursProvider), isNull);
        expect(c.read(attentesCrmProvider).map((x) => x.id), ['c2']);
        expect(find.text('Panier'), findsNothing);
        expect(find.textContaining('validée'), findsOneWidget);
        // Elle apparaît dans le suivi comme une commande de l'appli.
        await toucher(tester, find.text('Suivi'));
        expect(idsCartes(tester).any((id) => id.startsWith('CDE-')), isTrue);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets('valider sans modification : seulement POST valider', (
      tester,
    ) async {
      await ouvrirPanier(tester);
      await toucher(tester, find.text('✓ Valider'));
      expect(_serveur.ecritures.map((e) => '${e.$1} ${e.$2}'), [
        'POST /commandes/apk/c1/valider',
      ]);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('supprimer depuis le panier : confirmation puis DELETE', (
      tester,
    ) async {
      final c = await ouvrirPanier(tester);
      await toucher(tester, find.text('Supprimer'));
      await toucher(
        tester,
        find.descendant(
          of: find.byType(DialogueBase),
          matching: find.text('Supprimer'),
        ),
      );
      expect(_serveur.ecritures.single.$1, 'DELETE');
      expect(c.read(commandeEnCoursProvider), isNull);
      expect(find.text('Panier'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Envoi par mail', () {
    Future<ProviderContainer> ouvrirFeuille(
      WidgetTester tester, {
      Map<String, FicheClient?> fiches = const {},
      bool dernier = false,
    }) async {
      final c = await _ouvrir(tester, fiches: fiches);
      await toucher(tester, find.text('En attente (2)'));
      await toucher(
        tester,
        dernier ? find.text('Modifier').last : find.text('Modifier').first,
      );
      await toucher(tester, find.text('✉ Envoyer par mail'));
      return c;
    }

    testWidgets(
      'adresse déjà utilisée pour la commande, sinon e-mail du client',
      (tester) async {
        // c2 (la première de la liste) a déjà été envoyée à chef@exemple.fr.
        await ouvrirFeuille(tester);
        expect(find.text('Envoyer par mail'), findsOneWidget);
        expect(find.text('chef@exemple.fr'), findsOneWidget);
      },
    );

    testWidgets('adresse du client prise sur la commande du CRM', (
      tester,
    ) async {
      await ouvrirFeuille(tester, dernier: true);
      expect(find.text('magasin@exemple.fr'), findsOneWidget);
    });

    testWidgets('sans e-mail sur la commande : celui de la fiche client', (
      tester,
    ) async {
      _serveur.commandes['c1'] = detailAttente(
        'c1',
        clientEmail: null,
        date: '2026-11-10T09:30:00.000Z',
      );
      await ouvrirFeuille(
        tester,
        dernier: true,
        fiches: {
          'm8': const FicheClient(
            contacts: [],
            notes: [],
            visites: [],
            commandes: [],
            visitesMois: 0,
            mail: 'fiche@exemple.fr',
          ),
        },
      );
      expect(find.text('fiche@exemple.fr'), findsOneWidget);
    });

    testWidgets('format invalide refusé, adresse valide : appel puis succès', (
      tester,
    ) async {
      final c = await ouvrirFeuille(tester, dernier: true);
      final champ = find.descendant(
        of: find.byType(FeuilleBase),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(champ, 'pas-une-adresse');
      await toucher(tester, find.text('Envoyer'));
      expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
      expect(_serveur.ecritures, isEmpty);

      await tester.enterText(champ, 'client@exemple.fr');
      await toucher(tester, find.text('Envoyer'));
      expect(_serveur.ecritures.single.$2, '/commandes/apk/c1/envoyer-mail');
      expect(_serveur.ecritures.single.$3, {'email': 'client@exemple.fr'});
      expect(find.text('Envoyer par mail'), findsNothing);
      expect(
        find.text(
          'Commande envoyée à client@exemple.fr. Elle reste en attente.',
        ),
        findsOneWidget,
      );
      // La commande reste en attente, avec la pastille d'envoi.
      expect(c.read(commandeEnCoursProvider)!.crm!.envoyee, isTrue);
      expect(_pastille('✉ Envoyée à client@exemple.fr'), findsOneWidget);
      expect(c.read(attentesCrmProvider), hasLength(2));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'l’API refuse (envoi non configuré) : son message, feuille ouverte',
      (tester) async {
        await ouvrirFeuille(tester, dernier: true);
        _serveur.erreurEcriture = ErreurApi.depuisReponse(
          503,
          '{"message":"Envoi de mail non configuré sur le serveur"}',
        );
        await toucher(tester, find.text('Envoyer'));
        expect(
          find.text('Envoi de mail non configuré sur le serveur'),
          findsOneWidget,
        );
        expect(find.text('Envoyer par mail'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });

  group('Mettre en attente depuis le panier (connecté)', () {
    Future<ProviderContainer> panierNeuf(WidgetTester tester) async {
      final c = await _ouvrir(tester);
      c.read(commandeEnCoursProvider.notifier)
        ..demarrer(magasinId: 'm1')
        ..ajouter('a1');
      unawaited(
        Navigator.of(tester.element(find.byType(CommandesScreen))).push<void>(
          MaterialPageRoute<void>(builder: (_) => const PanierScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('création dans le CRM, rien dans l’attente locale', (
      tester,
    ) async {
      final c = await panierNeuf(tester);
      final localAvant = c.read(attenteProvider).length;
      await toucher(tester, find.text('⏸ Mettre en attente'));
      final (methode, chemin, corps) = _serveur.ecritures.single;
      expect((methode, chemin), ('POST', '/commandes/apk'));
      final b = corps! as Map<String, Object?>;
      expect(b['statut'], 'EN_ATTENTE');
      expect(b['clientId'], 'm1');
      expect(b['idCommandeApk'], matches(r'^[A-Za-z0-9]{10}$'));
      final lignes = (b['lignes']! as List).cast<Map<String, Object?>>();
      expect(lignes.single['articleId'], 'a1');
      expect(lignes.single['quantite'], greaterThan(0));
      expect(lignes.single['prixIndicatif'], isA<double>());
      expect(c.read(attenteProvider), hasLength(localAvant));
      expect(c.read(commandeEnCoursProvider), isNull);
      expect(c.read(sousOngletCommandesProvider), SousOngletCommandes.attente);
      expect(find.text('Commande mise en attente.'), findsOneWidget);
      expect(find.text('Panier'), findsNothing);
      expect(c.read(attentesCrmProvider), hasLength(3));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('la consigne de livraison part en champs séparés', (
      tester,
    ) async {
      final c = await panierNeuf(tester);
      c.read(commandeEnCoursProvider.notifier)
        ..basculerConsigne()
        ..majDateMin('2026-11-20')
        ..choisirMotif('Impératif')
        ..majNote('Une remarque');
      await tester.pump();
      await toucher(tester, find.text('⏸ Mettre en attente'));
      final b = _serveur.ecritures.single.$3! as Map<String, Object?>;
      expect(b['nePasLivrerAvant'], '2026-11-20');
      expect(b['motifNePasLivrerAvant'], 'Impératif');
      expect(b['commentaire'], 'Une remarque');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'sans réseau : erreur, la commande reste, le renvoi garde le même identifiant',
      (tester) async {
        final c = await panierNeuf(tester);
        _serveur.erreurEcriture = const ErreurApi(TypeErreurApi.reseau);
        await toucher(tester, find.text('⏸ Mettre en attente'));
        expect(
          find.text('Serveur injoignable. Vérifiez votre connexion.'),
          findsOneWidget,
        );
        expect(find.text('Panier'), findsOneWidget);
        final restee = c.read(commandeEnCoursProvider)!;
        expect(restee.lignes, isNotEmpty);
        expect(restee.crm, isNull);
        final id = restee.idApk;
        expect(id, isNotNull);

        await tester.pump(const Duration(seconds: 3));
        await toucher(tester, find.text('⏸ Mettre en attente'));
        expect(_serveur.ecritures, hasLength(2));
        expect(
          (_serveur.ecritures.last.$3!
              as Map<String, Object?>)['idCommandeApk'],
          id,
        );
        expect(c.read(commandeEnCoursProvider), isNull);
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'envoi par mail d’une commande pas encore au CRM : elle y est d’abord créée',
      (tester) async {
        final c = await panierNeuf(tester);
        await toucher(tester, find.text('✉ Envoyer par mail'));
        final champ = find.descendant(
          of: find.byType(FeuilleBase),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(champ, 'client@exemple.fr');
        await toucher(tester, find.text('Envoyer'));
        expect(_serveur.ecritures.map((e) => '${e.$1} ${e.$2}'), [
          'POST /commandes/apk',
          'POST /commandes/apk/cmd-1/envoyer-mail',
        ]);
        // Elle est maintenant liée à sa commande du CRM : un nouvel enregistrement la modifie.
        expect(c.read(commandeEnCoursProvider)!.crm!.id, 'cmd-1');
        expect(find.text('⏸ Enregistrer en attente'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}
