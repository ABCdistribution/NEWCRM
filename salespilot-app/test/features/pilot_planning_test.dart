import 'package:flutter_test/flutter_test.dart';
import 'package:salespilot/features/pilot/pilot_planning_page.dart';

void main() {
  test('numéro de semaine ISO : 28 octobre 2026 = semaine 44 (maquette)', () {
    expect(semaineIso(DateTime(2026, 10, 28)), 44);
    expect(semaineIso(DateTime(2026, 10, 26)), 44);
    expect(semaineIso(DateTime(2026, 1, 1)), 1);
    expect(semaineIso(DateTime(2026, 12, 31)), 53);
  });

  test('le lundi de la semaine du 28 octobre 2026 est le 26', () {
    expect(lundiDe(DateTime(2026, 10, 28)), DateTime(2026, 10, 26));
    expect(lundiDe(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
  });

  test('regroupement des étapes du pipeline en quatre colonnes', () {
    final c = CompteursProspection.fromPipeline({
      'etapes': [
        {'statut': 'NOUVEAU', 'total': 5},
        {'statut': 'CONTACTE', 'total': 3},
        {'statut': 'PROPOSITION', 'total': 1},
        {'statut': 'VISITE', 'total': 4},
        {'statut': 'NEGOCIATION', 'total': 1},
        {'statut': 'GAGNE', 'total': 1},
        {'statut': 'PERDU', 'total': 9},
      ],
    });
    expect((c.aContacter, c.rdvPris, c.enNego, c.references), (8, 4, 2, 1));
  });
}
