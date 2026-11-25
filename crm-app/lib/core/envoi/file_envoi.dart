/// File d'envoi vers le CRM : ce qui est validé dans l'application (visites, commandes) est rangé dans la base chiffrée
/// puis envoyé, une entrée à la fois, du plus ancien au plus récent, jusqu'à ce que l'API l'ait acceptée.
///
/// Logique pure (base, API en paramètres) ; [EnvoiNotifier] la déclenche (démarrage, retour du réseau, relance).
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../api/api_client.dart';
import '../api/erreur_api.dart';
import '../db/app_database.dart';
import '../db/envois_base.dart';

/// Ce que l'on fait d'une erreur d'appel.
enum NatureErreur {
  /// Réseau coupé, serveur en panne, trop de requêtes : on retente plus tard.
  reessayer,

  /// Jeton refusé : il faut se reconnecter ; l'entrée reste à envoyer.
  sessionExpiree,

  /// L'API refuse la demande (validation, droits, élément introuvable…) : l'entrée passe en erreur, sans boucle.
  definitive,
}

/// Classe une erreur d'API : seuls le réseau, les 5xx, 408 et 429 valent la peine d'être retentés.
NatureErreur classerErreur(ErreurApi e) {
  if (e.type == TypeErreurApi.sessionExpiree) {
    return NatureErreur.sessionExpiree;
  }
  if (e.type == TypeErreurApi.reseau || e.type == TypeErreurApi.serveur) {
    return NatureErreur.reessayer;
  }
  final statut = e.statut;
  // Réponse illisible : l'envoi est idempotent, on peut le refaire.
  if (statut == null || statut == 408 || statut == 429) {
    return NatureErreur.reessayer;
  }
  return NatureErreur.definitive;
}

final RegExp _dejaRecu = RegExp(
  r'd[ée]j[àa] (re[çc]u|synchronis|valid)',
  caseSensitive: false,
);

/// Vrai pour un 409 qui veut dire « l'API l'a déjà » : l'envoi est réussi. (Les créations de l'API sont idempotentes par
/// `idApk` et répondent 200 ; ce cas ne sert que si une version de l'API répondait 409.)
bool conflitDejaRecu(ErreurApi e) =>
    e.statut == 409 && _dejaRecu.hasMatch(e.detail ?? '');

/// Issue d'un passage de la file.
enum IssueVidage {
  /// Plus rien à envoyer (les entrées en erreur restent en erreur).
  termine,

  /// Le réseau ou le serveur a manqué : il reste des entrées à retenter.
  reseau,

  /// La session a expiré : il faut se reconnecter.
  sessionExpiree,
}

/// Résultat d'un passage : l'issue et les entrées envoyées pendant ce passage.
class ResultatVidage {
  const ResultatVidage(this.issue, this.envoyes);

  final IssueVidage issue;
  final List<EnvoiLocal> envoyes;
}

/// Type MIME d'une image d'après ses premiers octets (JPEG par défaut : c'est ce que produit l'appareil photo).
String typeMimeImage(List<int> octets) {
  bool debut(List<int> m) =>
      octets.length >= m.length &&
      [for (var i = 0; i < m.length; i++) octets[i] == m[i]].every((b) => b);
  if (debut(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (debut(const [0x47, 0x49, 0x46])) return 'image/gif';
  if (debut(const [0x52, 0x49, 0x46, 0x46]) &&
      octets.length > 11 &&
      String.fromCharCodes(octets.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return 'image/jpeg';
}

String _extension(String mime) => switch (mime) {
  'image/png' => 'png',
  'image/gif' => 'gif',
  'image/webp' => 'webp',
  _ => 'jpg',
};

/// Un refus définitif détecté avant tout appel (donnée locale inutilisable).
class _Refus implements Exception {
  const _Refus(this.message);
  final String message;
}

class FileEnvoi {
  FileEnvoi({
    required this.base,
    required this.ecriture,
    required this.fichiers,
    DateTime Function()? maintenant,
  }) : _maintenant = maintenant ?? DateTime.now;

  final AppDatabase base;
  final ApiEcriture ecriture;
  final ApiFichiers fichiers;
  final DateTime Function() _maintenant;

  /// Entrées envoyées gardées 7 jours (trace), puis purgées.
  static const conservation = Duration(days: 7);

  /// Range une visite terminée dans la file. `payload` : le corps de `POST /visites` ; ses photos (celles de
  /// `visiteLocaleId`) y sont rattachées.
  Future<EnvoiLocal> enfilerVisite({
    required String utilisateurId,
    required String idApk,
    required Map<String, Object?> corps,
    required String visiteLocaleId,
  }) => base.enfilerEnvoi(
    utilisateurId: utilisateurId,
    type: TypeEnvoi.visite,
    cle: idApk,
    payload: jsonEncode(corps),
    refLocale: visiteLocaleId,
    photosDe: visiteLocaleId,
  );

  /// Range une commande validée dans la file. `corps` : le corps de `POST /commandes/apk` (statut `VALIDEE`).
  Future<EnvoiLocal> enfilerCommande({
    required String utilisateurId,
    required Map<String, Object?> corps,
  }) => base.enfilerEnvoi(
    utilisateurId: utilisateurId,
    type: TypeEnvoi.commande,
    cle: corps['idCommandeApk']! as String,
    payload: jsonEncode(corps),
  );

  /// Range une écriture rejouable (note, journal d'appel ou d'e-mail) dans la file. `idApk` est la clé d'idempotence (celle
  /// du corps) ; `cible` (`client:<id>` ou `prospect:<id>`) dit quelle fiche relire une fois l'écriture partie ;
  /// `libelle` nomme l'écriture dans les messages d'erreur.
  Future<EnvoiLocal> enfilerEcriture({
    required String utilisateurId,
    required String idApk,
    required String methode,
    required String chemin,
    required Map<String, Object?> corps,
    String? cible,
    String libelle = 'Envoi',
  }) => base.enfilerEnvoi(
    utilisateurId: utilisateurId,
    type: TypeEnvoi.ecriture,
    cle: idApk,
    payload: jsonEncode({
      'methode': methode,
      'chemin': chemin,
      'corps': corps,
      'libelle': libelle,
    }),
    refLocale: cible,
  );

  /// Envoie les entrées de l'utilisateur, une à la fois, de la plus ancienne à la plus récente. S'arrête au premier
  /// manque de réseau ou de session ; une entrée refusée par l'API passe en erreur et la file continue.
  Future<ResultatVidage> vider(String utilisateurId) async {
    await base.reprendreEnvoisInterrompus(utilisateurId);
    await base.purgerEnvoisEnvoyes(_maintenant().subtract(conservation));
    final envoyes = <EnvoiLocal>[];
    while (true) {
      final entree = await base.prochainEnvoi(utilisateurId);
      if (entree == null) return ResultatVidage(IssueVidage.termine, envoyes);
      final issue = await _traiter(entree);
      switch (issue) {
        case null:
          final fait = await base.envoi(entree.id);
          if (fait != null && fait.etat == EtatEnvoi.envoye) envoyes.add(fait);
        case IssueVidage.termine:
          break; // refus définitif : entrée suivante
        case IssueVidage.reseau || IssueVidage.sessionExpiree:
          return ResultatVidage(issue, envoyes);
      }
    }
  }

  /// Envoie une entrée. Renvoie null si elle est partie (ou passée en erreur après un refus de photo), [IssueVidage.termine]
  /// si elle est refusée, [IssueVidage.reseau] ou [IssueVidage.sessionExpiree] si elle est à retenter.
  Future<IssueVidage?> _traiter(EnvoiLocal e) async {
    await base.majEnvoi(e.id, etat: EtatEnvoi.enCours, essais: e.essais + 1);
    try {
      switch (e.type) {
        case TypeEnvoi.visite:
          await _envoyerVisite(e);
        case TypeEnvoi.commande:
          await _envoyerCommande(e);
        case TypeEnvoi.ecriture:
          await _envoyerEcriture(e);
        default:
          throw _Refus("Type d'envoi inconnu : ${e.type}.");
      }
      return null;
    } on ErreurApi catch (err) {
      if (conflitDejaRecu(err)) {
        await _termine(e.id);
        return null;
      }
      switch (classerErreur(err)) {
        case NatureErreur.reessayer:
          await _remettre(e.id, err.message);
          return IssueVidage.reseau;
        case NatureErreur.sessionExpiree:
          await _remettre(e.id, err.message);
          return IssueVidage.sessionExpiree;
        case NatureErreur.definitive:
          await _enErreur(e.id, err.message);
          return IssueVidage.termine;
      }
    } on _Refus catch (r) {
      await _enErreur(e.id, r.message);
      return IssueVidage.termine;
    } catch (_) {
      await _enErreur(e.id, "L'envoi a échoué (donnée illisible).");
      return IssueVidage.termine;
    }
  }

  Future<void> _remettre(int id, String message) =>
      base.majEnvoi(id, etat: EtatEnvoi.aEnvoyer, erreur: Value(message));

  Future<void> _enErreur(int id, String message) =>
      base.majEnvoi(id, etat: EtatEnvoi.erreur, erreur: Value(message));

  Future<void> _termine(int id) => base.majEnvoi(
    id,
    etat: EtatEnvoi.envoye,
    erreur: const Value(null),
    envoyeLe: _maintenant(),
  );

  Map<String, Object?> _corps(EnvoiLocal e) {
    final j = jsonDecode(e.payload);
    if (j is! Map<String, dynamic>) throw const _Refus('Envoi illisible.');
    return j;
  }

  /// `POST /visites` (idempotent par `idApk`), puis chaque photo (`POST /visites/:id/photos`, idempotent par
  /// `idApk`). Une visite déjà créée n'est pas recréée : son identifiant CRM est gardé avec l'entrée.
  Future<void> _envoyerVisite(EnvoiLocal e) async {
    var serveurId = e.serveurId;
    if (serveurId == null) {
      final r = await ecriture.envoyer('POST', '/visites', corps: _corps(e));
      final id = r is Map ? r['id'] : null;
      if (id is! String || id.isEmpty) {
        throw const ErreurApi(TypeErreurApi.inattendue);
      }
      serveurId = id;
      await base.majEnvoi(e.id, serveurId: serveurId);
    }
    final chemin = '/visites/${Uri.encodeComponent(serveurId)}/photos';
    var refus = 0;
    for (final f in await base.fichiersDeEnvoi(e.id)) {
      if (f.etat == EtatFichierEnvoi.envoye) continue;
      final octets = f.photoId == null
          ? null
          : await base.octetsPhotoVisite(f.photoId!);
      if (octets == null || octets.isEmpty) {
        await base.fichierRefuse(f, 'Photo introuvable sur le téléphone.');
        refus++;
        continue;
      }
      final mime = typeMimeImage(octets);
      try {
        await fichiers.televerser(
          chemin,
          champ: 'photo',
          nomFichier: '${f.idApk}.${_extension(mime)}',
          typeMime: mime,
          octets: octets,
          champs: {'idApk': f.idApk, 'etape': f.etape},
        );
        await base.fichierEnvoye(f);
      } on ErreurApi catch (err) {
        if (conflitDejaRecu(err)) {
          await base.fichierEnvoye(f);
        } else if (classerErreur(err) == NatureErreur.definitive) {
          await base.fichierRefuse(f, err.message);
          refus++;
        } else {
          rethrow;
        }
      }
    }
    if (refus > 0) {
      throw _Refus(
        refus == 1
            ? 'Visite envoyée, une photo a été refusée.'
            : 'Visite envoyée, $refus photos ont été refusées.',
      );
    }
    await _termine(e.id);
  }

  /// `POST /commandes/apk` en statut `VALIDEE` (idempotent par `idCommandeApk`). Si une commande portant cet
  /// identifiant existe déjà en attente, l'API la renvoie telle quelle : on la valide (`POST /:id/valider`, idempotent).
  Future<void> _envoyerCommande(EnvoiLocal e) async {
    var serveurId = e.serveurId;
    var validee = false;
    if (serveurId == null) {
      final r = await ecriture.envoyer(
        'POST',
        '/commandes/apk',
        corps: _corps(e),
      );
      final id = r is Map ? r['id'] : null;
      if (id is! String || id.isEmpty) {
        throw const ErreurApi(TypeErreurApi.inattendue);
      }
      serveurId = id;
      validee = r is Map && r['statut'] == 'VALIDEE';
      await base.majEnvoi(e.id, serveurId: serveurId);
    }
    if (!validee) {
      await ecriture.envoyer(
        'POST',
        '/commandes/apk/${Uri.encodeComponent(serveurId)}/valider',
      );
    }
    await _termine(e.id);
  }

  /// Rejoue l'écriture rangée : `POST` d'une note, d'un appel ou d'un e-mail (idempotents par `idApk`). Seules les
  /// routes de clients et de prospects sont admises.
  Future<void> _envoyerEcriture(EnvoiLocal e) async {
    final j = _corps(e);
    final methode = j['methode'];
    final chemin = j['chemin'];
    final corps = j['corps'];
    if (methode != 'POST' ||
        chemin is! String ||
        !RegExp(
          r'^/(clients|prospects)/[^/]+/(notes|appels|emails)$',
        ).hasMatch(chemin)) {
      throw const _Refus('Envoi illisible.');
    }
    await ecriture.envoyer('POST', chemin, corps: corps);
    await _termine(e.id);
  }
}

/// Nom d'une entrée de la file dans les messages d'erreur : « Visite », « Commande » ou le libellé de l'écriture.
String libelleEnvoi(String type, String payload) {
  if (type == TypeEnvoi.visite) return 'Visite';
  if (type == TypeEnvoi.commande) return 'Commande';
  try {
    final j = jsonDecode(payload);
    final l = j is Map ? j['libelle'] : null;
    if (l is String && l.isNotEmpty) return l;
  } catch (_) {}
  return 'Envoi';
}
