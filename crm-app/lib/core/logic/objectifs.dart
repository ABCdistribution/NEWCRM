/// Objectifs : couleur selon le taux d'atteinte, objectifs et opérations promotionnelles d'un magasin.
library;

import '../models/models.dart';

/// Niveau d'atteinte d'un objectif : vert ≥ 90 %, orange ≥ 70 %, rouge en dessous (`couleurObj`).
enum NiveauObjectif { bon, moyen, faible }

NiveauObjectif niveauObjectif(num pct) => pct >= 90
    ? NiveauObjectif.bon
    : pct >= 70
    ? NiveauObjectif.moyen
    : NiveauObjectif.faible;

/// Total réalisé / cible d'un groupe de promoteurs (`totalEq`).
TotalObjectif totalObjectif(Iterable<Promoteur> promoteurs) {
  var real = 0.0;
  var cible = 0.0;
  for (final p in promoteurs) {
    real += p.real;
    cible += p.cible;
  }
  return TotalObjectif(real, cible);
}

/// État d'une opération promotionnelle.
enum EtatOp {
  enCours('En cours'),
  aVenir('À venir'),
  terminee('Terminée');

  const EtatOp(this.libelle);
  final String libelle;
}

class OperationPromo {
  const OperationPromo(this.nom, this.du, this.au, this.etat);
  final String nom;
  final String du;
  final String au;
  final EtatOp etat;
}

/// CA du mois / objectif et opérations promotionnelles d'un magasin (`objMag`).
class ObjectifMagasin {
  const ObjectifMagasin(this.ca, this.obj, this.ops);
  final int ca;
  final int obj;
  final List<OperationPromo> ops;

  /// Taux d'atteinte arrondi, plafonné à 100 sur la fiche magasin.
  int get pct => (ca / obj * 100).round();
}

/// Données de démonstration stables par magasin, calculées à partir de son id (`objMag`).
ObjectifMagasin objectifMagasin(Magasin m) {
  final n = m.id.runes.fold<int>(0, (a, c) => a + c);
  final obj = 3000 + (n % 9) * 450;
  final ca = ((obj * (0.55 + (n % 7) * 0.08) / 10).round()) * 10;
  const toutes = [
    OperationPromo(
      'Remise -20 % gamme soin',
      '2 nov.',
      '15 nov.',
      EtatOp.enCours,
    ),
    OperationPromo(
      'Tête de gondole PEM Noël',
      '16 nov.',
      '6 déc.',
      EtatOp.aVenir,
    ),
    OperationPromo(
      '2 achetés = 1 offert maquillage',
      '1 oct.',
      '31 oct.',
      EtatOp.terminee,
    ),
  ];
  final ops = <OperationPromo>[
    for (var i = 0; i < toutes.length; i++)
      if ((n + i) % 3 != 0 || i == 0) toutes[i],
  ];
  return ObjectifMagasin(ca, obj, ops);
}
