import 'package:crm_app/core/logic/logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    DemoTemps.reel = false;
    DemoTemps.maintenant = DateTime.now;
  });

  void aujourdhui(DateTime d) {
    DemoTemps.reel = true;
    DemoTemps.maintenant = () => d;
  }

  test('démonstration : toujours le mercredi 4 novembre, semaine 45', () {
    expect(DemoTemps.dateLibelle, 'mer. 4 nov.');
    expect(DemoTemps.jourPlanning, 2);
    expect(DemoTemps.semaineCourante, 45);
    expect(DemoTemps.semaineLibelle, '2 – 6 novembre');
    expect(DemoTemps.maintenantCourt, '4 nov. 14:23');
    expect(semaineInfo(0).dates, [2, 3, 4, 5, 6]);
    expect(semaineInfo(1).num, 46);
    expect(ageDepuisTexte('3 nov. 10:00'), 1);
    expect(ageDepuisTexte('26 oct.'), 9);
  });

  test('connecté un vendredi 13 novembre : planning sur la semaine 46', () {
    aujourdhui(DateTime(2026, 11, 13, 15, 42));
    expect(DemoTemps.dateLibelle, 'ven. 13 nov.');
    expect(DemoTemps.jourPlanning, 4);
    expect(DemoTemps.semaineCourante, 46);
    expect(DemoTemps.semaineLibelle, '9 – 13 novembre');
    expect(DemoTemps.maintenantCourt, '13 nov. 15:42');
    expect(DemoTemps.horodatageMaintenant(), '13/11/2026 15h42');
    final s = semaineInfo(0);
    expect(s.dates, [9, 10, 11, 12, 13]);
    expect(s.num, 46);
    expect(semaineInfo(1).libelle, '16 – 20 nov.');
    expect(ageDepuisTexte('3 nov. 10:00'), 10);
    expect(joursDepuisTimeline('auj.'), isNull);
  });

  test('libellés du planning : lundi, lundi suivant, jours, livraison', () {
    expect(DemoTemps.lundiLibelle, 'lun. 2 nov.');
    expect(DemoTemps.lundiSuivantLibelle, 'lun. 9 nov.');
    expect(DemoTemps.livraisonPrevue, 'ven. 6 nov.');
    aujourdhui(DateTime(2026, 11, 16, 9));
    expect(DemoTemps.lundiLibelle, 'lun. 16 nov.');
    expect(DemoTemps.lundiSuivantLibelle, 'lun. 23 nov.');
    expect(DemoTemps.jourDeLaSemaine(4), 'ven. 20 nov.');
    expect(semaineInfo(0).dates, [16, 17, 18, 19, 20]);
    expect(DemoTemps.livraisonPrevue, 'mer. 18 nov.');
    aujourdhui(DateTime(2026, 11, 19));
    expect(DemoTemps.livraisonPrevue, 'lun. 23 nov.');
  });

  test('week-end : le planning reste sur le vendredi', () {
    aujourdhui(DateTime(2026, 11, 15));
    expect(DemoTemps.jourPlanning, 4);
    expect(DemoTemps.semaineCourante, 46);
  });

  test('passage d\'année : semaine 53 de 2026, puis semaine 1', () {
    aujourdhui(DateTime(2026, 12, 30));
    expect(DemoTemps.semaineCourante, 53);
    expect(DemoTemps.semaineLibelle, '28 décembre – 1 janvier');
    expect(semaineInfo(1).num, 1);
  });

  test(
    'une date de décembre vue en janvier est celle de l\'année précédente',
    () {
      aujourdhui(DateTime(2027, 1, 5));
      expect(ageDepuisTexte('30 déc.'), 6);
    },
  );
}
