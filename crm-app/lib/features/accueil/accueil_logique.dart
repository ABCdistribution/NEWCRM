/// Calculs de l'accueil, en fonctions pures (maquette : `etatTournee`, `salesAccueil`, `blocProspectsCS`,
/// `prochaineAction`, `carte` de `pageAccueil`).
library;

import '../../core/logic/logic.dart';
import '../../core/models/models.dart';
import '../../core/state/state.dart';

/// État d'une visite de la tournée du jour du promoteur (maquette : `etatTournee`).
enum EtatTournee { realisee, enCours, aFaire }

/// Une visite du jour a-t-elle été commencée (brouillon : « En cours ») ou faite chez ce client ?
EtatTournee etatTournee(List<Visite> visites, String magasinId) {
  for (final v in visites) {
    if (v.magasinId == magasinId && v.date.startsWith(DemoTemps.jourCourt)) {
      return v.etat == EtatVisite.brouillon
          ? EtatTournee.enCours
          : EtatTournee.realisee;
    }
  }
  return EtatTournee.aFaire;
}

/// Une étape de « Ma tournée du jour » du promoteur.
class LigneTournee {
  const LigneTournee({
    required this.visite,
    required this.magasin,
    required this.etat,
    required this.demarrer,
  });

  final TourneeVisite visite;
  final Magasin magasin;
  final EtatTournee etat;

  /// Vrai pour la première visite « À faire » quand aucune n'est « En cours » : le bouton « Démarrer la visite ».
  final bool demarrer;
}

/// Tournée du promoteur avec l'état de chaque étape (maquette : `items` de `salesAccueil`).
List<LigneTournee> lignesTournee(CrmEtat e) {
  final etats = [
    for (final t in e.tournee) etatTournee(e.visites, t.magasinId),
  ];
  var peutDemarrer = !etats.contains(EtatTournee.enCours);
  final lignes = <LigneTournee>[];
  for (var i = 0; i < e.tournee.length; i++) {
    final t = e.tournee[i];
    final magasin = e.magasinParId(t.magasinId);
    if (magasin == null) continue;
    final demarrer = etats[i] == EtatTournee.aFaire && peutDemarrer;
    if (demarrer) peutDemarrer = false;
    lignes.add(
      LigneTournee(
        visite: t,
        magasin: magasin,
        etat: etats[i],
        demarrer: demarrer,
      ),
    );
  }
  return lignes;
}

/// Commandes des clients visibles pas encore livrées, les plus urgentes d'abord (maquette : `livs`).
List<Commande> livraisonsEnCours(CrmEtat e) => triStable<Commande>(
  e.commandesVisibles.where((c) => c.statut != StatutLivraison.livree),
  (a, b) => a.statut.ordre.compareTo(b.statut.ordre),
);

/// Détail d'une étape du planning : « 11:30 · Prospect · RDV · note » (maquette : `det` de `pageAccueil`).
String detailEtape(EtapePlanning e) => [
  e.heure,
  e.cible.libelle,
  if (e.rdv) 'RDV',
  e.note,
].where((s) => s.isNotEmpty).join(' · ');

/// Les trois prospects à suivre en priorité : ceux en négociation d'abord, puis par potentiel × probabilité décroissant
/// (maquette : `blocProspectsCS`).
List<Prospect> prospectsASuivre(List<Prospect> prospects) {
  final actifs = prospects.where(
    (p) => p.statut != StatutProspect.gagne && p.statut != StatutProspect.perdu,
  );
  int enNego(Prospect p) => p.groupe == GroupeProspect.enNego ? 1 : 0;
  final tries = triStable<Prospect>(actifs, (a, b) {
    final c = enNego(b).compareTo(enNego(a));
    return c != 0 ? c : (b.pot * b.proba).compareTo(a.pot * a.proba);
  });
  return tries.take(3).toList();
}

/// Prochaine étape prévue pour un prospect : « 📅 RDV · Jeu 10:00 » (maquette : `prochaineAction`), nulle sans étape.
String? prochaineAction(Prospect p, List<EtapePlanning> etapes) {
  for (final e in etapes) {
    if (e.cible == CiblePlanning.prospect && e.ref == p.id && !e.fait) {
      return '📅 ${e.rdv ? 'RDV' : 'Visite'} · ${joursCourts[e.jour]} ${e.heure}';
    }
  }
  return null;
}
