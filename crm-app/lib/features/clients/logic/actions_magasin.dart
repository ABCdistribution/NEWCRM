/// Écritures sur un magasin envoyées au CRM (connecté) : droits par rôle (les `@Roles` de `clients.controller.ts`),
/// corps et routes des contacts et de la périodicité, validation du formulaire de contact, messages d'erreur.
library;

import '../../../core/api/erreur_api.dart';
import '../../../core/data/fiche_client.dart';

/// Rôles de l'API qui écrivent sur un magasin (notes, contacts, périodicité, journal des appels et e-mails) et que
/// l'application connaît : tous ceux qui ont un accès mobile. Hors liste (marketing…), rien n'est proposé.
const Set<String> rolesEcritureMagasin = {
  'ADMIN',
  'DIRECTION',
  'DIRECTEUR_REGIONAL',
  'CHEF_SECTEUR',
  'COMMERCIAL',
  'ADV',
};

bool peutEcrireMagasin(String? roleApi) =>
    rolesEcritureMagasin.contains(roleApi);

/// Longueurs acceptées par l'API (`CreateContactDto`).
const int maxPrenom = 60;
const int maxNomContact = 60;
const int maxPosteContact = 80;
const int maxTelContact = 20;

/// Champs du formulaire de contact, tels que saisis.
class BrouillonContact {
  const BrouillonContact({
    this.prenom = '',
    this.nom = '',
    this.poste = '',
    this.fixe = '',
    this.portable = '',
    this.mail = '',
  });

  /// Formulaire prérempli avec un contact du CRM.
  factory BrouillonContact.depuis(ContactClient c) => BrouillonContact(
    prenom: c.prenom ?? '',
    nom: c.nomFamille ?? c.nom,
    poste: c.posteSaisi ?? '',
    fixe: c.fixe ?? '',
    portable: c.portable ?? '',
    mail: c.mail ?? '',
  );

  final String prenom;
  final String nom;
  final String poste;
  final String fixe;
  final String portable;
  final String mail;

  BrouillonContact copyWith({
    String? prenom,
    String? nom,
    String? poste,
    String? fixe,
    String? portable,
    String? mail,
  }) => BrouillonContact(
    prenom: prenom ?? this.prenom,
    nom: nom ?? this.nom,
    poste: poste ?? this.poste,
    fixe: fixe ?? this.fixe,
    portable: portable ?? this.portable,
    mail: mail ?? this.mail,
  );
}

final RegExp _formeMail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Erreurs par champ (`nom`, `prenom`, `poste`, `fixe`, `portable`, `mail`) ; vide si le formulaire est valide.
Map<String, String> validerContact(BrouillonContact b) {
  final e = <String, String>{};
  void borne(String cle, String valeur, int max) {
    if (valeur.trim().length > max) e[cle] = '$max caractères au plus';
  }

  if (b.nom.trim().isEmpty) e['nom'] = 'Nom requis';
  borne('nom', b.nom, maxNomContact);
  borne('prenom', b.prenom, maxPrenom);
  borne('poste', b.poste, maxPosteContact);
  borne('fixe', b.fixe, maxTelContact);
  borne('portable', b.portable, maxTelContact);
  final mail = b.mail.trim();
  if (mail.isNotEmpty && !_formeMail.hasMatch(mail)) {
    e['mail'] = 'Mail invalide';
  }
  return e;
}

/// Corps de `POST /clients/:id/contacts` (champs vides omis) ou, avec `modification`, de `PATCH …/contacts/:contactId`
/// (champs vides envoyés à `null` pour effacer la valeur).
Map<String, Object?> corpsContact(
  BrouillonContact b, {
  bool modification = false,
}) {
  Object? texte(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  final champs = <String, Object?>{
    'prenom': texte(b.prenom),
    'nom': b.nom.trim(),
    'poste': texte(b.poste),
    'fixe': texte(b.fixe),
    'portable': texte(b.portable),
    'mail': texte(b.mail),
  };
  return modification
      ? champs
      : {
          for (final c in champs.entries)
            if (c.value != null) c.key: c.value,
        };
}

/// `/clients/:id/contacts` ou `/clients/:id/contacts/:contactId` (identifiants encodés).
String cheminContact(String clientId, [String? contactId]) =>
    '/clients/${Uri.encodeComponent(clientId)}/contacts'
    '${contactId == null ? '' : '/${Uri.encodeComponent(contactId)}'}';

/// `/clients/:id/periodicite`.
String cheminPeriodicite(String clientId) =>
    '/clients/${Uri.encodeComponent(clientId)}/periodicite';

/// Corps de `PATCH /clients/:id/periodicite` : l'identifiant de la périodicité, ou `null` pour n'en avoir aucune.
Map<String, Object?> corpsPeriodicite(String? periodiciteId) => {
  'periodiciteId': periodiciteId,
};

/// Une périodicité de la nomenclature (`GET /periodicites`).
class PeriodiciteVisite {
  const PeriodiciteVisite({required this.id, required this.libelle});

  final String id;
  final String libelle;
}

/// Périodicités à partir de la réponse de l'API (liste d'objets `{id, code, libelle}`), les lignes illisibles écartées.
List<PeriodiciteVisite> periodicitesDepuisJson(Object? json) => [
  if (json is List)
    for (final p in json)
      if (p is Map && p['id'] is String && p['libelle'] is String)
        PeriodiciteVisite(
          id: p['id'] as String,
          libelle: (p['libelle'] as String).trim(),
        ),
];

/// Message affiché quand le CRM refuse l'écriture : celui de l'API quand elle en donne un, sinon un texte selon le statut.
String messageErreurMagasin(ErreurApi e) {
  if (e.detail != null || e.type == TypeErreurApi.reseau) return e.message;
  return switch (e.statut) {
    400 => 'Ces informations sont refusées par le CRM. Vérifiez la saisie.',
    403 => "Vous n'avez pas le droit de modifier ce magasin.",
    404 => 'Magasin ou contact introuvable dans votre périmètre.',
    _ => e.message,
  };
}
