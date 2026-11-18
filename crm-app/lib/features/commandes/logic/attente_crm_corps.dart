/// Corps des appels `/commandes/apk` à partir de la commande en cours de saisie (fonctions pures).
library;

import 'attente_crm.dart';
import '../state/commande_en_cours.dart';

/// Prix indicatif d'un article (nul s'il est inconnu de l'app).
typedef PrixArticle = double? Function(String articleId);

/// Lignes pour l'API : l'article (UUID du CRM), la quantité et le prix affiché à la saisie. Un article que l'app ne
/// connaît pas garde le prix que le CRM avait déjà.
List<Map<String, Object?>> lignesPourApi(
  List<LigneCommande> lignes,
  PrixArticle prixDe, {
  CommandeAttenteCrm? crm,
}) {
  final anciens = {
    if (crm != null)
      for (final l in crm.lignes) l.articleId: l.prixIndicatif,
  };
  return [
    for (final l in lignes)
      if (l.qty > 0)
        {
          'articleId': l.produitId,
          'quantite': l.qty,
          'prixIndicatif': ?(prixDe(l.produitId) ?? anciens[l.produitId]),
        },
  ];
}

/// Remarque libre de la commande (le commentaire du CRM).
String commentaireDe(CommandeEnCours cmd) => cmd.note.trim();

/// Consigne « Ne pas livrer avant » à envoyer : date et motif (« Autre » résolu en texte), nulle si elle n'est pas
/// complète (l'API refuse une date sans motif).
({String date, String motif})? consigneDe(CommandeEnCours cmd) {
  if (!cmd.pas || cmd.dateMin.isEmpty || cmd.motifPas.isEmpty) return null;
  final motif = motifFinal(cmd.motifPas, cmd.motifAutre);
  return (
    date: cmd.dateMin,
    motif: motif.length > 200 ? motif.substring(0, 200) : motif,
  );
}

/// `POST /commandes/apk` d'une commande mise en attente.
Map<String, Object?> corpsCreation(
  CommandeEnCours cmd, {
  required String idApk,
  required DateTime maintenant,
  required PrixArticle prixDe,
  String? email,
}) {
  final commentaire = commentaireDe(cmd);
  final consigne = consigneDe(cmd);
  return {
    'idCommandeApk': idApk,
    'clientId': cmd.magasinId,
    'dateCommande': maintenant.toUtc().toIso8601String(),
    'statut': 'EN_ATTENTE',
    if (email != null && email.isNotEmpty) 'emailValidation': email,
    if (commentaire.isNotEmpty) 'commentaire': commentaire,
    if (consigne != null) 'nePasLivrerAvant': consigne.date,
    if (consigne != null) 'motifNePasLivrerAvant': consigne.motif,
    'lignes': lignesPourApi(cmd.lignes, prixDe),
  };
}

/// `PATCH /commandes/apk/:id` : seulement ce qui a changé depuis l'état connu du CRM ; vide si rien n'a changé.
Map<String, Object?> corpsModification(
  CommandeEnCours cmd,
  CommandeAttenteCrm crm,
  PrixArticle prixDe,
) {
  final lignes = [
    for (final l in cmd.lignes)
      if (l.qty > 0) l,
  ];
  final memes =
      lignes.length == crm.lignes.length &&
      [
        for (var i = 0; i < lignes.length; i++)
          lignes[i].produitId == crm.lignes[i].articleId &&
              lignes[i].qty == crm.lignes[i].quantite,
      ].every((b) => b);
  final commentaire = commentaireDe(cmd);
  final consigne = consigneDe(cmd);
  // Une consigne à l'ancien format est migrée vers les champs de l'API au premier enregistrement.
  final heritee = crm.consigneHeritee;
  final consigneChangee =
      heritee ||
      consigne?.date != crm.nePasLivrerAvant ||
      (consigne != null && consigne.motif != crm.motifNePasLivrerAvant);
  return {
    if (!memes) 'lignes': lignesPourApi(lignes, prixDe, crm: crm),
    if (commentaire != crm.commentaire || heritee)
      'commentaire': commentaire.isEmpty ? null : commentaire,
    // `nePasLivrerAvant: null` efface la date et le motif.
    if (consigneChangee && consigne == null) 'nePasLivrerAvant': null,
    if (consigneChangee && consigne != null) ...{
      'nePasLivrerAvant': consigne.date,
      'motifNePasLivrerAvant': consigne.motif,
    },
  };
}
