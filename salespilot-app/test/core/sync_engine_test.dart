import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salespilot/core/db/app_database.dart';
import 'package:salespilot/core/sync/outbox_repository.dart';
import 'package:salespilot/core/sync/outbox_transport.dart';
import 'package:salespilot/core/sync/sync_engine.dart';

/// Transport simulé : un « serveur » qui retient les idApk déjà reçus (comme l'API : un doublon est reconnu).
class FakeServer implements OutboxTransport {
  final received = <String, String>{}; // idApk -> serverId
  final sendLog = <String>[]; // tous les envois tentés, dans l'ordre
  final scripted = <String, List<SendResult>>{}; // idApk -> réponses forcées, consommées dans l'ordre
  var _n = 0;

  @override
  Future<SendResult> send(OutboxItem item, {String? parentServerId}) async {
    sendLog.add('${item.kind}:${item.idApk}');
    final forced = scripted[item.idApk];
    if (forced != null && forced.isNotEmpty) return forced.removeAt(0);
    if (item.kind == OutboxKind.photo && parentServerId == null) return const Rejected('photo sans visite');
    // Doublon reconnu = succès, sans créer un second enregistrement.
    final existing = received[item.idApk];
    if (existing != null) return Sent(serverId: existing);
    final id = 'srv-${++_n}';
    received[item.idApk] = id;
    return Sent(serverId: id);
  }
}

void main() {
  late AppDatabase db;
  late OutboxRepository repo;
  late FakeServer server;
  late SyncEngine engine;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 26, 9);
    repo = OutboxRepository(db, clock: () => now);
    server = FakeServer();
    engine = SyncEngine(repo: repo, transport: server, backoff: (_) => const Duration(seconds: 30));
  });

  tearDown(() => db.close());

  Future<void> visiteAvecPhotos(String user, String idApk, {int photos = 2}) async {
    await repo.enqueue(userId: user, kind: OutboxKind.visite, idApk: idApk, payload: {'idApk': idApk});
    for (var i = 1; i <= photos; i++) {
      await repo.enqueue(
        userId: user,
        kind: OutboxKind.photo,
        idApk: '$idApk-p$i',
        payload: {},
        filePath: '/tmp/$i.jpg',
        parentIdApk: idApk,
      );
    }
  }

  test('une visite part avant ses photos, et tout est confirmé', () async {
    // Les photos sont créées AVANT la visite dans la base : l'ordre d'envoi ne doit pas en dépendre.
    await repo.enqueue(userId: 'u1', kind: OutboxKind.photo, idApk: 'v1-p1', payload: {}, filePath: 'a.jpg', parentIdApk: 'v1');
    await repo.enqueue(userId: 'u1', kind: OutboxKind.visite, idApk: 'v1', payload: {});

    final r1 = await engine.run('u1');
    // 1re passe : la photo (parent pas encore parti) est bloquée, la visite part.
    expect(server.sendLog, ['visite:v1']);
    expect(r1.sent, 1);
    expect(r1.blocked, 1);

    final r2 = await engine.run('u1');
    expect(server.sendLog, ['visite:v1', 'photo:v1-p1']);
    expect(r2.sent, 1);
    expect(await repo.watchPendingCount('u1').first, 0);
  });

  test('aucun doublon : une visite renvoyée 5 fois reste unique côté serveur', () async {
    await visiteAvecPhotos('u1', 'v1', photos: 3);
    // Le serveur répond « coupure » 4 fois de suite sur la visite avant d'accepter.
    server.scripted['v1'] = List<SendResult>.filled(4, const RetryLater('coupure'), growable: true);
    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(minutes: 1)); // l'attente avant nouvel essai est écoulée
      await engine.run('u1');
    }
    expect(server.received.keys.where((k) => k == 'v1').length, 1);
    expect(server.received.length, 4); // 1 visite + 3 photos, une seule fois chacune
    expect(await repo.watchPendingCount('u1').first, 0);
  });

  test('l\'enqueue est idempotent : le même idApk ne crée pas un second élément', () async {
    final a = await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'CMD1', payload: {'x': 1});
    final b = await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'CMD1', payload: {'x': 2});
    expect(b, a);
    expect(await repo.watchPendingCount('u1').first, 1);
  });

  test('un échec temporaire attend avant de réessayer, sans perdre l\'élément', () async {
    await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'C1', payload: {});
    server.scripted['C1'] = [const RetryLater('réseau')];

    final r1 = await engine.run('u1');
    expect(r1.retry, 1);
    expect(await repo.watchPendingCount('u1').first, 1);

    // Trop tôt : l'échéance n'est pas passée, rien n'est renvoyé.
    final r2 = await engine.run('u1');
    expect(r2.hasNothing, isTrue);

    now = now.add(const Duration(seconds: 31));
    final r3 = await engine.run('u1');
    expect(r3.sent, 1);
    expect(await repo.watchPendingCount('u1').first, 0);
  });

  test('un refus définitif reste en erreur avec son motif et ne bloque pas les éléments indépendants', () async {
    await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'C1', payload: {});
    await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'C2', payload: {});
    server.scripted['C1'] = [const Rejected('Client inconnu')];

    final r = await engine.run('u1');
    expect(r.rejected, 1);
    expect(r.sent, 1);
    final c1 = await repo.findByIdApk('u1', OutboxKind.commande, 'C1');
    expect(c1!.status, OutboxStatus.error);
    expect(c1.lastError, 'Client inconnu');
    // Toujours compté dans l'« à traiter » : jamais d'échec silencieux.
    expect(await repo.watchPendingCount('u1').first, 1);
  });

  test('un élément dépendant d\'un parent en erreur passe en erreur, sans être envoyé', () async {
    await visiteAvecPhotos('u1', 'v1', photos: 2);
    server.scripted['v1'] = [const Rejected('Visite refusée')];

    await engine.run('u1');
    expect(server.sendLog, ['visite:v1']); // aucune photo envoyée sans visite
    for (final idApk in ['v1-p1', 'v1-p2']) {
      final p = await repo.findByIdApk('u1', OutboxKind.photo, idApk);
      expect(p!.status, OutboxStatus.error);
    }
    expect(await repo.watchPendingCount('u1').first, 3);
  });

  test('session expirée : l\'envoi s\'arrête, rien n\'est perdu ni compté comme essai', () async {
    await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'C1', payload: {});
    await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'C2', payload: {});
    server.scripted['C1'] = [const Unauthorized()];

    final r = await engine.run('u1');
    expect(r.sessionExpired, isTrue);
    expect(server.sendLog, ['commande:C1']); // C2 n'est pas tenté
    final c1 = await repo.findByIdApk('u1', OutboxKind.commande, 'C1');
    expect(c1!.status, OutboxStatus.pending);
    expect(c1.attempts, 0);
    expect(await repo.watchPendingCount('u1').first, 2);

    // Après reconnexion, tout part.
    final r2 = await engine.run('u1');
    expect(r2.sent, 2);
  });

  test('cloisonnement : un utilisateur n\'envoie ni ne compte les éléments d\'un autre', () async {
    await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'C1', payload: {});
    await repo.enqueue(userId: 'u2', kind: OutboxKind.commande, idApk: 'C2', payload: {});

    await engine.run('u2');
    expect(server.sendLog, ['commande:C2']);
    expect(await repo.watchPendingCount('u1').first, 1);
    expect(await repo.watchPendingCount('u2').first, 0);
    expect(await repo.countUnsentOfOthers('u2'), 1);
  });

  test('une application tuée en plein envoi reprend l\'élément « en cours » au lancement suivant', () async {
    final id = await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'C1', payload: {});
    await repo.markSending(id); // simule un arrêt brutal pendant l'envoi

    final r = await engine.run('u1');
    expect(r.sent, 1);
  });

  test('« Réessayer » remet les éléments en erreur dans la file', () async {
    await repo.enqueue(userId: 'u1', kind: OutboxKind.commande, idApk: 'C1', payload: {});
    server.scripted['C1'] = [const Rejected('temporaire côté métier')];
    await engine.run('u1');

    await repo.retryAllErrors('u1');
    final r = await engine.run('u1');
    expect(r.sent, 1);
  });

  test('une réouverture avant envoi supprime les éléments non envoyés, jamais ceux déjà confirmés', () async {
    await visiteAvecPhotos('u1', 'v1', photos: 1);
    await engine.run('u1');
    await engine.run('u1'); // visite et photo confirmées

    final removed = await repo.deleteUnsent('u1', ['v1', 'v1-p1']);
    expect(removed, 0);
  });

  group('classement des erreurs HTTP', () {
    DioException err(int? status) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: status == null
              ? null
              : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: {'message': 'Motif'}),
        );

    test('réseau coupé et erreurs serveur : à réessayer', () {
      expect(HttpOutboxTransport.classify(err(null)), isA<RetryLater>());
      expect(HttpOutboxTransport.classify(err(500)), isA<RetryLater>());
      expect(HttpOutboxTransport.classify(err(503)), isA<RetryLater>());
      expect(HttpOutboxTransport.classify(err(429)), isA<RetryLater>());
    });
    test('401 : session expirée', () {
      expect(HttpOutboxTransport.classify(err(401)), isA<Unauthorized>());
    });
    test('400, 403, 404 : refus définitif avec le motif du serveur', () {
      for (final s in [400, 403, 404]) {
        final r = HttpOutboxTransport.classify(err(s));
        expect(r, isA<Rejected>());
        expect((r as Rejected).reason, 'Motif');
      }
    });
  });
}
