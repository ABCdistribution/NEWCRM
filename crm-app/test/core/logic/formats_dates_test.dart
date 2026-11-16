import 'package:crm_app/core/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formats', () {
    test('eur arrondit et sépare les milliers par des espaces insécables', () {
      expect(eur(4200), '4 200 €');
      expect(eur(1700), '1 700 €');
      expect(eur(950.4), '950 €');
      expect(eur(0), '0 €');
    });

    test('euros : deux décimales, virgule, espace avant €', () {
      expect(euros(3.46), '3,46 €');
      expect(euros(11), '11,00 €');
      expect(euros(20.05), '20,05 €');
    });

    test('eurD : milliers séparés', () {
      expect(eurD(1540), '1 540,00 €');
      expect(eurD(958.7), '958,70 €');
      expect(eurD(12345.678), '12 345,68 €');
    });

    test('kf : virgule décimale sans « .0 »', () {
      expect(kf(180), '180');
      expect(kf(1.5), '1,5');
      expect(kf(29.4), '29,4');
    });

    test('pluriel', () {
      expect(pluriel(1, 'client'), '1 client');
      expect(pluriel(3, 'client'), '3 clients');
    });
  });

  group('dates', () {
    test('semaine 45 : lundi 2 au vendredi 6 novembre', () {
      final s = semaineInfo(0);
      expect(s.num, 45);
      expect(s.dates, [2, 3, 4, 5, 6]);
      expect(s.libelle, '2 – 6 nov.');
    });

    test('semaine à cheval sur deux mois', () {
      final s = semaineInfo(4);
      expect(s.num, 49);
      expect(s.dates, [30, 1, 2, 3, 4]);
      expect(s.libelle, '30 nov. – 4 déc.');
    });

    test('dateFr', () {
      expect(dateFr('2026-11-16'), '16 nov.');
      expect(dateFr('2026-12-01'), '1 déc.');
    });

    test('ageDepuisTexte (au 4 novembre)', () {
      expect(ageDepuisTexte('4 nov. 08:30'), 0);
      expect(ageDepuisTexte('3 nov. 11:20'), 1);
      expect(ageDepuisTexte('20 oct. 14:30'), 15);
      expect(ageDepuisTexte('hier'), 99);
    });

    test('joursDepuisTimeline', () {
      expect(joursDepuisTimeline('3 nov.'), 1);
      expect(joursDepuisTimeline('29 oct.'), 6);
      expect(joursDepuisTimeline('1 sept.'), 64);
      expect(joursDepuisTimeline('ven. 6 nov.'), isNull);
      expect(joursDepuisTimeline('auj.'), isNull);
    });

    test('horodatage', () {
      expect(horodatage(4, 'nov', 8, 30), '04/11/2026 08h30');
      expect(horodatage(20, 'oct', 14, 5), '20/10/2026 14h05');
    });
  });
}
