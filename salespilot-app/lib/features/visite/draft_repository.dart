import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';

/// États d'une visite (CDC §3.4).
abstract final class VisiteState {
  /// Commencée, non validée, modifiable.
  static const brouillon = 'brouillon';

  /// Validée par l'utilisateur, en file d'envoi (modifiable en la rouvrant tant qu'elle n'est pas envoyée).
  static const terminee = 'terminee';

  /// Reçue et confirmée par le serveur.
  static const synchronisee = 'synchronisee';
}

/// Brouillons de visite : écrits à chaque saisie, repris automatiquement au prochain lancement.
class DraftRepository {
  DraftRepository(this._db, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  $VisiteDraftsTable get _t => _db.visiteDrafts;

  Future<VisiteDraft?> get(String id) => (_db.select(_t)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Brouillon ouvert pour un magasin : un seul brouillon actif par magasin (CDC §10, question 17).
  Future<VisiteDraft?> openForClient(String userId, String clientId) {
    return (_db.select(_t)
          ..where((r) => r.userId.equals(userId) & r.clientId.equals(clientId) & r.state.equals(VisiteState.brouillon))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Crée ou met à jour un brouillon. Appelé à chaque saisie : aucune action « enregistrer » n'existe.
  Future<void> save({
    required String id,
    required String userId,
    String? clientId,
    String? prospectId,
    String? planningId,
    String libelle = '',
    required Map<String, dynamic> data,
    String state = VisiteState.brouillon,
  }) async {
    final now = _now();
    final existing = await get(id);
    await _db.into(_t).insertOnConflictUpdate(
          VisiteDraftsCompanion(
            id: Value(id),
            userId: Value(userId),
            clientId: Value(clientId),
            prospectId: Value(prospectId),
            planningId: Value(planningId),
            libelle: Value(libelle),
            state: Value(state),
            dataJson: Value(jsonEncode(data)),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> setState(String id, String state) =>
      (_db.update(_t)..where((r) => r.id.equals(id))).write(VisiteDraftsCompanion(state: Value(state), updatedAt: Value(_now())));

  /// Abandon explicite d'un brouillon (jamais automatique).
  Future<void> delete(String id) => (_db.delete(_t)..where((r) => r.id.equals(id) & r.state.equals(VisiteState.brouillon))).go();

  Stream<List<VisiteDraft>> watchForUser(String userId) {
    return (_db.select(_t)
          ..where((r) => r.userId.equals(userId))
          ..orderBy([(r) => OrderingTerm.desc(r.updatedAt)]))
        .watch();
  }

  Stream<VisiteDraft?> watch(String id) => (_db.select(_t)..where((r) => r.id.equals(id))).watchSingleOrNull();
}
