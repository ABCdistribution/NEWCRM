/// Liste filtrée des commandes de l'onglet « Commandes » (maquette : `commandesListe`).
library;

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/state/state.dart';
import '../state/filtres_commandes.dart';

/// Complément de « Toutes les commandes » selon le rôle (`PORTEE_TXT`).
String porteeTexte(Role role) => switch (role) {
  Role.promoteur => 'sur vos clients',
  Role.cs => 'de votre secteur',
  Role.dir => 'de votre région',
};

/// Commandes des clients visibles, filtrées puis triées : les pas livrées d'abord, l'ordre d'origine sinon.
/// `ignorerEtat` sert aux compteurs « Pas livrées » et « Livrées », qui ne dépendent pas du filtre d'état.
List<Commande> commandesListe(
  CrmEtat etat,
  FiltresCommandes f, {
  bool ignorerEtat = false,
}) {
  final moi = etat.nomProfil;
  final q = f.q.toLowerCase();
  final statut = f.etat.statut;
  bool garde(Commande c) {
    if (f.portee != PorteeCommandes.toutes && auteurCommande(c) != moi) {
      return false;
    }
    if (!ignorerEtat && statut != null && c.statut != statut) return false;
    if (f.type != TypeCommande.tous &&
        (f.type == TypeCommande.edi) != c.estEdi) {
      return false;
    }
    if (f.periode != PeriodeCommandes.toutes) {
      final age = ageDepuisTexte(c.date);
      if (f.periode == PeriodeCommandes.jour ? age != 0 : age > 7) {
        return false;
      }
    }
    if (q.isNotEmpty) {
      final nom = etat.magasinParId(c.magasinId)?.nom ?? '';
      final cible = '$nom ${c.id} ${auteurCommande(c) ?? ''}'.toLowerCase();
      if (!cible.contains(q)) return false;
    }
    return true;
  }

  return triStable<Commande>(
    etat.commandesVisibles.where(garde),
    (a, b) => a.statut.ordre.compareTo(b.statut.ordre),
  );
}
