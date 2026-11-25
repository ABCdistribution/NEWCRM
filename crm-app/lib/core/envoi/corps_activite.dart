/// Écritures d'activité sur une fiche du CRM (note, appel, e-mail) : route, corps et libellé (fonctions pures, conformes
/// aux DTO `CreateNoteDto`, `CreateAppelClientDto`, `CreateEmailClientDto` des clients et `CreateNoteProspectDto`,
/// `CreateAppelDto`, `CreateEmailDto` des prospects). Chacune est idempotente par `idApk`.
library;

import '../logic/id_apk.dart';

/// Fiche visée : un client (magasin) ou un prospect.
enum CibleActivite {
  client('clients', 'client', 'magasin'),
  prospect('prospects', 'prospect', 'prospect');

  const CibleActivite(this.racine, this.prefixe, this.nom);

  /// Premier segment de la route (`/clients/:id/…`).
  final String racine;

  /// Préfixe de la référence gardée avec l'entrée de la file (`client:<id>`).
  final String prefixe;

  /// Nom affiché dans les messages d'erreur.
  final String nom;
}

/// Une écriture prête à être rangée dans la file d'envoi.
class RequeteActivite {
  const RequeteActivite({
    required this.idApk,
    required this.chemin,
    required this.corps,
    required this.cible,
    required this.libelle,
  });

  final String idApk;
  final String chemin;
  final Map<String, Object?> corps;

  /// `client:<id>` ou `prospect:<id>` : la fiche à relire une fois l'écriture partie.
  final String cible;
  final String libelle;
}

String _chemin(CibleActivite c, String id, String suite) =>
    '/${c.racine}/${Uri.encodeComponent(id)}/$suite';

/// Longueurs acceptées par l'API.
const int maxRemarque = 2000;
const int maxDestinataire = 200;

/// `POST /clients/:id/notes` ou `POST /prospects/:id/notes` : la remarque, nettoyée, au plus [maxRemarque] caractères.
RequeteActivite requeteNote(
  CibleActivite cible,
  String id,
  String remarque, {
  String? idApk,
}) {
  final cle = idApk ?? genererIdApkUuid();
  final texte = remarque.trim();
  return RequeteActivite(
    idApk: cle,
    chemin: _chemin(cible, id, 'notes'),
    corps: {
      'remarque': texte.length > maxRemarque
          ? texte.substring(0, maxRemarque)
          : texte,
      'idApk': cle,
    },
    cible: '${cible.prefixe}:$id',
    libelle: 'Note ${cible.nom}',
  );
}

/// Résultat d'un appel (`resultat` de l'API, identique pour un client et un prospect).
enum ResultatAppel {
  repondu('REPONDU', 'Répondu'),
  sansReponse('SANS_REPONSE', 'Sans réponse'),
  messagerie('MESSAGERIE', 'Messagerie'),
  rappelPrevu('RAPPEL_PREVU', 'Rappel prévu');

  const ResultatAppel(this.code, this.libelle);

  /// Valeur envoyée à l'API.
  final String code;
  final String libelle;

  /// Le résultat d'un code de l'API ; nul si le code est absent ou inconnu.
  static ResultatAppel? depuisCode(Object? code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

/// `POST …/appels` : un appel lancé depuis la fiche, à l'heure `quand`. Sans `resultat` (« Ignorer » dans la feuille
/// de résultat), le champ n'est pas envoyé et l'API prend sa valeur par défaut.
RequeteActivite requeteAppel(
  CibleActivite cible,
  String id, {
  required DateTime quand,
  ResultatAppel? resultat,
  String? idApk,
}) {
  final cle = idApk ?? genererIdApkUuid();
  return RequeteActivite(
    idApk: cle,
    chemin: _chemin(cible, id, 'appels'),
    corps: {
      'idApk': cle,
      'dateAppel': quand.toUtc().toIso8601String(),
      if (resultat != null) 'resultat': resultat.code,
    },
    cible: '${cible.prefixe}:$id',
    libelle: 'Appel ${cible.nom}',
  );
}

/// `POST …/emails` : un e-mail lancé depuis la fiche, vers `destinataire` (adresse), à l'heure `quand`.
RequeteActivite requeteEmail(
  CibleActivite cible,
  String id, {
  required DateTime quand,
  String? destinataire,
  String? idApk,
}) {
  final cle = idApk ?? genererIdApkUuid();
  final d = destinataire?.trim() ?? '';
  return RequeteActivite(
    idApk: cle,
    chemin: _chemin(cible, id, 'emails'),
    corps: {
      'idApk': cle,
      'dateEmail': quand.toUtc().toIso8601String(),
      if (d.isNotEmpty)
        'destinataire': d.length > maxDestinataire
            ? d.substring(0, maxDestinataire)
            : d,
    },
    cible: '${cible.prefixe}:$id',
    libelle: 'E-mail ${cible.nom}',
  );
}
