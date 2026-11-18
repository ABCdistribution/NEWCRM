import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Les jeux de démonstration sont la copie fidèle de la maquette `demo-appli.html` : nombres d'enregistrements et
/// quelques enregistrements relus mot à mot (le contrôleur a comparé 100 % des champs avec la maquette exécutée).
void main() {
  test('aucun jeu de données n’est tronqué', () {
    expect(magasinsDemo, hasLength(10)); // etatInitial().magasins
    expect(autresClients, hasLength(22)); // AUTRES_CLIENTS
    expect(prospectsDemo, hasLength(23)); // etatInitial().prospects
    expect(etapesDemo, hasLength(8)); // etatInitial().etapes
    expect(tourneeDemo, hasLength(9)); // tourneeSales
    expect(commandesDemo, hasLength(10)); // COMMANDES (8 + 2)
    expect(visitesAutresDemo, hasLength(10)); // VISITES_AUTRES
    expect(produitsCatalogue, hasLength(14)); // PRODUITS
    expect(produitsKit, hasLength(2)); // PRODUITS_KIT
    expect(produitsPem, hasLength(8)); // PRODUITS_PEM
    expect(marquesCatalogue, hasLength(3)); // CATS
    expect(tousProduits(), hasLength(24));
    expect(chefsSecteurDemo, hasLength(3)); // EQUIPE_CS
    expect(tousPromoteurs(), hasLength(8)); // PROMOS
    expect(motifsVisite, hasLength(5)); // MOTIFS
    expect(sourcesProspect, hasLength(4)); // SOURCES
  });

  test('clients : enregistrements relus dans la maquette', () {
    final m1 = magasinsDemo.firstWhere((m) => m.id == 'm1');
    expect(m1.nom, 'Carrefour Market – Versailles');
    expect(m1.classe, 'A++');
    expect(m1.ca, '29,4 k€');
    expect(m1.evo, '−14 %');
    expect(m1.cde, '958 €');
    expect(m1.contact, 'Thomas N., chef de rayon');
    final m5 = magasinsDemo.firstWhere((m) => m.id == 'm5');
    expect(m5.actif, isFalse); // « Client inactif »
    expect(m5.cdeDate, '3 sept.');
  });

  test('prospects : enregistrements relus dans la maquette', () {
    final p1 = prospectsDemo.firstWhere((p) => p.id == 'p1');
    expect(p1.nom, 'Super U – Versailles');
    expect(p1.statut, StatutProspect.negociation);
    expect(p1.pot, 180);
    expect(p1.proba, 60);
    expect(p1.timeline, hasLength(5));
    expect(p1.timeline.first.titre, 'RDV de négociation prévu');
    expect(p1.timeline.last.detail, 'Source : terrain · par Nadia H.');
    final p23 = prospectsDemo.last;
    expect(p23.id, 'p23');
    expect(p23.cs, 'Karim B.');
    expect(p23.nom, 'Carrefour HM – Mondeville');
  });

  test('commandes et visites : enregistrements relus dans la maquette', () {
    final c = commandesDemo.firstWhere((c) => c.id == 'CDE-2033');
    expect(c.ht, '1 060,00 €');
    expect(c.eta, "mer. 4 nov. (aujourd'hui)");
    expect(c.transporteur, 'Chronopost Freight');
    expect(c.evenements.last.detail, '2 nov. 15:10 · Chronopost Freight');
    final v = visitesAutresDemo.firstWhere((v) => v.id == 'x4');
    expect(v.num, 218087);
    expect(v.par, 'Amine K.');
    expect(v.cmd?.id, '2039');
    expect(v.chrono[EtapeDph.debut], '03/11/2026 09h40');
  });

  test('produits et équipe : enregistrements relus dans la maquette', () {
    final p = produitsCatalogue.firstWhere((p) => p.id == 'a13');
    expect(p.nom, 'Stick lèvres SPF 30');
    expect(p.stock, NiveauStock.rupture);
    expect(p.reappro, '12 nov.');
    expect(produitsCatalogue.firstWhere((p) => p.id == 'a5').kit, isTrue);
    final amine = promoteurParNom('Amine K.')!;
    expect(amine.real, 5800);
    expect(amine.cible, 5700);
    expect(amine.obj, 102);
  });

  test('périmètre par rôle : mêmes nombres que la maquette', () {
    final attendu = {
      Role.promoteur: (4, 0, 3, 3),
      Role.cs: (6, 12, 5, 5),
      Role.dir: (10, 23, 8, 9),
    };
    for (final e in attendu.entries) {
      final etat = conteneurPour(e.key).read(crmProvider);
      expect(etat.magasins, hasLength(e.value.$1), reason: '${e.key} clients');
      expect(
        etat.prospects,
        hasLength(e.value.$2),
        reason: '${e.key} prospects',
      );
      expect(etat.etapes, hasLength(e.value.$3), reason: '${e.key} planning');
      expect(etat.tournee, hasLength(e.value.$4), reason: '${e.key} tournée');
    }
  });
}
