import 'package:flutter_test/flutter_test.dart';
import 'package:salespilot/features/visite/visite_etapes_page.dart';
import 'package:salespilot/features/visite/visite_models.dart';

void main() {
  final debut = DateTime(2026, 10, 28, 11, 4);

  test('visite vide : check-in fait, relevé linéaire en cours', () {
    final e = etapesDe(const VisiteData(), demarree: debut);
    expect(e[0].etat, EtatEtape.fait);
    expect(e[0].detail, '11:04');
    expect(e[1].etat, EtatEtape.enCours);
    expect(e.where((x) => x.etat == EtatEtape.fait), hasLength(1));
  });

  test('photos et commentaire marquent les étapes 4 et 6', () {
    final e = etapesDe(const VisiteData(photos: ['a.jpg', 'b.jpg'], commentaire: 'RAS'), demarree: debut);
    expect(e[3].etat, EtatEtape.fait);
    expect(e[3].detail, '2 photos');
    expect(e[5].etat, EtatEtape.fait);
    expect(e[1].etat, EtatEtape.enCours);
  });
}
