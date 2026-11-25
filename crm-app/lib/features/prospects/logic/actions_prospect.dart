/// Actions sur un prospect envoyées au CRM (connecté) : droits par rôle (les `@Roles` de `prospects.controller.ts`),
/// corps du changement d'étape, route et messages d'erreur.
library;

import '../../../core/api/erreur_api.dart';
import '../../../core/models/models.dart';

/// Rôles de l'API qui ajoutent une note (`POST /prospects/:id/notes`) et journalisent un appel ou un e-mail. Le
/// promoteur (COMMERCIAL) n'a aucune de ces routes.
const Set<String> rolesNoteProspect = {
  'CHEF_SECTEUR',
  'DIRECTEUR_REGIONAL',
  'DIRECTION',
  'ADMIN',
};

/// Rôles de l'API qui changent l'étape (`PATCH /prospects/:id`) et convertissent en client (`POST …/convert`).
const Set<String> rolesEtapeProspect = {
  'CHEF_SECTEUR',
  'DIRECTEUR_REGIONAL',
  'ADMIN',
};

bool peutNoterProspect(String? roleApi) => rolesNoteProspect.contains(roleApi);

bool peutFaireAvancerProspect(String? roleApi) =>
    rolesEtapeProspect.contains(roleApi);

/// Motif de la perte d'un prospect (`MotifPerteProspect` de l'API), exigé pour l'étape « Perdu ».
enum MotifPerte {
  prix('PRIX', 'Prix'),
  concurrence('CONCURRENCE', 'Concurrent en place'),
  pasDeBesoin('PAS_DE_BESOIN', 'Pas de besoin'),
  sansReponse('SANS_REPONSE', 'Sans réponse'),
  autre('AUTRE', 'Autre');

  const MotifPerte(this.code, this.libelle);

  final String code;
  final String libelle;
}

/// Route d'un prospect : `/prospects/:id` et son éventuelle suite (`convert`). L'identifiant est encodé.
String cheminProspect(String id, [String? suite]) =>
    '/prospects/${Uri.encodeComponent(id)}${suite == null ? '' : '/$suite'}';

/// Corps de `PATCH /prospects/:id` pour changer d'étape : la probabilité par défaut de l'étape s'applique côté API.
/// `motif` n'est envoyé que pour « Perdu » (l'API le refuse sinon).
Map<String, Object?> corpsChangementEtape(
  StatutProspect statut, {
  MotifPerte? motif,
}) => {
  'statut': statut.code,
  if (statut == StatutProspect.perdu && motif != null) 'motifPerte': motif.code,
};

/// Message affiché quand le CRM refuse l'action : celui de l'API quand elle en donne un, sinon un texte selon le statut.
String messageErreurActionProspect(ErreurApi e) {
  if (e.detail != null || e.type == TypeErreurApi.reseau) return e.message;
  return switch (e.statut) {
    400 => 'Cette modification est refusée par le CRM.',
    403 => "Vous n'avez pas le droit de faire cela sur ce prospect.",
    404 => 'Prospect introuvable dans votre périmètre.',
    _ => e.message,
  };
}
