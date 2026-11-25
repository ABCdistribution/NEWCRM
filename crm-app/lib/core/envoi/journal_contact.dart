/// Appel ou e-mail lancé depuis une fiche : l'application externe s'ouvre, puis l'action est journalisée dans le CRM par
/// la file d'envoi (rejouée hors connexion, idempotente par `idApk`).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/logic.dart';
import '../ui/lanceur_externe.dart';
import '../ui/retour_appli.dart';
import 'corps_activite.dart';
import 'corps_visite.dart';
import 'envoi_provider.dart';
import 'resultat_appel_sheet.dart';

/// Requête de journal pour une adresse lancée (`tel:` = appel, `mailto:` = e-mail), ou null pour toute autre adresse
/// (itinéraire) ou une fiche qui n'est pas au CRM.
RequeteActivite? requeteJournal(
  Uri uri, {
  required CibleActivite cible,
  required String id,
  required DateTime quand,
  ResultatAppel? resultat,
}) {
  if (!estUuid(id)) return null;
  return switch (uri.scheme) {
    'tel' => requeteAppel(cible, id, quand: quand, resultat: resultat),
    'mailto' => requeteEmail(
      cible,
      id,
      quand: quand,
      destinataire: Uri.decodeComponent(uri.path),
    ),
    _ => null,
  };
}

/// Ouvre `uri` dans l'application du téléphone, puis journalise l'appel ou l'e-mail dans le CRM (connecté seulement,
/// si `journaliser`, et seulement si l'application s'est bien ouverte). L'ouverture n'attend jamais le journal.
///
/// Pour un appel, une feuille demande le résultat (Répondu, Sans réponse, Messagerie, Rappel prévu) quand
/// l'utilisateur revient dans l'application, donc après l'appel. « Ignorer » journalise sans résultat (l'API prend sa
/// valeur par défaut). Tant que l'application n'est pas revenue au premier plan, rien n'est journalisé ; sans retour
/// avant le délai de sécurité (30 min), l'appel n'est pas journalisé non plus : rien n'atteste qu'il a eu lieu. Si le
/// retour n'est pas détectable (`SurveillantRetour.surveiller` nul), la feuille s'affiche aussitôt. Une feuille
/// impossible à afficher (écran quitté) journalise l'appel sans résultat.
Future<void> lancerEtJournaliser(
  BuildContext context,
  WidgetRef ref,
  Uri uri, {
  required CibleActivite cible,
  required String id,
  bool journaliser = true,
}) async {
  final lanceur = ref.read(lanceurExterneProvider);
  final envoi = ref.read(envoiProvider.notifier);
  final estAppel = uri.scheme == 'tel';
  // L'observateur est posé avant le lancement : le passage en arrière-plan ne peut pas être manqué.
  final attente = estAppel && journaliser && DemoTemps.reel
      ? ref.read(surveillantRetourProvider).surveiller()
      : null;
  final ok = await lancerExterne(context, lanceur, uri);
  if (!ok || !journaliser || !DemoTemps.reel) {
    attente?.annuler();
    return;
  }
  final quand = DateTime.now();
  // Sans journal à écrire (adresse d'itinéraire, fiche hors CRM), aucune question n'est posée.
  if (requeteJournal(uri, cible: cible, id: id, quand: quand) == null) {
    attente?.annuler();
    return;
  }
  ResultatAppel? resultat;
  if (estAppel) {
    if (attente != null && !await attente.retour) return;
    if (context.mounted) resultat = await demanderResultatAppel(context);
  }
  final requete = requeteJournal(
    uri,
    cible: cible,
    id: id,
    quand: quand,
    resultat: resultat,
  );
  if (requete != null) unawaited(envoi.enfilerActivite(requete));
}
