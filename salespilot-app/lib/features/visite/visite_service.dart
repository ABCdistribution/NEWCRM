import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/db/app_database.dart';
import '../../core/sync/outbox_repository.dart';
import '../../core/sync/outbox_transport.dart';
import 'draft_repository.dart';
import 'visite_models.dart';

/// Cycle de vie d'une visite : brouillon → terminée (en file d'envoi) → synchronisée.
class VisiteService {
  VisiteService(this._db, this._drafts, this._outbox, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final DraftRepository _drafts;
  final OutboxRepository _outbox;
  final Uuid _uuid;

  /// Identifiant anti-doublon d'une photo : celui de la visite + son rang (≤ 64 caractères).
  static String photoId(String visiteId, int index) => '$visiteId-p${index + 1}';

  /// Reprend le brouillon ouvert du magasin, ou en crée un (un seul brouillon actif par magasin).
  Future<String> startOrResume({
    required String userId,
    required String clientId,
    required String libelle,
    String? planningId,
  }) async {
    final existing = await _drafts.openForClient(userId, clientId);
    if (existing != null) return existing.id;
    final id = _uuid.v4();
    await _drafts.save(
      id: id,
      userId: userId,
      clientId: clientId,
      planningId: planningId,
      libelle: libelle,
      data: VisiteData(motif: planningId != null ? 'Planifiée' : null).toJson(),
    );
    return id;
  }

  Future<void> saveData(VisiteDraft draft, VisiteData data) => _drafts.save(
        id: draft.id,
        userId: draft.userId,
        clientId: draft.clientId,
        prospectId: draft.prospectId,
        planningId: draft.planningId,
        libelle: draft.libelle,
        data: data.toJson(),
        state: draft.state,
      );

  /// Valide la visite : la passe en « terminée » et met en file la visite puis ses photos. Tout est écrit dans une
  /// seule transaction : soit tout est enregistré, soit rien. Renvoie les problèmes bloquants, le cas échéant.
  Future<List<String>> finish(VisiteDraft draft, List<Question> questions) async {
    final data = VisiteData.fromJson(jsonDecode(draft.dataJson) as Map<String, dynamic>);
    final controle = VisiteValidator.controle(data, questions);
    if (!controle.peutValider) return controle.bloquants;

    await _db.transaction(() async {
      await _outbox.enqueue(
        userId: draft.userId,
        kind: OutboxKind.visite,
        idApk: draft.id,
        payload: {
          'idApk': draft.id,
          if (draft.clientId != null) 'clientId': draft.clientId,
          if (draft.prospectId != null) 'prospectId': draft.prospectId,
          if (draft.planningId != null) 'planningId': draft.planningId,
          'motif': data.motif,
          if (data.dnAbc != null) 'dnAbc': data.dnAbc,
          if (data.dnConcurrence != null) 'dnConcurrence': data.dnConcurrence,
          if (data.dnGondoleHaute != null) 'dnGondoleHaute': data.dnGondoleHaute,
          if (data.dnGondoleBasse != null) 'dnGondoleBasse': data.dnGondoleBasse,
          if (data.commentaire.trim().isNotEmpty) 'commentaire': data.commentaire.trim(),
          'reponses': [
            for (final e in data.reponses.entries)
              if (e.value.trim().isNotEmpty) {'questionId': e.key, 'valeur': e.value.trim()},
          ],
        },
      );
      for (var i = 0; i < data.photos.length; i++) {
        await _outbox.enqueue(
          userId: draft.userId,
          kind: OutboxKind.photo,
          idApk: photoId(draft.id, i),
          payload: const {},
          filePath: data.photos[i],
          parentIdApk: draft.id,
        );
      }
      await _drafts.setState(draft.id, VisiteState.terminee);
    });
    return const [];
  }

  /// Rouvre une visite terminée pour la corriger — uniquement tant que rien n'est parti au serveur.
  /// Renvoie faux si la visite est déjà (au moins en partie) envoyée.
  Future<bool> reopen(VisiteDraft draft) async {
    if (draft.state != VisiteState.terminee) return false;
    final data = VisiteData.fromJson(jsonDecode(draft.dataJson) as Map<String, dynamic>);
    final ids = [draft.id, for (var i = 0; i < data.photos.length; i++) photoId(draft.id, i)];
    final visite = await _outbox.findByIdApk(draft.userId, OutboxKind.visite, draft.id);
    if (visite != null && visite.status == OutboxStatus.sent) return false;
    await _db.transaction(() async {
      await _outbox.deleteUnsent(draft.userId, ids);
      await _drafts.setState(draft.id, VisiteState.brouillon);
    });
    return true;
  }

  /// Passe en « synchronisée » les visites terminées dont la visite ET toutes les photos sont confirmées.
  Future<int> reconcile(String userId) async {
    var done = 0;
    final all = await _drafts.watchForUser(userId).first;
    for (final d in all.where((d) => d.state == VisiteState.terminee)) {
      final data = VisiteData.fromJson(jsonDecode(d.dataJson) as Map<String, dynamic>);
      final visite = await _outbox.findByIdApk(userId, OutboxKind.visite, d.id);
      if (visite == null || visite.status != OutboxStatus.sent) continue;
      var allSent = true;
      for (var i = 0; i < data.photos.length; i++) {
        final p = await _outbox.findByIdApk(userId, OutboxKind.photo, photoId(d.id, i));
        if (p == null || p.status != OutboxStatus.sent) allSent = false;
      }
      if (allSent) {
        await _drafts.setState(d.id, VisiteState.synchronisee);
        done++;
      }
    }
    return done;
  }

  /// Abandon d'un brouillon, après confirmation de l'utilisateur.
  Future<void> abandon(VisiteDraft draft) => _drafts.delete(draft.id);
}
