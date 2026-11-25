/// Envoi d'une ligne de planning au CRM : date de passage, corps des deux routes
/// (`POST /tournees` pour son propre planning, `POST /plannings` pour planifier une visite chez un client pour un
/// promoteur) et message d'erreur.
library;

import '../../../core/api/erreur_api.dart';
import '../../../core/logic/dates.dart';
import '../../../core/models/models.dart';

/// Longueurs maximales acceptées par l'API.
const int maxLibelle = 200;
const int maxAdresse = 300;
const int maxNote = 500;
const int maxLieuSoiree = 200;

/// Date de passage envoyée à l'API : « yyyy-mm-dd », ou « yyyy-mm-ddTHH:mm » (sans fuseau) quand une heure est
/// saisie (`heure` = « HH:MM »). `semaine` : décalage par rapport à la semaine courante ; `jour` : 0 = lundi.
String datePassageApi({
  required DateTime lundi,
  required int semaine,
  required int jour,
  String heure = '',
  bool avecHeure = true,
}) {
  final d = DateTime(lundi.year, lundi.month, lundi.day + 7 * semaine + jour);
  final date =
      '${d.year.toString().padLeft(4, '0')}-${deuxChiffres(d.month)}-${deuxChiffres(d.day)}';
  final h = heure.trim();
  return avecHeure && RegExp(r'^\d{1,2}:\d{2}$').hasMatch(h)
      ? '${date}T${h.padLeft(5, '0')}'
      : date;
}

/// Corps de `POST /tournees` : exactement une cible (client, prospect, texte libre ou ADM) et les options de la ligne.
///
/// `adresse` : adresse saisie (facultative, ignorée pour une ligne ADM). Une ligne ADM n'envoie aucun type de visite.
Map<String, Object?> corpsTournee(
  EtapePlanning e, {
  required String idApk,
  required String datePassage,
  String adresse = '',
}) {
  final adm = e.cible == CiblePlanning.adm;
  final note = e.note.trim();
  final adr = adresse.trim();
  return {
    'idApk': idApk,
    'datePassage': datePassage,
    ...switch (e.cible) {
      CiblePlanning.adm => {'adm': true},
      CiblePlanning.client => {'clientId': e.ref},
      CiblePlanning.prospect => {'prospectId': e.ref},
      CiblePlanning.libre => {'libelle': e.titre.trim()},
    },
    if (!adm && adr.isNotEmpty) 'adresse': adr,
    if (note.isNotEmpty) 'note': note,
    if (!adm) ...{
      'visiteSimple': e.visite,
      'accompagnement': e.acc,
      'rdv': e.rdv,
      'appel': e.appel,
      'remplacement': e.remp,
      'soireeEtape': e.soiree,
      if (e.soiree) ...{
        'soireeLieu': (e.soireeLieu ?? '').trim(),
        'soireeAdresse': (e.soireeAdr ?? '').trim(),
      },
    },
  };
}

/// Corps de `POST /plannings` : une visite chez un client, planifiée pour un promoteur (jour seulement, sans heure).
Map<String, Object?> corpsPlanning({
  required String idApk,
  required String promoteurId,
  required String clientId,
  required String datePassage,
  String note = '',
}) {
  final n = note.trim();
  return {
    'idApk': idApk,
    'promoteurId': promoteurId,
    'clientId': clientId,
    'datePassage': datePassage,
    if (n.isNotEmpty) 'note': n,
  };
}

/// Message affiché quand l'envoi échoue : celui de l'API quand elle en donne un, sinon un texte selon le statut.
String messageErreurPlanning(ErreurApi e, {required bool pourPromoteur}) {
  if (e.detail != null || e.type != TypeErreurApi.inattendue) return e.message;
  return switch (e.statut) {
    400 => 'Ces informations sont refusées par le CRM. Vérifiez la saisie.',
    404 => 'Client, prospect ou promoteur introuvable dans votre périmètre.',
    409 =>
      pourPromoteur
          ? 'Une visite est déjà planifiée ce jour chez ce client.'
          : 'Cette semaine est verrouillée : plus rien ne peut y être ajouté.',
    _ => e.message,
  };
}
