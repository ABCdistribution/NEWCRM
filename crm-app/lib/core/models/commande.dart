/// Commande et suivi de livraison : maquette `COMMANDES`, `STATUTS_LIV`.
library;

/// Statut de livraison (`STATUTS_LIV`).
enum StatutLivraison {
  pasLivree('PAS_LIVREE', 'Pas livrée'),
  livree('LIVREE', 'Livrée');

  const StatutLivraison(this.code, this.libelle);
  final String code;
  final String libelle;

  /// Ordre d'affichage : les commandes pas encore livrées d'abord (`ordreLiv`).
  int get ordre => this == pasLivree ? 0 : 1;
}

/// Un événement du suivi de transport (« Expédiée », « 3 nov. 18:40 · Geodis »).
class EvenementTransport {
  const EvenementTransport(this.libelle, this.detail);
  final String libelle;
  final String detail;
}

class Commande {
  const Commande({
    required this.id,
    required this.magasinId,
    required this.date,
    required this.ht,
    required this.lignes,
    required this.statut,
    required this.eta,
    required this.colis,
    required this.evenements,
    this.src,
    this.transporteur,
    this.suivi,
    this.par,
    this.pasAvant,
    this.motifPas,
    this.note,
  });

  /// « CDE-2041 ».
  final String id;
  final String magasinId;

  /// « 3 nov. ».
  final String date;

  /// Montant HT déjà formaté (« 1 540,00 € »).
  final String ht;

  /// Nombre de références.
  final int lignes;
  final StatutLivraison statut;

  /// Date de livraison prévue ou réalisée, en texte (« ven. 6 nov. », « livrée le 22 oct. »).
  final String eta;
  final int colis;
  final List<EvenementTransport> evenements;

  /// Origine : « EDI », « Appli » ou nulle (commande de la maquette sans origine).
  final String? src;
  final String? transporteur;
  final String? suivi;

  /// Auteur si la commande a été saisie dans l'appli (sinon voir `parMagasin`).
  final String? par;

  /// Consigne « Ne pas livrer avant » : date ISO `aaaa-mm-jj` et motif.
  final String? pasAvant;
  final String? motifPas;
  final String? note;

  bool get estEdi => src == 'EDI';
}
