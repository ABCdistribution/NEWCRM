/// Appel ou e-mail lancé depuis une fiche : l'application externe s'ouvre, puis l'action est journalisée dans le CRM par
/// la file d'envoi (rejouée hors connexion, idempotente par `idApk`).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/logic.dart';
import '../ui/lanceur_externe.dart';
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
/// Pour un appel, une feuille demande ensuite le résultat (Répondu, Sans réponse, Messagerie, Rappel prévu) : elle
/// s'affiche aussitôt après le lancement, donc visible au retour dans l'application. « Ignorer » journalise sans
/// résultat (l'API prend sa valeur par défaut).
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
  final ok = await lancerExterne(context, lanceur, uri);
  if (!ok || !journaliser || !DemoTemps.reel) return;
  final quand = DateTime.now();
  // Sans journal à écrire (adresse d'itinéraire, fiche hors CRM), aucune question n'est posée.
  if (requeteJournal(uri, cible: cible, id: id, quand: quand) == null) return;
  ResultatAppel? resultat;
  if (uri.scheme == 'tel' && context.mounted) {
    resultat = await demanderResultatAppel(context);
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
