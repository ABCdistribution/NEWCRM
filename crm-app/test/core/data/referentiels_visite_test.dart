import 'package:crm_app/core/data/referentiels_visite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TypeQuestionFin.depuisCode', () {
    test('codes du CRM, case à cocher par défaut', () {
      expect(TypeQuestionFin.depuisCode('TEXTE'), TypeQuestionFin.texte);
      expect(TypeQuestionFin.depuisCode('NOMBRE'), TypeQuestionFin.nombre);
      expect(TypeQuestionFin.depuisCode('NOTE_1_5'), TypeQuestionFin.note);
      expect(
        TypeQuestionFin.depuisCode('BOOLEEN'),
        TypeQuestionFin.caseACocher,
      );
      expect(TypeQuestionFin.depuisCode(null), TypeQuestionFin.caseACocher);
      expect(TypeQuestionFin.depuisCode(3), TypeQuestionFin.caseACocher);
    });
  });

  group('questionsDepuisJson', () {
    test('lit les questions dans l’ordre de l’API', () {
      final q = questionsDepuisJson([
        {
          'id': 'a',
          'libelle': 'Rayon propre ?',
          'type': 'BOOLEEN',
          'obligatoire': true,
        },
        {'id': 'b', 'libelle': 'Remarque', 'type': 'TEXTE'},
        {'id': 'c', 'libelle': 'Note', 'type': 'NOTE_1_5', 'obligatoire': false},
        {'id': 'd', 'libelle': 'Facings', 'type': 'NOMBRE'},
      ]);
      expect(q.map((x) => x.id), ['a', 'b', 'c', 'd']);
      expect(q.map((x) => x.type), [
        TypeQuestionFin.caseACocher,
        TypeQuestionFin.texte,
        TypeQuestionFin.note,
        TypeQuestionFin.nombre,
      ]);
      expect(q.map((x) => x.obligatoire), [true, false, false, false]);
      expect(q.first.libelle, 'Rayon propre ?');
    });

    test('« obligatoire » n’est vrai que pour true', () {
      final q = questionsDepuisJson([
        {'id': 'a', 'libelle': 'A', 'obligatoire': 'true'},
        {'id': 'b', 'libelle': 'B', 'obligatoire': 1},
      ]);
      expect(q.map((x) => x.obligatoire), [false, false]);
    });

    test('ignore les questions inactives, sans id ou sans libellé', () {
      final q = questionsDepuisJson([
        {'id': 'a', 'libelle': 'Active', 'actif': true},
        {'id': 'b', 'libelle': 'Inactive', 'actif': false},
        {'libelle': 'Sans id'},
        {'id': 'c'},
        {'id': 'd', 'libelle': '   '},
        {'id': '  ', 'libelle': 'Id vide'},
        {'id': 12, 'libelle': 'Id numérique'},
        'pas un objet',
        null,
      ]);
      expect(q.map((x) => x.id), ['a']);
    });

    test('le libellé est nettoyé', () {
      final q = questionsDepuisJson([
        {'id': 'a', 'libelle': '  Rayon propre ?  '},
      ]);
      expect(q.single.libelle, 'Rayon propre ?');
    });

    test('une réponse qui n’est pas une liste donne une liste vide', () {
      expect(questionsDepuisJson(null), isEmpty);
      expect(questionsDepuisJson({'data': []}), isEmpty);
      expect(questionsDepuisJson('x'), isEmpty);
      expect(questionsDepuisJson(const []), isEmpty);
    });
  });

  group('raisonsDepuisJson', () {
    test('lit les raisons actives', () {
      final r = raisonsDepuisJson([
        {'id': 'r1', 'libelle': 'Stock suffisant'},
        {'id': 'r2', 'libelle': ' Gérant absent ', 'actif': true},
        {'id': 'r3', 'libelle': 'Désactivée', 'actif': false},
        {'id': 'r4'},
        {'libelle': 'Sans id'},
        42,
      ]);
      expect(r.map((x) => x.id), ['r1', 'r2']);
      expect(r.map((x) => x.libelle), ['Stock suffisant', 'Gérant absent']);
    });

    test('une réponse qui n’est pas une liste donne une liste vide', () {
      expect(raisonsDepuisJson(null), isEmpty);
      expect(raisonsDepuisJson({'id': 'r1', 'libelle': 'X'}), isEmpty);
    });
  });

  group('promosOpDepuisJson', () {
    test('libellé et article de la promotion', () {
      final p = promosOpDepuisJson([
        {
          'id': 'p1',
          'libelle': '2 pour 1 shampoings',
          'article': {'libelle': 'Shampoing 250 ml'},
        },
      ]);
      expect(p.single.id, 'p1');
      expect(p.single.libelle, '2 pour 1 shampoings');
      expect(p.single.article, 'Shampoing 250 ml');
    });

    test('sans libellé, le nom de l’article sert de libellé', () {
      final p = promosOpDepuisJson([
        {
          'id': 'p1',
          'article': {'libelle': 'Shampoing 250 ml'},
        },
      ]);
      expect(p.single.libelle, 'Shampoing 250 ml');
      expect(p.single.article, 'Shampoing 250 ml');
    });

    test('sans libellé ni article : « Promotion »', () {
      final p = promosOpDepuisJson([
        {'id': 'p1'},
        {'id': 'p2', 'libelle': '  ', 'article': {'libelle': ''}},
        {'id': 'p3', 'article': 'texte'},
      ]);
      expect(p.map((x) => x.libelle), ['Promotion', 'Promotion', 'Promotion']);
      expect(p.map((x) => x.article), ['', '', '']);
    });

    test('ignore les lignes sans id', () {
      final p = promosOpDepuisJson([
        {'libelle': 'Sans id'},
        {'id': ' ', 'libelle': 'Id vide'},
        {'id': 'p1', 'libelle': 'Valide'},
        null,
      ]);
      expect(p.map((x) => x.id), ['p1']);
    });

    test('une réponse qui n’est pas une liste donne une liste vide', () {
      expect(promosOpDepuisJson(null), isEmpty);
      expect(promosOpDepuisJson({'data': []}), isEmpty);
    });
  });
}
