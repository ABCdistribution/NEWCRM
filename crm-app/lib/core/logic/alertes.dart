/// Alertes de la cloche : visite en retard, livraison du jour, client inactif, relances prospects.
///
/// Fonctions pures (maquette : `alertes()`, `alertesProspects()`, `joursDepuisVisite()`).
library;

import 'dart:math' as math;

import '../models/models.dart';
import 'classes.dart';
import 'dates.dart';
import 'formats.dart';
import 'tri.dart';

/// Jours écoulés depuis la dernière visite d'un client, nul si jamais visité.
/// Les visites du profil comptent pour 0 jour (maquette), celles des autres pour leur âge.
int? joursDepuisVisite(
  String magasinId, {
  required List<Visite> visites,
  required List<Visite> visitesAutres,
}) {
  final ages = <int>[
    ...visites.where((v) => v.magasinId == magasinId).map((_) => 0),
    ...visitesAutres.where((v) => v.magasinId == magasinId).map((v) => v.age),
  ];
  return ages.isEmpty ? null : ages.reduce(math.min);
}

/// Alertes prospects du chef de secteur : RDV du jour, relance à faire, prospect jamais contacté.
List<Alerte> alertesProspects({
  required List<Prospect> prospects,
  required List<EtapePlanning> etapes,
  required int jour,
}) {
  final liste = <Alerte>[];
  for (final p in prospects) {
    if (p.statut == StatutProspect.gagne ||
        p.statut == StatutProspect.perdu ||
        p.attente) {
      continue;
    }
    EtapePlanning? prevu;
    for (final e in etapes) {
      if (e.cible == CiblePlanning.prospect && e.ref == p.id && !e.fait) {
        prevu = e;
        break;
      }
    }
    final ages = p.timeline
        .map((e) => joursDepuisTimeline(e.date))
        .whereType<int>();
    final age = ages.isEmpty ? null : ages.reduce(math.min);
    final groupe = p.groupe?.libelle ?? '';
    if (prevu != null && prevu.jour == jour) {
      liste.add(
        Alerte(
          niveau: NiveauAlerte.haut,
          prospectId: p.id,
          icone: '📅',
          titre: p.nom,
          classe: p.classe,
          detail: 'RDV prospect aujourd’hui à ${prevu.heure} · $groupe',
          rang: 5,
        ),
      );
    } else if (prevu == null &&
        (p.statut == StatutProspect.proposition ||
            p.statut == StatutProspect.negociation) &&
        age != null &&
        age >= 5) {
      liste.add(
        Alerte(
          niveau: NiveauAlerte.haut,
          prospectId: p.id,
          icone: '💬',
          titre: p.nom,
          classe: p.classe,
          detail:
              'Prospect en négo sans action prévue depuis $age jours · à relancer (${kf(p.pot)} k€/an)',
          rang: 15,
        ),
      );
    } else if (prevu == null &&
        (p.statut == StatutProspect.nouveau ||
            p.statut == StatutProspect.contacte) &&
        age != null &&
        age >= 3) {
      liste.add(
        Alerte(
          niveau: NiveauAlerte.moy,
          prospectId: p.id,
          icone: '🎯',
          titre: p.nom,
          classe: p.classe,
          detail:
              '${p.statut == StatutProspect.nouveau ? 'Fiche créée il y a $age jours, aucun contact pris' : 'Contacté il y a $age jours, pas de RDV obtenu'} · à contacter',
          rang: 60,
        ),
      );
    }
  }
  return liste;
}

/// Toutes les alertes du profil, les plus urgentes d'abord.
List<Alerte> calculerAlertes({
  required Role role,
  required List<Magasin> magasins,
  required List<Prospect> prospects,
  required List<EtapePlanning> etapes,
  required List<Visite> visites,
  required List<Visite> visitesAutres,
  required List<Commande> commandes,
  required int jour,
}) {
  final l = <Alerte>[];
  for (final m in magasins) {
    if (!m.actif) {
      // Client réel : le CRM ne donne pas la date de sa dernière commande, aucune alerte n'est fabriquée.
      if (m.reel) continue;
      l.add(
        Alerte(
          niveau: NiveauAlerte.moy,
          magasinId: m.id,
          icone: '💤',
          titre: m.nom,
          classe: m.classe,
          detail: 'Client inactif · dernière commande en septembre',
          rang: 90,
        ),
      );
      continue;
    }
    final j = joursDepuisVisite(
      m.id,
      visites: visites,
      visitesAutres: visitesAutres,
    );
    final seuil = seuilPourClasse(m.classe);
    if (j != null && j > seuil) {
      l.add(
        Alerte(
          niveau: seuil <= 10 ? NiveauAlerte.haut : NiveauAlerte.moy,
          magasinId: m.id,
          icone: '📍',
          titre: m.nom,
          classe: m.classe,
          detail:
              'Pas visité depuis $j jours · visite attendue tous les $seuil jours',
          rang: classeRang(m.classe),
        ),
      );
    }
  }
  final parId = {for (final m in magasins) m.id: m};
  for (final c in commandes) {
    if (c.statut != StatutLivraison.pasLivree || !c.eta.contains('aujourd')) {
      continue;
    }
    final m = parId[c.magasinId];
    if (m == null) continue;
    l.add(
      Alerte(
        niveau: NiveauAlerte.moy,
        magasinId: m.id,
        icone: '🚚',
        titre: m.nom,
        classe: m.classe,
        detail:
            "Commande ${c.id} : livraison prévue aujourd'hui, pas encore livrée",
        rang: 50,
      ),
    );
  }
  if (role == Role.cs) {
    l.addAll(
      alertesProspects(prospects: prospects, etapes: etapes, jour: jour),
    );
  }
  return triStable<Alerte>(l, (a, b) => a.rang.compareTo(b.rang));
}
