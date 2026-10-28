import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// File d'envoi (« outbox ») : toute saisie terrain y est écrite AVANT d'être envoyée.
/// Un envoi rejoué ne crée jamais de doublon : le serveur reconnaît l'[idApk].
class OutboxItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Propriétaire : la file est cloisonnée par utilisateur (CDC §4.2).
  TextColumn get userId => text()();

  /// Type d'envoi : visite, visite_commerciale, photo, commande, note…
  TextColumn get kind => text()();

  /// Identifiant anti-doublon généré par l'application.
  TextColumn get idApk => text()();

  /// Corps de la requête, en JSON.
  TextColumn get payload => text()();

  /// Fichier local à envoyer (photos).
  TextColumn get filePath => text().nullable()();

  /// Élément dont celui-ci dépend (une photo dépend de sa visite).
  TextColumn get parentIdApk => text().nullable()();

  /// pending (à envoyer) · sending (en cours) · sent (confirmé par le serveur) · error (refus définitif).
  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  /// Identifiant serveur renvoyé à l'envoi (utile aux éléments dépendants).
  TextColumn get serverId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get sentAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {userId, kind, idApk},
      ];
}

/// Brouillons de visite : sauvegardés à chaque saisie, repris au prochain lancement.
class VisiteDrafts extends Table {
  /// Identifiant anti-doublon de la visite (sert aussi d'identifiant local).
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get clientId => text().nullable()();
  TextColumn get prospectId => text().nullable()();
  TextColumn get planningId => text().nullable()();

  /// Libellé du magasin, pour l'affichage hors ligne.
  TextColumn get libelle => text().withDefault(const Constant(''))();

  /// brouillon · terminee (en attente d'envoi) · synchronisee.
  TextColumn get state => text().withDefault(const Constant('brouillon'))();

  /// Saisie complète (motif, DN, questionnaire, commentaire, photos locales) en JSON.
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

/// Cache des référentiels répliqués (tournée, magasins, catalogue…), par utilisateur.
class CacheEntries extends Table {
  /// Clé de la forme `userId:clé`.
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>>? get primaryKey => {key};
}

@DriftDatabase(tables: [OutboxItems, VisiteDrafts, CacheEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Base locale de l'application. TODO(sécurité, CDC §6.2) : chiffrement SQLCipher, clé protégée
  /// par le Keystore — test bloquant avant lancement, pas encore fait.
  AppDatabase.open() : super(driftDatabase(name: 'salespilot'));

  @override
  int get schemaVersion => 1;
}
