/// Magasins de la même enseigne qu'un prospect (onglet « Magasins » de la fiche).
///
/// Maquette : `magasinsProspect` (l.1759-1767).
library;

import 'dart:math' as math;

import '../../../core/models/models.dart';
import '../data/villes_a_prospecter.dart';
import 'vue_prospects.dart';

/// Nature d'un magasin de l'enseigne : client, prospect, ou ni l'un ni l'autre (« À prospecter »).
enum TypeMagasinEnseigne { client, prospect, aProspecter }

/// Une ligne de l'onglet « Magasins » d'un prospect.
class MagasinEnseigne {
  const MagasinEnseigne({
    required this.nom,
    required this.ville,
    required this.type,
    this.detail = '',
    this.prospectId,
    this.magasinId,
  });

  final String nom;

  /// Adresse d'un client, « code postal et ville » d'un prospect, code postal d'un magasin à prospecter.
  final String ville;
  final TypeMagasinEnseigne type;

  /// « Classe B » pour un client, groupe du pipeline pour un prospect, vide sinon.
  final String detail;

  /// Prospect ou client à ouvrir au toucher (nuls pour un magasin « À prospecter »).
  final String? prospectId;
  final String? magasinId;
}

/// Enseigne d'un prospect : partie avant « – », sans « HM » final, en minuscules (`enseigne` de `magasinsProspect`).
String enseigneDuProspect(Prospect p) =>
    p.nom.split(' – ').first.replaceFirst(RegExp(r' HM$'), '').toLowerCase();

/// Magasins de l'enseigne : clients (2 au plus), prospects (2 au plus), puis des magasins « À prospecter » en nombre
/// tel que la liste compte 8 lignes, avec un minimum de 3 magasins à prospecter.
///
/// `prospects` : prospects visibles du profil ; `clients` : tous les clients du secteur ou de la région et les clients
/// hors région (`tousLesClients`).
List<MagasinEnseigne> magasinsDeLEnseigne(
  Prospect p, {
  required List<Prospect> prospects,
  required List<Magasin> clients,
}) {
  final enseigne = enseigneDuProspect(p);
  bool meme(String nom) => nom.toLowerCase().startsWith(enseigne);
  final autresProspects = prospects
      .where((x) => x.id != p.id && meme(x.nom))
      .map(
        (x) => MagasinEnseigne(
          nom: x.nom,
          ville: x.cp,
          type: TypeMagasinEnseigne.prospect,
          detail: libelleGroupeProspect(x),
          prospectId: x.id,
        ),
      )
      .take(2)
      .toList();
  final clientsEnseigne = clients
      .where((m) => meme(m.nom))
      .take(2)
      .map(
        (m) => MagasinEnseigne(
          nom: m.nom,
          ville: m.adresse,
          type: TypeMagasinEnseigne.client,
          detail: 'Classe ${m.classe}',
          magasinId: m.id,
        ),
      )
      .toList();
  final nb = math.max(3, 8 - autresProspects.length - clientsEnseigne.length);
  final prefixe = p.nom.split(' – ').first;
  final aProspecter = List.generate(nb, (i) {
    final v = villesAProspecter[(i + p.id.length) % villesAProspecter.length];
    return MagasinEnseigne(
      nom: '$prefixe – ${v.ville}',
      ville: v.codePostal,
      type: TypeMagasinEnseigne.aProspecter,
    );
  });
  return [...clientsEnseigne, ...autresProspects, ...aProspecter];
}
