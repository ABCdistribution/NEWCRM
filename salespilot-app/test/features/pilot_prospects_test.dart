import 'package:flutter_test/flutter_test.dart';
import 'package:salespilot/features/pilot/pilot_prospects_page.dart';
import 'package:salespilot/features/pilot/prospects_pipeline.dart';
import 'package:salespilot/features/pilot/tournee_etapes.dart';

void main() {
  test('les étapes du serveur se regroupent en quatre colonnes, les perdus sont écartés', () {
    expect(GroupeProspect.de('NOUVEAU'), GroupeProspect.aContacter);
    expect(GroupeProspect.de('CONTACTE'), GroupeProspect.aContacter);
    expect(GroupeProspect.de('VISITE'), GroupeProspect.rdvPris);
    expect(GroupeProspect.de('PROPOSITION'), GroupeProspect.enNego);
    expect(GroupeProspect.de('NEGOCIATION'), GroupeProspect.enNego);
    expect(GroupeProspect.de('GAGNE'), GroupeProspect.reference);
    expect(GroupeProspect.de('PERDU'), isNull);
  });

  test('le pipeline est aplati, trié par potentiel, sans les prospects perdus', () {
    final liste = ProspectPipeline.depuisPipeline({
      'etapes': [
        {
          'statut': 'NOUVEAU',
          'prospects': [
            {'id': 'a', 'enseigne': 'Super Gare', 'ville': 'Villiers', 'potentielCaAnnuel': '11000'},
            {'id': 'b', 'enseigne': '  ', 'raisonSociale': 'Sans enseigne SAS', 'potentielCaAnnuel': null},
          ],
        },
        {
          'statut': 'NEGOCIATION',
          'prospects': [
            {'id': 'c', 'enseigne': 'Hyper Plaine', 'ville': 'Noisy', 'potentielCaAnnuel': 42000},
          ],
        },
        {
          'statut': 'PERDU',
          'prospects': [
            {'id': 'd', 'enseigne': 'Perdu', 'potentielCaAnnuel': 99000},
          ],
        },
      ],
    })..sort(parPotentiel);
    expect(liste.map((p) => p.id), ['c', 'a', 'b']);
    expect(liste.last.enseigne, 'Sans enseigne SAS');
    expect(liste.first.groupe, GroupeProspect.enNego);
  });

  test('potentiel affiché en milliers d\'euros', () {
    expect(potentielCourt(42000), '42 k€/an');
    expect(potentielCourt(950), '950 €/an');
    expect(potentielCourt(null), '—');
  });

  test('la prochaine action dit auj., demain ou la date, avec l\'heure si elle est fixée', () {
    final lundi = DateTime(2026, 10, 26);
    EtapeTournee etape(DateTime jour, {String? heure, bool rdv = false}) =>
        EtapeTournee(id: 'x', jour: jour, heure: heure, titre: 'Prospect', type: 'PROSPECT', rdv: rdv);
    expect(prochaineAction(etape(lundi, heure: '09:00', rdv: true), lundi), 'RDV · auj. 09:00');
    expect(prochaineAction(etape(DateTime(2026, 10, 27)), lundi), 'Visite · demain');
    expect(prochaineAction(etape(DateTime(2026, 11, 4), rdv: true), lundi), 'RDV · 4 nov.');
  });
}
