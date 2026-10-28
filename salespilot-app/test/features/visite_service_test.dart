import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salespilot/core/db/app_database.dart';
import 'package:salespilot/core/sync/outbox_repository.dart';
import 'package:salespilot/core/sync/outbox_transport.dart';
import 'package:salespilot/core/sync/sync_engine.dart';
import 'package:salespilot/features/visite/draft_repository.dart';
import 'package:salespilot/features/visite/visite_models.dart';
import 'package:salespilot/features/visite/visite_service.dart';

class AcceptAll implements OutboxTransport {
  var _n = 0;
  @override
  Future<SendResult> send(OutboxItem item, {String? parentServerId}) async => Sent(serverId: 'srv-${++_n}');
}

void main() {
  late AppDatabase db;
  late DraftRepository drafts;
  late OutboxRepository outbox;
  late VisiteService service;

  const user = 'u1';
  const questions = [
    Question(id: 'q1', libelle: 'Facing respecté ?', type: 'CASE_A_COCHER', obligatoire: true),
    Question(id: 'q2', libelle: 'Remarque', type: 'TEXTE', obligatoire: false),
  ];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    drafts = DraftRepository(db);
    outbox = OutboxRepository(db);
    service = VisiteService(db, drafts, outbox);
  });
  tearDown(() => db.close());

  Future<VisiteDraft> nouvelle({String clientId = 'c1', String? planning = 'p1'}) async {
    final id = await service.startOrResume(userId: user, clientId: clientId, libelle: 'Carrefour Lyon', planningId: planning);
    return (await drafts.get(id))!;
  }

  test('un seul brouillon actif par magasin : on reprend celui qui existe', () async {
    final a = await nouvelle();
    final b = await nouvelle();
    expect(b.id, a.id);
    final autre = await nouvelle(clientId: 'c2');
    expect(autre.id, isNot(a.id));
  });

  test('la saisie est écrite à chaque modification et retrouvée à la réouverture', () async {
    var d = await nouvelle();
    await service.saveData(d, const VisiteData(motif: 'Planifiée', commentaire: 'Rupture sur le linéaire', photos: ['/p/1.jpg']));
    d = (await drafts.get(d.id))!;
    final data = VisiteData.fromJson(jsonDecode(d.dataJson) as Map<String, dynamic>);
    expect(data.commentaire, 'Rupture sur le linéaire');
    expect(data.photos, ['/p/1.jpg']);
    expect(d.state, VisiteState.brouillon);
  });

  test('on ne peut pas valider une visite incomplète', () async {
    var d = await nouvelle(planning: null); // pas de motif par défaut
    final bloquants = await service.finish(d, questions);
    expect(bloquants, hasLength(2)); // motif manquant + question obligatoire sans réponse
    expect(await outbox.watchPendingCount(user).first, 0); // rien n'a été mis en file
    d = (await drafts.get(d.id))!;
    expect(d.state, VisiteState.brouillon);
  });

  test('valider met la visite puis ses photos en file, dans une transaction, et passe en « terminée »', () async {
    var d = await nouvelle();
    await service.saveData(d, const VisiteData(motif: 'Planifiée', reponses: {'q1': 'oui'}, photos: ['/p/1.jpg', '/p/2.jpg']));
    d = (await drafts.get(d.id))!;

    expect(await service.finish(d, questions), isEmpty);
    expect((await drafts.get(d.id))!.state, VisiteState.terminee);
    expect(await outbox.watchPendingCount(user).first, 3); // 1 visite + 2 photos

    final visite = await outbox.findByIdApk(user, OutboxKind.visite, d.id);
    final payload = jsonDecode(visite!.payload) as Map<String, dynamic>;
    expect(payload['idApk'], d.id);
    expect(payload['planningId'], 'p1');
    expect(payload['reponses'], [
      {'questionId': 'q1', 'valeur': 'oui'},
    ]);
    final photo = await outbox.findByIdApk(user, OutboxKind.photo, VisiteService.photoId(d.id, 0));
    expect(photo!.parentIdApk, d.id);
  });

  test('valider deux fois ne duplique rien', () async {
    var d = await nouvelle();
    await service.saveData(d, const VisiteData(motif: 'Planifiée', reponses: {'q1': 'oui'}, photos: ['/p/1.jpg']));
    d = (await drafts.get(d.id))!;
    await service.finish(d, questions);
    await service.finish((await drafts.get(d.id))!, questions);
    expect(await outbox.watchPendingCount(user).first, 2);
  });

  test('rouvrir avant envoi retire les éléments de la file et redonne un brouillon modifiable', () async {
    var d = await nouvelle();
    await service.saveData(d, const VisiteData(motif: 'Planifiée', reponses: {'q1': 'oui'}, photos: ['/p/1.jpg']));
    d = (await drafts.get(d.id))!;
    await service.finish(d, questions);

    expect(await service.reopen((await drafts.get(d.id))!), isTrue);
    expect((await drafts.get(d.id))!.state, VisiteState.brouillon);
    expect(await outbox.watchPendingCount(user).first, 0);
  });

  test('on ne rouvre plus une visite déjà envoyée', () async {
    var d = await nouvelle();
    await service.saveData(d, const VisiteData(motif: 'Planifiée', reponses: {'q1': 'oui'}));
    d = (await drafts.get(d.id))!;
    await service.finish(d, questions);
    await SyncEngine(repo: outbox, transport: AcceptAll()).run(user);

    expect(await service.reopen((await drafts.get(d.id))!), isFalse);
  });

  test('« synchronisée » seulement quand la visite ET toutes les photos sont confirmées', () async {
    var d = await nouvelle();
    await service.saveData(d, const VisiteData(motif: 'Planifiée', reponses: {'q1': 'oui'}, photos: ['/p/1.jpg']));
    d = (await drafts.get(d.id))!;
    await service.finish(d, questions);

    // Seule la visite est confirmée : la photo n'est pas encore partie.
    final visite = await outbox.findByIdApk(user, OutboxKind.visite, d.id);
    await outbox.markSent(visite!.id, serverId: 'srv-1');
    expect(await service.reconcile(user), 0);
    expect((await drafts.get(d.id))!.state, VisiteState.terminee);

    final photo = await outbox.findByIdApk(user, OutboxKind.photo, VisiteService.photoId(d.id, 0));
    await outbox.markSent(photo!.id, serverId: 'srv-2');
    expect(await service.reconcile(user), 1);
    expect((await drafts.get(d.id))!.state, VisiteState.synchronisee);
  });

  group('contrôle avant validation', () {
    test('compte les questions répondues et les photos', () {
      const d = VisiteData(motif: 'Planifiée', reponses: {'q1': 'oui', 'q2': '  '}, photos: ['a', 'b']);
      final c = VisiteValidator.controle(d, questions);
      expect(c.peutValider, isTrue);
      expect(c.questionsRepondues, 1); // une réponse vide ne compte pas
      expect(c.questionsTotal, 2);
      expect(c.photos, 2);
    });

    test('une question facultative sans réponse ne bloque pas', () {
      const d = VisiteData(motif: 'Planifiée', reponses: {'q1': 'oui'});
      expect(VisiteValidator.controle(d, questions).peutValider, isTrue);
    });
  });
}
