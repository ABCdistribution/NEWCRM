import 'package:crm_app/core/data/detail_prospect.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/lanceur_factice.dart';

void main() {
  group('uriAppel', () {
    test('nettoie le numéro', () {
      expect(uriAppel('01 23 45 67 89').toString(), 'tel:0123456789');
      expect(uriAppel('01.23.45.67.89').toString(), 'tel:0123456789');
      expect(uriAppel(' (01) 23-45-67-89 ').toString(), 'tel:0123456789');
    });

    test('garde le « + » et convertit « 00 »', () {
      expect(uriAppel('+33 1 23 45 67 89').toString(), 'tel:+33123456789');
      expect(uriAppel('0033 1 23 45 67 89').toString(), 'tel:+33123456789');
    });

    test('vide ou sans chiffres : pas d’appel', () {
      expect(uriAppel(null), isNull);
      expect(uriAppel('  '), isNull);
      expect(uriAppel('—'), isNull);
      expect(uriAppel('12'), isNull);
    });
  });

  group('uriMail', () {
    test('adresse valide', () {
      expect(uriMail(' a.b@exemple.fr ').toString(), 'mailto:a.b@exemple.fr');
    });

    test('adresse absente ou invalide : pas de mail', () {
      expect(uriMail(null), isNull);
      expect(uriMail(''), isNull);
      expect(uriMail('pas un mail'), isNull);
      expect(uriMail('a@b'), isNull);
    });
  });

  group('uriItineraire', () {
    const adresse = '12 rue du Port, 34400 Lunel';

    test('Android : geo avec adresse encodée', () {
      expect(
        uriItineraire(adresse, plateforme: TargetPlatform.android).toString(),
        'geo:0,0?q=12%20rue%20du%20Port%2C%2034400%20Lunel',
      );
    });

    test('ailleurs : lien Google Maps', () {
      final u = uriItineraire(adresse, plateforme: TargetPlatform.iOS)!;
      expect(u.scheme, 'https');
      expect(u.host, 'www.google.com');
      expect(u.queryParameters, {'api': '1', 'query': adresse});
    });

    test('adresse vide : pas d’itinéraire', () {
      expect(uriItineraire(null), isNull);
      expect(uriItineraire('  '), isNull);
      expect(uriItineraire('—'), isNull);
    });
  });

  group('ActionRapide inactive', () {
    testWidgets('estompée et sans effet au toucher', (tester) async {
      var touches = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RangeeActions(
              actions: [
                ActionRapide(label: 'Actif', onTap: () => touches++),
                const ActionRapide(label: 'Inactif', onTap: null),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Inactif'));
      expect(touches, 0);
      await tester.tap(find.text('Actif'));
      expect(touches, 1);
      expect(find.byType(Opacity), findsOneWidget);
    });
  });

  group('lancerExterne', () {
    testWidgets('échec : toast sobre ; succès : rien', (tester) async {
      late BuildContext contexte;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              contexte = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final ok = LanceurFactice();
      await lancerExterne(contexte, ok, Uri.parse('tel:0123456789'));
      await tester.pump();
      expect(find.textContaining('Impossible'), findsNothing);
      expect(ok.ouverts, hasLength(1));

      await lancerExterne(
        contexte,
        LanceurFactice(reussit: false),
        Uri.parse('tel:0123456789'),
      );
      await tester.pump();
      expect(find.text("Impossible d'ouvrir l'application."), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('detailProspectDepuisJson : coordonnées', () {
    test('fiche, sinon premier contact', () {
      final d = detailProspectDepuisJson({
        'telephone': '04 67 00 11 22',
        'email': 'contact@exemple.fr',
        'adresse1': '12 rue du Port',
        'codePostal': '34400',
        'ville': 'Lunel',
        'contacts': [
          {'nom': 'Durand', 'portable': '06 00 00 00 00'},
        ],
      }, null);
      expect(d.telephone, '04 67 00 11 22');
      expect(d.mail, 'contact@exemple.fr');
      expect(d.adresse, '12 rue du Port, 34400 Lunel');

      final c = detailProspectDepuisJson({
        'contacts': [
          {'nom': 'Durand', 'prenom': 'Paul', 'portable': '06 00 00 00 00'},
          {'nom': 'Martin', 'mail': 'm@exemple.fr'},
        ],
      }, null);
      expect(c.telephone, '06 00 00 00 00');
      expect(c.mail, 'm@exemple.fr');
      expect(c.adresse, isNull);
      expect(c.contact, 'Paul Durand');
    });
  });
}
