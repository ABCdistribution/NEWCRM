import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Métadonnées de la base locale (clé / valeur) : date de création, dates de mise à jour, curseurs à venir.
class MetaBase extends Table {
  TextColumn get cle => text()();
  TextColumn get valeur => text()();
  DateTimeColumn get misAJourLe => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {cle};
}

/// Articles du catalogue téléchargés depuis le CRM (`GET /articles`), lus hors connexion.
@DataClassName('ArticleLocal')
class ArticlesLocaux extends Table {
  /// Identifiant serveur (UUID).
  TextColumn get id => text()();
  TextColumn get codeAs400 => text()();
  TextColumn get libelle => text()();
  TextColumn get gencode => text().nullable()();
  TextColumn get marque => text().nullable()();
  TextColumn get famille => text().nullable()();
  TextColumn get gamme => text().nullable()();
  TextColumn get typeArticle => text().nullable()();
  TextColumn get statut => text().nullable()();
  IntColumn get pcb => integer().nullable()();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  BoolColumn get actif => boolean().withDefault(const Constant(true))();

  /// Prix indicatif HT (premier tarif).
  RealColumn get prix => real().nullable()();
  BoolColumn get enPromo => boolean().withDefault(const Constant(false))();
  TextColumn get promoLibelle => text().nullable()();
  BoolColumn get misEnAvant => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Clients (points de vente) téléchargés du CRM (`GET /clients`), dans le périmètre de l'utilisateur.
@DataClassName('ClientLocal')
class ClientsLocaux extends Table {
  /// Identifiant serveur (UUID).
  TextColumn get id => text()();
  TextColumn get codeAs400 => text()();
  TextColumn get enseigne => text()();
  TextColumn get raisonSociale => text()();
  TextColumn get adresse1 => text().nullable()();
  TextColumn get codePostal => text().nullable()();
  TextColumn get ville => text().nullable()();
  TextColumn get telephone => text().nullable()();
  TextColumn get contact => text().nullable()();
  BoolColumn get actif => boolean().withDefault(const Constant(true))();

  /// Classe CRM de A à G, nulle si non classé.
  TextColumn get niveauClass => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Enregistrements du serveur gardés tels quels (JSON) pour les jeux de données secondaires : commandes, visites,
/// prospects, planning, actualités, équipe. Un « domaine » regroupe les lignes d'un même jeu.
@DataClassName('EnregistrementLocal')
class EnregistrementsLocaux extends Table {
  TextColumn get domaine => text()();
  TextColumn get id => text()();

  /// Ligne telle que renvoyée par l'API.
  TextColumn get json => text()();

  @override
  Set<Column> get primaryKey => {domaine, id};
}

/// Photos de profil des utilisateurs (`GET /users/:id/photo`). Une photo vide veut dire « pas de photo côté CRM ».
@DataClassName('PhotoLocale')
class PhotosLocales extends Table {
  TextColumn get id => text()();
  BlobColumn get octets => blob()();
  DateTimeColumn get majLe => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Photos prises pendant une visite (arrivée, rayon, fin de visite), gardées dans la base chiffrée de l'appareil.
@DataClassName('PhotoVisiteLocale')
class PhotosVisite extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Identifiant de la visite (celui de l'app).
  TextColumn get visiteId => text()();

  /// Clé de l'étape (`EtapeDph.cle`).
  TextColumn get etape => text()();
  BlobColumn get octets => blob()();
  DateTimeColumn get priseLe => dateTime().withDefault(currentDateAndTime)();
}

/// Base locale de l'application (SQLite chiffré, voir `ouverture_base.dart`).
@DriftDatabase(
  tables: [
    MetaBase,
    ArticlesLocaux,
    ClientsLocaux,
    EnregistrementsLocaux,
    PhotosLocales,
    PhotosVisite,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Clé de métadonnée : date de création de la base (ISO 8601, UTC).
  static const cleCreeeLe = 'creee_le';

  /// Clé de métadonnée : date du dernier téléchargement complet du catalogue (ISO 8601, UTC).
  static const cleCatalogueMajLe = 'catalogue_maj_le';

  /// Clé de métadonnée : date du dernier téléchargement complet des clients (ISO 8601, UTC).
  static const cleClientsMajLe = 'clients_maj_le';

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(metaBase).insert(
        MetaBaseCompanion.insert(
          cle: cleCreeeLe,
          valeur: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    },
    onUpgrade: (m, de, vers) async {
      if (de < 2) await m.createTable(articlesLocaux);
      if (de < 3) await m.createTable(clientsLocaux);
      if (de < 4) await m.createTable(enregistrementsLocaux);
      if (de < 5) await m.createTable(photosLocales);
      if (de < 6) await m.createTable(photosVisite);
    },
  );

  /// Photos d'une visite, de la plus ancienne à la plus récente.
  Future<List<PhotoVisiteLocale>> photosDeVisite(String visiteId) =>
      (select(photosVisite)
            ..where((t) => t.visiteId.equals(visiteId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<void> ajouterPhotoVisite(
    String visiteId,
    String etape,
    List<int> octets,
  ) => into(photosVisite).insert(
    PhotosVisiteCompanion.insert(
      visiteId: visiteId,
      etape: etape,
      octets: Uint8List.fromList(octets),
    ),
  );

  Future<void> supprimerPhotoVisite(int id) =>
      (delete(photosVisite)..where((t) => t.id.equals(id))).go();

  /// Clé de métadonnée de la date du dernier téléchargement d'un domaine.
  static String cleMajDomaine(String domaine) => 'maj_$domaine';

  /// Remplace en une transaction toutes les lignes d'un domaine (tout ou rien).
  Future<void> remplacerEnregistrements(
    String domaine,
    List<({String id, String json})> lignes,
  ) => transaction(() async {
    await (delete(
      enregistrementsLocaux,
    )..where((t) => t.domaine.equals(domaine))).go();
    await batch(
      (b) => b.insertAll(enregistrementsLocaux, [
        for (final l in lignes)
          EnregistrementsLocauxCompanion.insert(
            domaine: domaine,
            id: l.id,
            json: l.json,
          ),
      ]),
    );
    await ecrireMeta(
      cleMajDomaine(domaine),
      DateTime.now().toUtc().toIso8601String(),
    );
  });

  /// Photos enregistrées : identifiant d'utilisateur, octets (vides : pas de photo) et date du téléchargement.
  Future<List<PhotoLocale>> toutesLesPhotos() => select(photosLocales).get();

  Future<void> ecrirePhoto(String id, List<int> octets) =>
      into(photosLocales).insertOnConflictUpdate(
        PhotosLocalesCompanion.insert(
          id: id,
          octets: Uint8List.fromList(octets),
          majLe: Value(DateTime.now()),
        ),
      );

  /// Une ligne JSON d'un domaine, ou null.
  Future<String?> enregistrement(String domaine, String id) async {
    final ligne =
        await (select(enregistrementsLocaux)
              ..where((t) => t.domaine.equals(domaine) & t.id.equals(id)))
            .getSingleOrNull();
    return ligne?.json;
  }

  /// Écrit (ou remplace) une ligne JSON d'un domaine.
  Future<void> ecrireEnregistrement(String domaine, String id, String json) =>
      into(enregistrementsLocaux).insertOnConflictUpdate(
        EnregistrementsLocauxCompanion.insert(
          domaine: domaine,
          id: id,
          json: json,
        ),
      );

  /// Lignes JSON d'un domaine.
  Future<List<String>> enregistrements(String domaine) async {
    final lignes = await (select(
      enregistrementsLocaux,
    )..where((t) => t.domaine.equals(domaine))).get();
    return [for (final l in lignes) l.json];
  }

  /// Valeur d'une métadonnée, ou null si elle n'existe pas.
  Future<String?> meta(String cle) async {
    final ligne = await (select(
      metaBase,
    )..where((t) => t.cle.equals(cle))).getSingleOrNull();
    return ligne?.valeur;
  }

  /// Écrit (ou remplace) une métadonnée.
  Future<void> ecrireMeta(String cle, String valeur) => into(
    metaBase,
  ).insertOnConflictUpdate(MetaBaseCompanion.insert(cle: cle, valeur: valeur));

  /// Remplace tout le catalogue local en une seule transaction : si l'écriture échoue, l'ancien catalogue reste.
  /// Les articles disparus du serveur disparaissent aussi de la base.
  Future<void> remplacerArticles(List<ArticlesLocauxCompanion> articles) =>
      transaction(() async {
        await delete(articlesLocaux).go();
        await batch((b) => b.insertAll(articlesLocaux, articles));
        await ecrireMeta(
          cleCatalogueMajLe,
          DateTime.now().toUtc().toIso8601String(),
        );
      });

  /// Remplace tous les clients locaux en une seule transaction (tout ou rien).
  Future<void> remplacerClients(List<ClientsLocauxCompanion> clients) =>
      transaction(() async {
        await delete(clientsLocaux).go();
        await batch((b) => b.insertAll(clientsLocaux, clients));
        await ecrireMeta(
          cleClientsMajLe,
          DateTime.now().toUtc().toIso8601String(),
        );
      });

  Future<List<ClientLocal>> tousLesClients() => (select(
    clientsLocaux,
  )..orderBy([(t) => OrderingTerm.asc(t.enseigne)])).get();

  Future<List<ArticleLocal>> tousLesArticles() => (select(
    articlesLocaux,
  )..orderBy([(t) => OrderingTerm.asc(t.libelle)])).get();
}
