import 'package:drift/drift.dart';

import 'app_database.dart';

/// États d'une entrée de la file d'envoi.
abstract final class EtatEnvoi {
  static const aEnvoyer = 'a_envoyer';
  static const enCours = 'en_cours';
  static const envoye = 'envoye';
  static const erreur = 'erreur';
}

/// États d'une photo de la file d'envoi.
abstract final class EtatFichierEnvoi {
  static const aEnvoyer = 'a_envoyer';
  static const envoye = 'envoye';
  static const refuse = 'refuse';
}

/// Types d'entrée de la file d'envoi.
abstract final class TypeEnvoi {
  static const visite = 'visite';
  static const commande = 'commande';

  /// Écriture rejouable sur une route du CRM (note, journal d'appel ou d'e-mail) : `payload` porte la méthode, le
  /// chemin, le corps et un libellé ; la clé est l'`idApk` du corps.
  static const ecriture = 'ecriture';
}

/// Préfixe de l'identifiant de visite sous lequel les photos d'une visite en file sont rangées : elles ne se
/// confondent plus avec celles d'une nouvelle visite qui reprendrait le même identifiant local.
String refPhotosEnvoi(String cle) => 'envoi:$cle';

/// Accès à la file d'envoi (`envois_en_attente`, `envois_fichiers`).
extension EnvoisBase on AppDatabase {
  /// Ajoute une entrée à la file. Une clé déjà présente n'est pas dupliquée : l'entrée existante est renvoyée.
  ///
  /// Pour une visite, `photosDe` est l'identifiant local de la visite : ses photos sont rattachées à l'entrée (et
  /// rangées sous [refPhotosEnvoi]) dans la même transaction, sans quoi une coupure laisserait une visite sans photos.
  Future<EnvoiLocal> enfilerEnvoi({
    required String utilisateurId,
    required String type,
    required String cle,
    required String payload,
    String? refLocale,
    String? photosDe,
  }) => transaction(() async {
    final existant = await (select(
      envoisEnAttente,
    )..where((t) => t.cle.equals(cle))).getSingleOrNull();
    if (existant != null) return existant;
    final id = await into(envoisEnAttente).insert(
      EnvoisEnAttenteCompanion.insert(
        utilisateurId: utilisateurId,
        type: type,
        cle: cle,
        payload: payload,
        refLocale: Value(refLocale),
      ),
    );
    if (photosDe != null) {
      for (final p in await photosDeVisite(photosDe)) {
        await into(envoisFichiers).insert(
          EnvoisFichiersCompanion.insert(
            envoiId: id,
            photoId: Value(p.id),
            etape: p.etape,
            idApk: '$cle-${p.id}',
          ),
        );
      }
      await (update(photosVisite)..where((t) => t.visiteId.equals(photosDe)))
          .write(PhotosVisiteCompanion(visiteId: Value(refPhotosEnvoi(cle))));
    }
    return (select(envoisEnAttente)..where((t) => t.id.equals(id))).getSingle();
  });

  /// Efface les photos de visite qui ne sont rattachées à aucune entrée de la file (visites en cours abandonnées).
  /// À appeler au démarrage seulement : une visite en cours a ses photos ici.
  Future<void> purgerPhotosOrphelines() => (delete(
    photosVisite,
  )..where((t) => t.visiteId.like('envoi:%').not())).go();

  /// Entrées d'un utilisateur, de la plus ancienne à la plus récente.
  Future<List<EnvoiLocal>> envoisDe(String utilisateurId) =>
      (select(envoisEnAttente)
            ..where((t) => t.utilisateurId.equals(utilisateurId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  /// Prochaine entrée à envoyer (la plus ancienne dont l'état est `a_envoyer`), ou null.
  Future<EnvoiLocal?> prochainEnvoi(String utilisateurId) =>
      (select(envoisEnAttente)
            ..where(
              (t) =>
                  t.utilisateurId.equals(utilisateurId) &
                  t.etat.equals(EtatEnvoi.aEnvoyer),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(1))
          .getSingleOrNull();

  Future<EnvoiLocal?> envoi(int id) => (select(
    envoisEnAttente,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Met à jour une entrée ; la date de mise à jour est posée ici.
  Future<void> majEnvoi(
    int id, {
    String? etat,
    int? essais,
    Value<String?> erreur = const Value.absent(),
    String? serveurId,
    DateTime? envoyeLe,
  }) => (update(envoisEnAttente)..where((t) => t.id.equals(id))).write(
    EnvoisEnAttenteCompanion(
      etat: etat == null ? const Value.absent() : Value(etat),
      essais: essais == null ? const Value.absent() : Value(essais),
      derniereErreur: erreur,
      serveurId: serveurId == null ? const Value.absent() : Value(serveurId),
      envoyeLe: envoyeLe == null ? const Value.absent() : Value(envoyeLe),
      misAJourLe: Value(DateTime.now()),
    ),
  );

  /// Entrées restées « en cours » parce que l'application a été arrêtée pendant l'envoi : elles repartent.
  Future<void> reprendreEnvoisInterrompus(String utilisateurId) =>
      (update(envoisEnAttente)..where(
            (t) =>
                t.utilisateurId.equals(utilisateurId) &
                t.etat.equals(EtatEnvoi.enCours),
          ))
          .write(
            const EnvoisEnAttenteCompanion(etat: Value(EtatEnvoi.aEnvoyer)),
          );

  /// Remet à envoyer les entrées en erreur (et leurs photos refusées) : relance manuelle. Renvoie leur nombre.
  Future<int> relancerEnvoisEnErreur(
    String utilisateurId,
  ) => transaction(() async {
    final lignes =
        await (select(envoisEnAttente)..where(
              (t) =>
                  t.utilisateurId.equals(utilisateurId) &
                  t.etat.equals(EtatEnvoi.erreur),
            ))
            .get();
    for (final e in lignes) {
      await (update(envoisFichiers)..where(
            (t) =>
                t.envoiId.equals(e.id) & t.etat.equals(EtatFichierEnvoi.refuse),
          ))
          .write(
            const EnvoisFichiersCompanion(
              etat: Value(EtatFichierEnvoi.aEnvoyer),
              derniereErreur: Value(null),
            ),
          );
      await (update(envoisEnAttente)..where((t) => t.id.equals(e.id))).write(
        EnvoisEnAttenteCompanion(
          etat: const Value(EtatEnvoi.aEnvoyer),
          essais: const Value(0),
          derniereErreur: const Value(null),
          misAJourLe: Value(DateTime.now()),
        ),
      );
    }
    return lignes.length;
  });

  /// Nombre d'entrées à envoyer (y compris en cours) et en erreur.
  Future<({int aEnvoyer, int enErreur})> comptesEnvoi(
    String utilisateurId,
  ) async {
    final lignes = await envoisDe(utilisateurId);
    return (
      aEnvoyer: lignes
          .where(
            (e) => e.etat == EtatEnvoi.aEnvoyer || e.etat == EtatEnvoi.enCours,
          )
          .length,
      enErreur: lignes.where((e) => e.etat == EtatEnvoi.erreur).length,
    );
  }

  Future<List<EnvoiFichierLocal>> fichiersDeEnvoi(int envoiId) =>
      (select(envoisFichiers)
            ..where((t) => t.envoiId.equals(envoiId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  /// Octets d'une photo gardée sur l'appareil, ou null si elle n'existe plus.
  Future<List<int>?> octetsPhotoVisite(int photoId) async {
    final ligne = await (select(
      photosVisite,
    )..where((t) => t.id.equals(photoId))).getSingleOrNull();
    return ligne?.octets;
  }

  /// La photo est acceptée par le CRM : ses octets sont effacés de l'appareil.
  Future<void> fichierEnvoye(EnvoiFichierLocal f) => transaction(() async {
    await (update(envoisFichiers)..where((t) => t.id.equals(f.id))).write(
      const EnvoisFichiersCompanion(
        etat: Value(EtatFichierEnvoi.envoye),
        photoId: Value(null),
        derniereErreur: Value(null),
      ),
    );
    final photoId = f.photoId;
    if (photoId != null) {
      await supprimerPhotoVisite(photoId);
    }
  });

  Future<void> fichierRefuse(EnvoiFichierLocal f, String message) =>
      (update(envoisFichiers)..where((t) => t.id.equals(f.id))).write(
        EnvoisFichiersCompanion(
          etat: const Value(EtatFichierEnvoi.refuse),
          derniereErreur: Value(message),
        ),
      );

  /// Supprime les entrées envoyées avant `avant` (et leurs lignes de photos).
  Future<void> purgerEnvoisEnvoyes(DateTime avant) => transaction(() async {
    final anciens =
        await (select(envoisEnAttente)..where(
              (t) =>
                  t.etat.equals(EtatEnvoi.envoye) &
                  t.envoyeLe.isSmallerThanValue(avant),
            ))
            .get();
    for (final e in anciens) {
      await (delete(envoisFichiers)..where((t) => t.envoiId.equals(e.id))).go();
      await (delete(envoisEnAttente)..where((t) => t.id.equals(e.id))).go();
    }
  });
}
