import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crm_app/core/api/api_client.dart';
import 'package:crm_app/core/api/erreur_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Requête reçue par le serveur local.
class _Recue {
  _Recue(this.methode, this.chemin, this.entetes, this.corps);

  final String methode;
  final String chemin;
  final HttpHeaders entetes;
  final List<int> corps;
}

void main() {
  late HttpServer serveur;
  late List<_Recue> recues;
  var statut = 201;
  var reponse = '{"id":"p1","dejaSynchronise":false}';

  setUp(() async {
    recues = [];
    statut = 201;
    reponse = '{"id":"p1","dejaSynchronise":false}';
    serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      serveur.forEach((r) async {
        final corps = <int>[];
        await for (final morceau in r) {
          corps.addAll(morceau);
        }
        recues.add(_Recue(r.method, r.uri.path, r.headers, corps));
        r.response
          ..statusCode = statut
          ..headers.contentType = ContentType.json
          ..write(reponse);
        await r.response.close();
      }),
    );
  });

  tearDown(() => serveur.close(force: true));

  ApiClient client({String? jeton = 'jeton-1'}) => ApiClient(
    jeton: () async => jeton,
    urlBase: 'http://127.0.0.1:${serveur.port}',
  );

  test('corpsMultipart : champs texte puis fichier, séparés par la limite', () {
    final corps = corpsMultipart(
      limite: 'LIM',
      champ: 'photo',
      nomFichier: 'p.jpg',
      typeMime: 'image/jpeg',
      octets: [1, 2, 3],
      champs: {'idApk': 'Vabc-4', 'etape': 'arrivee'},
    );
    final texte = latin1.decode(corps);
    expect(
      texte,
      '--LIM\r\nContent-Disposition: form-data; name="idApk"\r\n\r\nVabc-4\r\n'
      '--LIM\r\nContent-Disposition: form-data; name="etape"\r\n\r\narrivee\r\n'
      '--LIM\r\nContent-Disposition: form-data; name="photo"; filename="p.jpg"\r\n'
      'Content-Type: image/jpeg\r\n\r\n\x01\x02\x03\r\n--LIM--\r\n',
    );
  });

  test(
    'televerser : POST multipart authentifié, champ « photo », idApk et étape',
    () async {
      final octets = List<int>.generate(1000, (i) => i % 256);
      final r = await client().televerser(
        '/visites/abc/photos',
        champ: 'photo',
        nomFichier: 'x.jpg',
        typeMime: 'image/jpeg',
        octets: octets,
        champs: {'idApk': 'Vabc-1', 'etape': 'rayonFin'},
      );
      expect(r, {'id': 'p1', 'dejaSynchronise': false});
      final q = recues.single;
      expect(q.methode, 'POST');
      expect(q.chemin, '/visites/abc/photos');
      expect(
        q.entetes.value(HttpHeaders.authorizationHeader),
        'Bearer jeton-1',
      );
      final type = q.entetes.contentType!;
      expect(type.mimeType, 'multipart/form-data');
      final limite = type.parameters['boundary']!;
      expect(q.entetes.contentLength, q.corps.length);
      final texte = latin1.decode(q.corps);
      expect(texte, contains('--$limite\r\n'));
      expect(texte, contains('name="idApk"\r\n\r\nVabc-1\r\n'));
      expect(texte, contains('name="etape"\r\n\r\nrayonFin\r\n'));
      expect(texte, contains('name="photo"; filename="x.jpg"'));
      expect(texte, endsWith('\r\n--$limite--\r\n'));
      // Les octets de l'image arrivent tels quels.
      final debut = texte.indexOf('Content-Type: image/jpeg\r\n\r\n') + 28;
      expect(q.corps.sublist(debut, debut + 1000), octets);
    },
  );

  test('refus de l\'API : message en français et statut gardés', () async {
    statut = 400;
    reponse = '{"statusCode":400,"message":"Le fichier doit être une image."}';
    await expectLater(
      client().televerser(
        '/visites/abc/photos',
        champ: 'photo',
        nomFichier: 'x.jpg',
        typeMime: 'image/jpeg',
        octets: [1],
      ),
      throwsA(
        isA<ErreurApi>()
            .having((e) => e.statut, 'statut', 400)
            .having(
              (e) => e.message,
              'message',
              'Le fichier doit être une image.',
            ),
      ),
    );
  });

  test('sans jeton : session expirée, rien n\'est envoyé', () async {
    await expectLater(
      client(jeton: null).televerser(
        '/visites/abc/photos',
        champ: 'photo',
        nomFichier: 'x.jpg',
        typeMime: 'image/jpeg',
        octets: [1],
      ),
      throwsA(
        isA<ErreurApi>().having(
          (e) => e.type,
          'type',
          TypeErreurApi.sessionExpiree,
        ),
      ),
    );
    expect(recues, isEmpty);
  });

  test('serveur injoignable : erreur réseau', () async {
    final c = ApiClient(jeton: () async => 'j', urlBase: 'http://127.0.0.1:1');
    await expectLater(
      c.televerser(
        '/visites/abc/photos',
        champ: 'photo',
        nomFichier: 'x.jpg',
        typeMime: 'image/jpeg',
        octets: [1],
      ),
      throwsA(
        isA<ErreurApi>().having((e) => e.type, 'type', TypeErreurApi.reseau),
      ),
    );
  });

  test('envoyer (JSON) : inchangé, corps JSON et réponse décodée', () async {
    statut = 200;
    reponse = '{"id":"c1"}';
    final r = await client().envoyer('POST', '/commandes/apk', corps: {'a': 1});
    expect(r, {'id': 'c1'});
    final q = recues.single;
    expect(q.entetes.contentType!.mimeType, 'application/json');
    expect(utf8.decode(q.corps), '{"a":1}');
  });
}
