import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

List<Alerte> alertesDe(Role role, {int jour = 2}) {
  final e = CrmEtat.initial(role);
  return calculerAlertes(
    role: role,
    magasins: e.magasins,
    prospects: e.prospects,
    etapes: e.etapes,
    visites: e.visites,
    visitesAutres: e.visitesAutres,
    commandes: e.commandes,
    jour: jour,
  );
}

void main() {
  test('directeur : visites en retard, livraison du jour, client inactif', () {
    final l = alertesDe(Role.dir);
    expect(l.map((a) => a.magasinId), ['m1', 'm8', 'm7', 'm5']);
    expect(l.map((a) => a.rang), [-2, 10, 50, 90]);
    expect(l.first.niveau, NiveauAlerte.haut);
    expect(
      l.first.detail,
      'Pas visité depuis 15 jours · visite attendue tous les 7 jours',
    );
    expect(l[1].niveau, NiveauAlerte.moy);
    expect(
      l[2].detail,
      "Commande CDE-2033 : livraison prévue aujourd'hui, pas encore livrée",
    );
    expect(l.last.detail, 'Client inactif · dernière commande en septembre');
  });

  test('promoteur : seulement son portefeuille, aucune alerte prospect', () {
    final l = alertesDe(Role.promoteur);
    expect(l.map((a) => a.magasinId), ['m1', 'm8', 'm5']);
    expect(l.any((a) => a.estProspect), isFalse);
  });

  test('chef de secteur : alertes clients et prospects, triées par urgence', () {
    final l = alertesDe(Role.cs);
    expect(l.map((a) => a.magasinId ?? a.prospectId), [
      'm1',
      'p2',
      'm8',
      'p5',
      'p9',
      'p19',
      'm5',
    ]);
    final rdv = l.firstWhere((a) => a.prospectId == 'p2');
    expect(rdv.niveau, NiveauAlerte.haut);
    expect(rdv.detail, 'RDV prospect aujourd’hui à 11:30 · À contacter');
    final nego = l.firstWhere((a) => a.prospectId == 'p5');
    expect(
      nego.detail,
      'Prospect en négo sans action prévue depuis 6 jours · à relancer (120 k€/an)',
    );
    final contacte = l.firstWhere((a) => a.prospectId == 'p9');
    expect(contacte.niveau, NiveauAlerte.moy);
    expect(
      contacte.detail,
      'Contacté il y a 5 jours, pas de RDV obtenu · à contacter',
    );
  });

  test('le RDV prospect n’est une alerte que le jour même', () {
    final l = alertesDe(Role.cs, jour: 3);
    expect(l.any((a) => a.prospectId == 'p2'), isFalse);
    expect(
      l.any((a) => a.prospectId == 'p1'),
      isTrue,
    ); // RDV de négociation prévu jeudi
  });

  test(
    'joursDepuisVisite : minimum entre mes visites (0) et celles des autres',
    () {
      final e = CrmEtat.initial(Role.dir);
      int? j(String id) => joursDepuisVisite(
        id,
        visites: e.visites,
        visitesAutres: e.visitesAutres,
      );
      expect(j('m1'), 15);
      expect(j('m4'), 0);
      expect(j('m2'), 1);
      expect(j('m5'), isNull);
    },
  );

  test('l’état partagé suit le profil', () {
    final c = conteneurPour(Role.promoteur);
    final e = c.read(crmProvider);
    expect(e.magasins.map((m) => m.id), ['m1', 'm8', 'm5', 'm4']);
    expect(e.prospects, isEmpty);
    expect(e.tournee.map((t) => t.magasinId), ['m4', 'm1', 'm8']);
    expect(e.visites.map((v) => v.id), ['d0']);
    expect(c.read(alertesProvider), hasLength(3));
  });
}
