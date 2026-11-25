import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/fiche_client.dart';
import 'package:crm_app/core/data/journal_contacts.dart';
import 'package:crm_app/core/envoi/corps_activite.dart';
import 'package:crm_app/core/envoi/envoi_provider.dart';
import 'package:crm_app/core/envoi/journal_contact.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/fiche_client_provider.dart';
import 'package:crm_app/core/sync/journal_contacts_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/clients/fiche_magasin_screen.dart';
import 'package:crm_app/features/clients/logic/actions_magasin.dart';
import 'package:crm_app/features/clients/periodicite_magasin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../../support/faux_ecriture.dart';
import '../../support/lanceur_factice.dart';

/// Écritures sur un magasin envoyées au CRM (note, contacts, périodicité, journal des appels et e-mails), connecté seulement.

const _id = '11111111-1111-4111-8111-111111111111';
const _contactId = '44444444-4444-4444-8444-444444444444';
const _mensuelle = '55555555-5555-4555-8555-555555555555';

const _magasin = Magasin(
  id: _id,
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

const _fiche = FicheClient(
  contacts: [
    ContactClient(
      nom: 'Léa Martin',
      poste: 'Chef de rayon',
      id: _contactId,
      prenom: 'Léa',
      nomFamille: 'Martin',
      posteSaisi: 'Chef de rayon',
      portable: '0612345678',
    ),
  ],
  notes: [],
  visites: [],
  commandes: [],
  visitesMois: 0,
  telephone: '04 78 00 11 22',
  mail: 'magasin@exemple.fr',
  periodicite: 'Hebdomadaire',
);

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
  _Banc(this.ecriture, this.envoi, this.lanceur);

  final FauxEcriture ecriture;
  final FauxEnvoi envoi;
  final LanceurFactice lanceur;
}

Future<_Banc> _monter(
  WidgetTester tester, {
  String? roleApi = 'CHEF_SECTEUR',
  Role role = Role.cs,
  LanceurFactice? lanceur,
  SurveillantFactice? surveillant,
  List<EntreeJournalContact> journal = const [],
}) async {
  if (roleApi != null) DemoTemps.reel = true;
  addTearDown(() => DemoTemps.reel = false);
  final b = _Banc(FauxEcriture(), FauxEnvoi(), lanceur ?? LanceurFactice());
  await pumpEcran(
    tester,
    const FicheMagasinScreen(magasinId: _id),
    role: role,
    overrides: [
      if (roleApi != null)
        sessionProvider.overrideWith(() => SessionNotifier(_moi(roleApi))),
      apiEcritureProvider.overrideWithValue(b.ecriture),
      envoiProvider.overrideWith(() => b.envoi),
      lanceurExterneProvider.overrideWithValue(b.lanceur),
      if (surveillant != null)
        surveillantRetourProvider.overrideWithValue(surveillant),
      magasinParIdProvider.overrideWith((ref, id) => _magasin),
      ficheClientProvider.overrideWith((ref, id) => Stream.value(_fiche)),
      journalContactsProvider.overrideWith((ref, id) => Stream.value(journal)),
      periodicitesVisiteProvider.overrideWith(
        (ref) async => const [
          PeriodiciteVisite(id: _mensuelle, libelle: 'Mensuelle'),
          PeriodiciteVisite(id: 'autre', libelle: 'Hebdomadaire'),
        ],
      ),
    ],
  );
  return b;
}

Future<void> _onglet(WidgetTester tester, String l) async {
  final onglet = find.descendant(
    of: find.byType(OngletsPills),
    matching: find.text(l),
  );
  await tester.ensureVisible(onglet);
  await tester.pumpAndSettle();
  await tester.tap(onglet);
  await tester.pumpAndSettle();
}

Finder _action(String l) =>
    find.descendant(of: find.byType(RangeeActions), matching: find.text(l));

Finder _dans(Type t, String texte) =>
    find.descendant(of: find.byType(t), matching: find.text(texte));

Future<void> _saisir(WidgetTester tester, String label, String texte) async {
  final champ = find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextFormField),
  );
  await tester.enterText(champ.first, texte);
  await tester.pump();
}

void main() {
  group('corps des écritures d\'activité', () {
    final quand = DateTime.utc(2026, 11, 25, 9, 30);

    test('note : remarque nettoyée, idApk, route du client ou du prospect', () {
      final r = requeteNote(
        CibleActivite.client,
        _id,
        '  Rayon réagencé ',
        idApk: 'N1',
      );
      expect(r.chemin, '/clients/$_id/notes');
      expect(r.corps, {'remarque': 'Rayon réagencé', 'idApk': 'N1'});
      expect(r.cible, 'client:$_id');
      expect(
        requeteNote(CibleActivite.prospect, _id, 'x').chemin,
        '/prospects/$_id/notes',
      );
      expect(
        requeteNote(CibleActivite.client, _id, 'a' * 3000).corps['remarque'],
        hasLength(2000),
      );
    });

    test('idApk généré : un UUID, différent à chaque requête', () {
      final a = requeteNote(CibleActivite.client, _id, 'x');
      final b = requeteNote(CibleActivite.client, _id, 'x');
      expect(a.idApk, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(a.idApk, isNot(b.idApk));
      expect(a.corps['idApk'], a.idApk);
    });

    test('appel et e-mail : date UTC, destinataire seulement s\'il existe', () {
      final a = requeteAppel(CibleActivite.client, _id, quand: quand);
      expect(a.chemin, '/clients/$_id/appels');
      expect(a.corps['dateAppel'], '2026-11-25T09:30:00.000Z');
      expect(a.corps.containsKey('resultat'), isFalse);
      final r = requeteAppel(
        CibleActivite.client,
        _id,
        quand: quand,
        resultat: ResultatAppel.messagerie,
      );
      expect(r.corps['resultat'], 'MESSAGERIE');
      expect(
        ResultatAppel.depuisCode('RAPPEL_PREVU'),
        ResultatAppel.rappelPrevu,
      );
      expect(ResultatAppel.depuisCode('X'), isNull);
      final e = requeteEmail(
        CibleActivite.client,
        _id,
        quand: quand,
        destinataire: ' a@b.fr ',
      );
      expect(e.chemin, '/clients/$_id/emails');
      expect(e.corps['destinataire'], 'a@b.fr');
      expect(
        requeteEmail(CibleActivite.client, _id, quand: quand).corps.keys,
        isNot(contains('destinataire')),
      );
    });

    test(
      'journal d\'une adresse lancée : tel, mailto, rien pour l\'itinéraire',
      () {
        RequeteActivite? j(String u, {String id = _id}) => requeteJournal(
          Uri.parse(u),
          cible: CibleActivite.client,
          id: id,
          quand: quand,
        );
        expect(j('tel:0123456789')!.chemin, '/clients/$_id/appels');
        expect(j('mailto:a@b.fr')!.corps['destinataire'], 'a@b.fr');
        expect(j('geo:0,0?q=Lyon'), isNull);
        expect(j('tel:0123456789', id: 'm1'), isNull);
      },
    );
  });

  group('logique des contacts et de la périodicité', () {
    test('droits : les rôles de l\'API connus de l\'application', () {
      for (final r in [
        'ADMIN',
        'DIRECTION',
        'DIRECTEUR_REGIONAL',
        'CHEF_SECTEUR',
        'COMMERCIAL',
        'ADV',
      ]) {
        expect(peutEcrireMagasin(r), isTrue, reason: r);
      }
      expect(peutEcrireMagasin('MARKETING'), isFalse);
      expect(peutEcrireMagasin(null), isFalse);
    });

    test('validation : nom requis, longueurs de l\'API, mail', () {
      expect(validerContact(const BrouillonContact(nom: 'Durand')), isEmpty);
      expect(validerContact(const BrouillonContact()).keys, {'nom'});
      expect(
        validerContact(
          BrouillonContact(
            prenom: 'a' * 61,
            nom: 'b' * 61,
            poste: 'c' * 81,
            fixe: '1' * 21,
            portable: '2' * 21,
            mail: 'pas un mail',
          ),
        ).keys,
        {'prenom', 'nom', 'poste', 'fixe', 'portable', 'mail'},
      );
      expect(
        validerContact(
          BrouillonContact(
            prenom: 'a' * 60,
            nom: 'b' * 60,
            poste: 'c' * 80,
            fixe: '1' * 20,
            portable: '2' * 20,
            mail: 'a@b.fr',
          ),
        ),
        isEmpty,
      );
    });

    test('corps : création sans champ vide, modification avec null', () {
      const b = BrouillonContact(
        prenom: ' Marie ',
        nom: 'Durand',
        mail: 'm@d.fr',
      );
      expect(corpsContact(b), {
        'prenom': 'Marie',
        'nom': 'Durand',
        'mail': 'm@d.fr',
      });
      expect(corpsContact(b, modification: true), {
        'prenom': 'Marie',
        'nom': 'Durand',
        'poste': null,
        'fixe': null,
        'portable': null,
        'mail': 'm@d.fr',
      });
    });

    test('routes, périodicité et lecture de la nomenclature', () {
      expect(cheminContact(_id), '/clients/$_id/contacts');
      expect(
        cheminContact(_id, _contactId),
        '/clients/$_id/contacts/$_contactId',
      );
      expect(cheminPeriodicite(_id), '/clients/$_id/periodicite');
      expect(corpsPeriodicite(null), {'periodiciteId': null});
      final p = periodicitesDepuisJson([
        {'id': _mensuelle, 'code': 3, 'libelle': 'Mensuelle'},
        {'id': 5, 'libelle': 'illisible'},
        'x',
      ]);
      expect(p.map((e) => e.libelle), ['Mensuelle']);
      expect(periodicitesDepuisJson(null), isEmpty);
    });

    test('messages d\'erreur', () {
      expect(
        messageErreurMagasin(_erreurApi(404)),
        'Magasin ou contact introuvable dans votre périmètre.',
      );
      expect(
        messageErreurMagasin(_erreurApi(403)),
        "Vous n'avez pas le droit de modifier ce magasin.",
      );
      expect(
        messageErreurMagasin(
          const ErreurApi(
            TypeErreurApi.inattendue,
            statut: 400,
            detail: 'mail must be an email',
          ),
        ),
        'mail must be an email',
      );
    });

    test('la fiche garde l\'identifiant et les champs du contact', () {
      final f = ficheClientDepuisJson(_id, {
        'contacts': [
          {
            'id': _contactId,
            'prenom': 'Léa',
            'nom': 'Martin',
            'poste': 'Chef de rayon',
            'fixe': '0478001122',
            'portable': '0612345678',
            'mail': 'lea@exemple.fr',
          },
        ],
      }, null);
      final c = f.contacts.single;
      expect(c.id, _contactId);
      expect(c.nom, 'Léa Martin');
      expect(c.prenom, 'Léa');
      expect(c.nomFamille, 'Martin');
      expect(c.fixe, '0478001122');
      expect(c.portable, '0612345678');
      expect(BrouillonContact.depuis(c).poste, 'Chef de rayon');
    });
  });

  group('note terrain', () {
    testWidgets('rangée dans la file d\'envoi avec son idApk', (tester) async {
      final b = await _monter(tester);
      await tester.tap(find.text('Ajouter une note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Prévoir PLV');
      await tester.tap(_dans(Dialog, 'Enregistrer'));
      await tester.pumpAndSettle();
      final r = b.envoi.activites.single;
      expect(r.chemin, '/clients/$_id/notes');
      expect(r.corps['remarque'], 'Prévoir PLV');
      expect(r.cible, 'client:$_id');
      expect(
        find.text('Note enregistrée. Envoi dès que le réseau le permet.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('démonstration : toast seul, rien dans la file', (
      tester,
    ) async {
      final b = await _monter(tester, roleApi: null);
      await tester.tap(find.text('Ajouter une note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Prévoir PLV');
      await tester.tap(_dans(Dialog, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(b.envoi.activites, isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('journal des appels et e-mails', () {
    for (final (role, roleApi) in [
      (Role.promoteur, 'COMMERCIAL'),
      (Role.cs, 'CHEF_SECTEUR'),
      (Role.dir, 'DIRECTION'),
    ]) {
      testWidgets('$roleApi : appel et e-mail journalisés après l\'ouverture', (
        tester,
      ) async {
        final b = await _monter(tester, roleApi: roleApi, role: role);
        await tester.tap(_action('Appeler'));
        await tester.pumpAndSettle();
        // Le résultat est demandé avant le journal ; « Ignorer » journalise sans résultat.
        expect(find.text("Résultat de l'appel"), findsOneWidget);
        expect(b.envoi.activites, isEmpty);
        await tester.tap(find.text('Ignorer'));
        await tester.pumpAndSettle();
        expect(b.envoi.activites.single.corps.containsKey('resultat'), isFalse);
        await tester.tap(_action('Mail'));
        await tester.pump();
        await tester.tap(_action('Itinéraire'));
        await tester.pump();
        expect(b.lanceur.ouverts, hasLength(3));
        expect(b.envoi.activites.map((r) => r.chemin), [
          '/clients/$_id/appels',
          '/clients/$_id/emails',
        ]);
        expect(
          b.envoi.activites[1].corps['destinataire'],
          'magasin@exemple.fr',
        );
      });
    }

    for (final r in ResultatAppel.values) {
      testWidgets('résultat « ${r.libelle} » envoyé avec l\'appel', (
        tester,
      ) async {
        final b = await _monter(tester);
        await tester.tap(_action('Appeler'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(r.libelle));
        await tester.pumpAndSettle();
        expect(find.text("Résultat de l'appel"), findsNothing);
        final a = b.envoi.activites.single;
        expect(a.chemin, '/clients/$_id/appels');
        expect(a.corps['resultat'], r.code);
      });
    }

    testWidgets('fermer la feuille sans choisir journalise quand même', (
      tester,
    ) async {
      final b = await _monter(tester);
      await tester.tap(_action('Appeler'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // le voile
      await tester.pumpAndSettle();
      expect(b.envoi.activites.single.chemin, '/clients/$_id/appels');
      expect(b.envoi.activites.single.corps.containsKey('resultat'), isFalse);
    });

    group("retour dans l'application", () {
      testWidgets('la feuille attend le retour, puis journalise', (
        tester,
      ) async {
        final retour = SurveillantFactice();
        final b = await _monter(tester, surveillant: retour);
        await tester.tap(_action('Appeler'));
        await tester.pumpAndSettle();
        expect(b.lanceur.ouverts, hasLength(1));
        expect(find.text("Résultat de l'appel"), findsNothing);
        expect(b.envoi.activites, isEmpty);

        retour.reviens();
        await tester.pumpAndSettle();
        expect(find.text("Résultat de l'appel"), findsOneWidget);
        expect(b.envoi.activites, isEmpty);
        await tester.tap(find.text('Rappel prévu'));
        await tester.pumpAndSettle();
        final a = b.envoi.activites.single;
        expect(a.chemin, '/clients/$_id/appels');
        expect(a.corps['resultat'], ResultatAppel.rappelPrevu.code);
      });

      testWidgets("sans retour avant le délai : rien n'est journalisé", (
        tester,
      ) async {
        final retour = SurveillantFactice();
        final b = await _monter(tester, surveillant: retour);
        await tester.tap(_action('Appeler'));
        await tester.pumpAndSettle();
        retour.delaiEcoule();
        await tester.pumpAndSettle();
        expect(find.text("Résultat de l'appel"), findsNothing);
        expect(b.envoi.activites, isEmpty);
      });

      testWidgets("échec d'ouverture : l'attente est annulée", (tester) async {
        final retour = SurveillantFactice();
        final b = await _monter(
          tester,
          surveillant: retour,
          lanceur: LanceurFactice(reussit: false),
        );
        await tester.tap(_action('Appeler'));
        await tester.pump();
        expect(retour.attentes.single.annulee, isTrue);
        expect(b.envoi.activites, isEmpty);
        await tester.pump(const Duration(seconds: 3));
      });

      testWidgets("écran quitté pendant l'appel : journalisé sans résultat", (
        tester,
      ) async {
        final retour = SurveillantFactice();
        final b = await _monter(tester, surveillant: retour);
        await tester.tap(_action('Appeler'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        retour.reviens();
        await tester.pumpAndSettle();
        final a = b.envoi.activites.single;
        expect(a.chemin, '/clients/$_id/appels');
        expect(a.corps.containsKey('resultat'), isFalse);
      });

      testWidgets('e-mail : aucune attente', (tester) async {
        final retour = SurveillantFactice();
        final b = await _monter(tester, surveillant: retour);
        await tester.tap(_action('Mail'));
        await tester.pumpAndSettle();
        expect(retour.attentes, isEmpty);
        expect(b.envoi.activites.single.chemin, '/clients/$_id/emails');
      });
    });

    testWidgets('e-mail : aucune question de résultat', (tester) async {
      final b = await _monter(tester);
      await tester.tap(_action('Mail'));
      await tester.pumpAndSettle();
      expect(find.text("Résultat de l'appel"), findsNothing);
      expect(b.envoi.activites.single.chemin, '/clients/$_id/emails');
    });

    testWidgets(
      'démonstration : l\'application s\'ouvre, rien n\'est journalisé',
      (tester) async {
        final b = await _monter(tester, roleApi: null);
        await tester.tap(_action('Appeler'));
        await tester.pump();
        expect(find.text("Résultat de l'appel"), findsNothing);
        expect(b.lanceur.ouverts, hasLength(1));
        expect(b.envoi.activites, isEmpty);
      },
    );

    testWidgets('échec d\'ouverture : rien n\'est journalisé', (tester) async {
      final ko = LanceurFactice(reussit: false);
      final b = await _monter(tester, lanceur: ko);
      await tester.tap(_action('Appeler'));
      await tester.pump();
      expect(ko.ouverts, hasLength(1));
      expect(b.envoi.activites, isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('journal des appels et e-mails affiché sur la fiche', () {
    final entrees = [
      EntreeJournalContact(
        type: TypeContact.appel,
        id: 'a1',
        date: DateTime(2026, 11, 24, 10),
        resultat: ResultatAppel.sansReponse,
        auteur: 'Léa M.',
      ),
      EntreeJournalContact(
        type: TypeContact.email,
        id: 'e1',
        date: DateTime(2026, 11, 20, 9),
        sujet: 'Offre promo',
        auteur: 'Paul D.',
      ),
    ];

    testWidgets('liste : type, date, résultat ou sujet, auteur', (
      tester,
    ) async {
      await _monter(tester, journal: entrees);
      expect(find.text('Appels et e-mails'), findsOneWidget);
      expect(find.text('Appel'), findsOneWidget);
      expect(find.text('24 nov.'), findsOneWidget);
      expect(find.text('Sans réponse · Léa M.'), findsOneWidget);
      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('20 nov.'), findsOneWidget);
      expect(find.text('Offre promo · Paul D.'), findsOneWidget);
    });

    testWidgets('sans entrée : mention discrète', (tester) async {
      await _monter(tester);
      expect(find.text('Appels et e-mails'), findsOneWidget);
      expect(find.text('Aucun appel ni e-mail.'), findsOneWidget);
    });

    testWidgets('rôle sans droit de lecture : section masquée', (tester) async {
      await _monter(tester, roleApi: 'MARKETING', journal: entrees);
      expect(find.text('Appels et e-mails'), findsNothing);
      expect(find.text('Offre promo · Paul D.'), findsNothing);
    });

    testWidgets('démonstration : section masquée', (tester) async {
      await _monter(tester, roleApi: null, journal: entrees);
      expect(find.text('Appels et e-mails'), findsNothing);
    });

    test(
      'lecture de la réponse de l\'API : plus récent en tête, lignes illisibles écartées',
      () {
        final l = journalContactsDepuisJson({
          'data': [
            {
              'type': 'EMAIL',
              'id': 'e1',
              'date': '2026-11-20T09:00:00.000Z',
              'sujet': '  Offre ',
              'commentaire': null,
              'auteur': null,
            },
            {
              'type': 'APPEL',
              'id': 'a1',
              'date': '2026-11-24T10:00:00.000Z',
              'resultat': 'RAPPEL_PREVU',
              'auteur': 'Léa M.',
            },
            {'type': 'APPEL', 'id': 'a2', 'date': 'pas une date'},
            {'type': 'AUTRE', 'id': 'x', 'date': '2026-11-24T10:00:00.000Z'},
            'bizarre',
          ],
        });
        expect(l.map((e) => e.id), ['a1', 'e1']);
        expect(l[0].type, TypeContact.appel);
        expect(l[0].resultat, ResultatAppel.rappelPrevu);
        expect(l[0].auteur, 'Léa M.');
        expect(l[1].sujet, 'Offre');
        expect(l[1].resultat, isNull);
        expect(journalContactsDepuisJson(null), isEmpty);
        expect(journalContactsDepuisJson({'data': 'x'}), isEmpty);
      },
    );
  });

  group('contacts', () {
    testWidgets('nouveau contact : POST sans champ vide', (tester) async {
      final b = await _monter(tester);
      await _onglet(tester, 'Contacts');
      await tester.tap(find.text('＋ Contact'));
      await tester.pumpAndSettle();
      await _saisir(tester, 'Prénom', 'Marie');
      await _saisir(tester, 'Nom *', 'Durand');
      await tester.tap(_dans(FeuilleBase, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels.single.methode, 'POST');
      expect(b.ecriture.appels.single.chemin, '/clients/$_id/contacts');
      expect(b.ecriture.corps(0), {'prenom': 'Marie', 'nom': 'Durand'});
      expect(find.byType(FeuilleBase), findsNothing);
      expect(find.text('Contact ajouté.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('nom absent : message sous le champ, aucun envoi', (
      tester,
    ) async {
      final b = await _monter(tester);
      await _onglet(tester, 'Contacts');
      await tester.tap(find.text('＋ Contact'));
      await tester.pumpAndSettle();
      await tester.tap(_dans(FeuilleBase, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Nom requis'), findsOneWidget);
      expect(b.ecriture.appels, isEmpty);
    });

    testWidgets('modification : feuille préremplie, PATCH du contact', (
      tester,
    ) async {
      final b = await _monter(tester);
      await _onglet(tester, 'Contacts');
      await tester.tap(find.text('Léa Martin'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier le contact'), findsOneWidget);
      expect(find.text('Chef de rayon'), findsWidgets);
      await _saisir(tester, 'Poste', 'Directrice');
      await tester.tap(_dans(FeuilleBase, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels.single.methode, 'PATCH');
      expect(
        b.ecriture.appels.single.chemin,
        '/clients/$_id/contacts/$_contactId',
      );
      expect(b.ecriture.corps(0), {
        'prenom': 'Léa',
        'nom': 'Martin',
        'poste': 'Directrice',
        'fixe': null,
        'portable': '0612345678',
        'mail': null,
      });
      expect(find.text('Contact modifié.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('suppression : une confirmation puis DELETE', (tester) async {
      final b = await _monter(tester);
      await _onglet(tester, 'Contacts');
      await tester.tap(find.text('Léa Martin'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Supprimer le contact'));
      await tester.tap(find.text('Supprimer le contact'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels, isEmpty);
      await tester.tap(find.text('Confirmer la suppression'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels.single.methode, 'DELETE');
      expect(
        b.ecriture.appels.single.chemin,
        '/clients/$_id/contacts/$_contactId',
      );
      expect(find.text('Contact supprimé.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('refus de l\'API : feuille ouverte avec le message', (
      tester,
    ) async {
      final b = await _monter(tester);
      b.ecriture.pannes.add(_erreurApi(404));
      await _onglet(tester, 'Contacts');
      await tester.tap(find.text('＋ Contact'));
      await tester.pumpAndSettle();
      await _saisir(tester, 'Nom *', 'Durand');
      await tester.tap(_dans(FeuilleBase, 'Enregistrer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Magasin ou contact introuvable dans votre périmètre.'),
        findsOneWidget,
      );
      expect(find.byType(FeuilleBase), findsOneWidget);
    });

    testWidgets('démonstration : ni bouton ni feuille', (tester) async {
      await _monter(tester, roleApi: null);
      await _onglet(tester, 'Contacts');
      expect(find.text('＋ Contact'), findsNothing);
      await tester.tap(find.text('Léa Martin'));
      await tester.pumpAndSettle();
      expect(find.byType(FeuilleBase), findsNothing);
    });
  });

  group('périodicité', () {
    testWidgets('choix d\'une valeur : PATCH avec son identifiant', (
      tester,
    ) async {
      final b = await _monter(tester);
      await _onglet(tester, 'Infos');
      await tester.tap(find.text('Hebdomadaire'));
      await tester.pumpAndSettle();
      expect(_dans(FeuilleBase, 'Mensuelle'), findsOneWidget);
      expect(_dans(FeuilleBase, '✓'), findsOneWidget);
      await tester.tap(_dans(FeuilleBase, 'Mensuelle'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels.single.methode, 'PATCH');
      expect(b.ecriture.appels.single.chemin, '/clients/$_id/periodicite');
      expect(b.ecriture.corps(0), {'periodiciteId': _mensuelle});
      expect(find.text('Périodicité enregistrée.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('« Aucune » envoie null ; la valeur courante ne fait rien', (
      tester,
    ) async {
      final b = await _monter(tester);
      await _onglet(tester, 'Infos');
      await tester.tap(find.text('Hebdomadaire'));
      await tester.pumpAndSettle();
      await tester.tap(_dans(FeuilleBase, 'Hebdomadaire'));
      await tester.pumpAndSettle();
      expect(b.ecriture.appels, isEmpty);
      await tester.tap(_dans(FeuilleBase, 'Aucune'));
      await tester.pumpAndSettle();
      expect(b.ecriture.corps(0), {'periodiciteId': null});
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('refus : feuille ouverte avec le message', (tester) async {
      final b = await _monter(tester);
      b.ecriture.pannes.add(_erreurApi(404));
      await _onglet(tester, 'Infos');
      await tester.tap(find.text('Hebdomadaire'));
      await tester.pumpAndSettle();
      await tester.tap(_dans(FeuilleBase, 'Mensuelle'));
      await tester.pumpAndSettle();
      expect(
        find.text('Magasin ou contact introuvable dans votre périmètre.'),
        findsOneWidget,
      );
      expect(find.byType(FeuilleBase), findsOneWidget);
    });

    testWidgets('démonstration : la valeur n\'est pas touchable', (
      tester,
    ) async {
      await _monter(tester, roleApi: null);
      await _onglet(tester, 'Infos');
      await tester.tap(find.text('Hebdomadaire'));
      await tester.pumpAndSettle();
      expect(find.byType(FeuilleBase), findsNothing);
    });
  });
}
