import 'dart:async';

import 'package:crm_app/core/api/erreur_api.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/auth/utilisateur.dart';
import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/sync/catalogue_provider.dart';
import 'package:crm_app/core/sync/domaines_provider.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/logic/nouveau_prospect.dart';
import 'package:crm_app/features/prospects/nouveau_prospect_screen.dart';
import 'package:crm_app/features/prospects/prospects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import '../../support/faux_ecriture.dart';

/// Création d'un prospect envoyée au CRM (`POST /prospects/apk`), connecté seulement.

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Ordre des champs de saisie du formulaire.
const int _enseigne = 0,
    _raison = 1,
    _ville = 2,
    _cp = 3,
    _tel = 4,
    _email = 5,
    _proba = 6,
    _pot = 7;

Utilisateur _moi(String role) => Utilisateur(
  id: 'moi',
  identifiant: 'x',
  nomAffiche: 'Jean DUPONT',
  email: null,
  roleApi: role,
);

Future<void> _saisir(WidgetTester tester, int champ, String texte) async {
  final f = find.byType(TextFormField).at(champ);
  await tester.ensureVisible(f);
  await tester.enterText(f, texte);
  await tester.pump();
}

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
  await tester.pumpAndSettle();
}

/// Formulaire connecté avec ce rôle d'API.
Future<(FauxEcriture, ProspectsSynchroFaux)> _monter(
  WidgetTester tester, {
  String roleApi = 'CHEF_SECTEUR',
  Role role = Role.cs,
  Widget ecran = const NouveauProspectScreen(),
}) async {
  DemoTemps.reel = true;
  addTearDown(() => DemoTemps.reel = false);
  final ecriture = FauxEcriture();
  final prospects = ProspectsSynchroFaux();
  await pumpEcran(
    tester,
    ecran,
    role: role,
    overrides: [
      sessionProvider.overrideWith(() => SessionNotifier(_moi(roleApi))),
      apiEcritureProvider.overrideWithValue(ecriture),
      prospectsSynchroProvider.overrideWith(() => prospects),
    ],
  );
  return (ecriture, prospects);
}

void main() {
  group('corps de POST /prospects/apk', () {
    test('valeurs d\'énumération : celles de l\'API', () {
      // PipelineEtape, SourceProspect et NiveauClass du CRM.
      const etapes = {
        'NOUVEAU',
        'CONTACTE',
        'PROPOSITION',
        'VISITE',
        'NEGOCIATION',
        'GAGNE',
        'PERDU',
      };
      for (final e in etapesCreation.keys) {
        expect(etapes, contains(e.code));
      }
      expect(sourcesProspect.keys, {
        'SALON',
        'RECOMMANDATION',
        'TERRAIN',
        'WEB',
      });
      expect(classesCreation, ['A', 'B', 'C', 'D', 'E', 'F', 'G']);
    });

    test('formulaire complet : tous les champs, sans secteur ni assigné', () {
      const f = BrouillonProspect(
        enseigne: ' Super Proxi ',
        raison: ' Dupont SAS ',
        ville: 'Lunel',
        cp: '34400',
        tel: '0467000000',
        email: 'a@b.fr',
        secteur: 's2',
        source: 'SALON',
        classe: 'C',
        etape: StatutProspect.negociation,
        proba: '65',
        pot: '120000,5',
      );
      expect(corpsProspect(f, idApk: 'I'), {
        'idApk': 'I',
        'raisonSociale': 'Dupont SAS',
        'enseigne': 'Super Proxi',
        'codePostal': '34400',
        'ville': 'Lunel',
        'telephone': '0467000000',
        'email': 'a@b.fr',
        'statut': 'NEGOCIATION',
        'probabilite': 65,
        'potentielCaAnnuel': 120000.5,
        'source': 'SALON',
        'niveauClass': 'C',
      });
    });

    test('formulaire minimal : seuls les champs obligatoires et l\'étape', () {
      expect(
        corpsProspect(
          const BrouillonProspect(enseigne: 'A', raison: 'B'),
          idApk: 'I',
        ),
        {
          'idApk': 'I',
          'raisonSociale': 'B',
          'enseigne': 'A',
          'statut': 'NOUVEAU',
        },
      );
    });

    test('validation : longueurs de l\'API et montant négatif', () {
      final e = validerProspect(
        BrouillonProspect(
          enseigne: 'a' * 201,
          raison: 'b' * 201,
          ville: 'c' * 101,
          cp: '1' * 11,
          tel: '2' * 21,
          email: 'x@y.fr${'z' * 200}',
          pot: '-1',
        ),
      );
      expect(e.keys, {
        'enseigne',
        'raison',
        'ville',
        'cp',
        'tel',
        'email',
        'pot',
      });
      expect(
        validerProspect(
          BrouillonProspect(
            enseigne: 'a' * 200,
            raison: 'b' * 200,
            ville: 'c' * 100,
            cp: '1' * 10,
            tel: '2' * 20,
            pot: '0',
          ),
        ),
        isEmpty,
      );
    });

    test('messages : celui de l\'API, sinon un texte selon le statut', () {
      expect(
        messageErreurProspect(
          const ErreurApi(
            TypeErreurApi.inattendue,
            statut: 400,
            detail: 'enseigne ne doit pas être vide',
          ),
        ),
        'enseigne ne doit pas être vide',
      );
      expect(
        messageErreurProspect(
          const ErreurApi(TypeErreurApi.inattendue, statut: 400),
        ),
        contains('refusées'),
      );
      expect(
        messageErreurProspect(const ErreurApi(TypeErreurApi.reseau)),
        'Serveur injoignable. Vérifiez votre connexion.',
      );
    });
  });

  group('formulaire connecté', () {
    testWidgets('création : corps envoyé, liste relue, retour aux prospects', (
      tester,
    ) async {
      final (ecriture, prospects) = await _monter(tester);
      await _saisir(tester, _enseigne, 'Super Proxi');
      await _saisir(tester, _raison, 'Dupont SAS');
      await _saisir(tester, _ville, 'Lunel');
      await _saisir(tester, _cp, '34400');
      await _saisir(tester, _tel, '0467000000');
      await _saisir(tester, _email, 'a@b.fr');
      await _saisir(tester, _proba, '65');
      await _saisir(tester, _pot, '120000');
      await _choisir(tester, '— non précisée —', 'Salon');
      await _choisir(tester, '— non renseignée —', 'Classe C');
      await _choisir(tester, 'Nouveau', 'Négociation');
      await _creer(tester);
      expect(ecriture.appels, hasLength(1));
      expect(ecriture.appels.single.methode, 'POST');
      expect(ecriture.appels.single.chemin, '/prospects/apk');
      final c = ecriture.corps(0);
      expect(c['idApk'], matches(_uuid));
      expect({...c}..remove('idApk'), {
        'raisonSociale': 'Dupont SAS',
        'enseigne': 'Super Proxi',
        'codePostal': '34400',
        'ville': 'Lunel',
        'telephone': '0467000000',
        'email': 'a@b.fr',
        'statut': 'NEGOCIATION',
        'probabilite': 65,
        'potentielCaAnnuel': 120000,
        'source': 'SALON',
        'niveauClass': 'C',
      });
      expect(prospects.rafraichis, 1);
      // Retour aux prospects (le toast l'annonce) ; rien n'est ajouté au store local.
      expect(find.text('Prospect créé.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('champs obligatoires manquants : aucun envoi', (tester) async {
      final (ecriture, prospects) = await _monter(tester);
      await _creer(tester);
      expect(find.text('Enseigne requise'), findsOneWidget);
      expect(find.text('Raison sociale requise'), findsOneWidget);
      expect(ecriture.appels, isEmpty);
      expect(prospects.rafraichis, 0);
    });

    testWidgets('champ trop long : erreur sous le champ, aucun envoi', (
      tester,
    ) async {
      final (ecriture, _) = await _monter(tester);
      await _saisir(tester, _enseigne, 'a' * 201);
      await _saisir(tester, _raison, 'Dupont SAS');
      await _creer(tester);
      expect(find.text('200 caractères au plus'), findsOneWidget);
      expect(ecriture.appels, isEmpty);
    });

    testWidgets(
      'erreur de l\'API : formulaire ouvert, même idApk au nouvel essai',
      (tester) async {
        final (ecriture, prospects) = await _monter(tester);
        ecriture.pannes.add(
          const ErreurApi(
            TypeErreurApi.inattendue,
            statut: 400,
            detail: 'email must be an email',
          ),
        );
        await _saisir(tester, _enseigne, 'Super Proxi');
        await _saisir(tester, _raison, 'Dupont SAS');
        await _creer(tester);
        expect(find.text('email must be an email'), findsOneWidget);
        expect(find.text('Prospect créé.'), findsNothing);
        expect(prospects.rafraichis, 0);
        await _creer(tester);
        expect(ecriture.appels, hasLength(2));
        expect(ecriture.corps(1)['idApk'], ecriture.corps(0)['idApk']);
        expect(prospects.rafraichis, 1);
        expect(find.text('Prospect créé.'), findsOneWidget);
      },
    );

    testWidgets('hors connexion : message sobre', (tester) async {
      final (ecriture, _) = await _monter(tester);
      ecriture.pannes.add(const ErreurApi(TypeErreurApi.reseau));
      await _saisir(tester, _enseigne, 'Super Proxi');
      await _saisir(tester, _raison, 'Dupont SAS');
      await _creer(tester);
      expect(
        find.text('Serveur injoignable. Vérifiez votre connexion.'),
        findsOneWidget,
      );
      expect(find.byType(NouveauProspectScreen), findsOneWidget);
    });

    testWidgets('bouton désactivé pendant l\'envoi : un seul appel', (
      tester,
    ) async {
      final (ecriture, prospects) = await _monter(tester);
      ecriture.attente = Completer<void>();
      await _saisir(tester, _enseigne, 'Super Proxi');
      await _saisir(tester, _raison, 'Dupont SAS');
      await tester.tap(find.text('＋ Créer le prospect'));
      await tester.pump();
      await tester.tap(find.text('＋ Créer le prospect'), warnIfMissed: false);
      await tester.pump();
      expect(ecriture.appels, hasLength(1));
      expect(
        tester
            .widget<AppBouton>(
              find.widgetWithText(AppBouton, '＋ Créer le prospect'),
            )
            .onPressed,
        isNull,
      );
      ecriture.attente!.complete();
      await tester.pumpAndSettle();
      expect(ecriture.appels, hasLength(1));
      expect(prospects.rafraichis, 1);
    });

    testWidgets('démonstration : prospect local, aucun envoi', (tester) async {
      final ecriture = FauxEcriture();
      await pumpEcran(
        tester,
        const NouveauProspectScreen(),
        role: Role.cs,
        overrides: [apiEcritureProvider.overrideWithValue(ecriture)],
      );
      await _saisir(tester, _enseigne, 'Super Proxi');
      await _saisir(tester, _raison, 'Dupont SAS');
      await tester.tap(find.text('＋ Créer le prospect'));
      await tester.pump();
      expect(ecriture.appels, isEmpty);
    });
  });

  group('droit de création', () {
    testWidgets('direction : pas de bouton « Nouveau prospect »', (
      tester,
    ) async {
      await _monter(
        tester,
        roleApi: 'DIRECTION',
        role: Role.dir,
        ecran: const ProspectsScreen(),
      );
      expect(find.text('＋ Nouveau prospect'), findsNothing);
    });

    for (final r in ['CHEF_SECTEUR', 'DIRECTEUR_REGIONAL', 'ADMIN']) {
      testWidgets('$r : bouton « Nouveau prospect » présent', (tester) async {
        await _monter(
          tester,
          roleApi: r,
          role: r == 'CHEF_SECTEUR' ? Role.cs : Role.dir,
          ecran: const ProspectsScreen(),
        );
        expect(find.text('＋ Nouveau prospect'), findsOneWidget);
      });
    }

    testWidgets('démonstration : le directeur garde le bouton', (tester) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.dir);
      expect(find.text('＋ Nouveau prospect'), findsOneWidget);
    });
  });
}
