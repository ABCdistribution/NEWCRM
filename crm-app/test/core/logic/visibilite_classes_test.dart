import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('visibilité par rôle', () {
    test('clients visibles', () {
      List<String> ids(Role r) =>
          magasinsDemo.where((m) => visM(r, m)).map((m) => m.id).toList();
      expect(ids(Role.promoteur), ['m1', 'm8', 'm5', 'm4']);
      expect(ids(Role.cs), ['m1', 'm8', 'm9', 'm10', 'm5', 'm4']);
      expect(ids(Role.dir), hasLength(10));
    });

    test('prospects visibles : aucun pour le promoteur', () {
      int nb(Role r) => prospectsDemo.where((p) => visP(r, p)).length;
      expect(nb(Role.promoteur), 0);
      expect(nb(Role.cs), 12);
      expect(nb(Role.dir), 23);
    });

    test('peutPilot', () {
      expect(peutPilot(Role.promoteur), isFalse);
      expect(peutPilot(Role.cs), isTrue);
      expect(peutPilot(Role.dir), isTrue);
    });

    test('univers du rôle', () {
      expect(Role.promoteur.univers, Univers.sales);
      expect(Role.cs.univers, Univers.pilot);
      expect(Role.dir.univers, Univers.pilot);
    });
  });

  group('classes', () {
    test('seuils de visite', () {
      expect(seuilPourClasse('A++'), 7);
      expect(seuilPourClasse('B'), 21);
      expect(seuilPourClasse('G'), 70);
      expect(seuilPourClasse('?'), 28);
    });

    test('classeValide : A à G en majuscule, sinon vide', () {
      expect(classeValide('b'), 'B');
      expect(classeValide(' G '), 'G');
      expect(classeValide('A++'), 'A++');
      expect(classeValide('A+'), 'A+');
      for (final x in ['—', '', 'H', 'AA', 'Z', null]) {
        expect(classeValide(x), isEmpty);
      }
    });

    test('nomEtClasse : la classe est ajoutée si elle est connue', () {
      expect(
        nomEtClasse('Carrefour – Rouen', 'c'),
        'Carrefour – Rouen · Classe C',
      );
      expect(nomEtClasse('Carrefour – Rouen', '—'), 'Carrefour – Rouen');
      expect(nomEtClasse('Carrefour – Rouen', null), 'Carrefour – Rouen');
    });

    test('classeRang : le meilleur niveau d’abord', () {
      final tri = ['G', 'B', 'A', 'A++', 'C', 'A+']
        ..sort((a, b) => classeRang(a).compareTo(classeRang(b)));
      expect(tri, ['A++', 'A+', 'A', 'B', 'C', 'G']);
    });
  });

  group('objectifs', () {
    test('niveau d’atteinte', () {
      expect(niveauObjectif(90), NiveauObjectif.bon);
      expect(niveauObjectif(89), NiveauObjectif.moyen);
      expect(niveauObjectif(70), NiveauObjectif.moyen);
      expect(niveauObjectif(69), NiveauObjectif.faible);
    });

    test('taux d’atteinte des promoteurs de la maquette', () {
      final n = promoteursParChef['n']!;
      expect(n.map((p) => p.obj), [86, 71, 102]);
      final t = totalObjectif(n);
      expect(t.real, 13100);
      expect(t.cible, 14950);
    });

    test('objectif d’un magasin : stable et déterministe', () {
      final m1 = magasinsDemo.first;
      final o = objectifMagasin(m1);
      expect(o.obj, 5250);
      expect(o.ca, 4570);
      expect(o.ops.map((x) => x.nom), [
        'Remise -20 % gamme soin',
        '2 achetés = 1 offert maquillage',
      ]);
      expect(objectifMagasin(m1).ca, o.ca);
    });
  });

  group('tri', () {
    test('compareFr : ponctuation avant les lettres, accents ignorés', () {
      expect(
        compareFr('Carrefour – Rouen', 'Carrefour Market – Rouen'),
        lessThan(0),
      );
      expect(compareFr('Évreux', 'Evry'), lessThan(0));
      expect(compareFr('abc', 'ABC'), 0);
    });

    test('triStable conserve l’ordre d’origine à égalité', () {
      final l = triStable<(String, int)>([
        ('a', 2),
        ('b', 1),
        ('c', 2),
        ('d', 1),
      ], (x, y) => x.$2.compareTo(y.$2));
      expect(l.map((e) => e.$1), ['b', 'd', 'a', 'c']);
    });
  });

  group('planning', () {
    test('style d’une ligne', () {
      const client = EtapePlanning(
        id: 'x',
        jour: 0,
        heure: '09:00',
        cible: CiblePlanning.client,
        titre: 'T',
      );
      expect(styleEtapePlanning(client).libelle, 'Client');
      expect(styleEtapePlanning(client.copyWith(fait: true)).libelle, 'Fait ✓');
      expect(
        styleEtapePlanning(
          client.copyWith(fait: true),
          masquerFait: true,
        ).libelle,
        'Client',
      );
      expect(
        styleEtapePlanning(client.copyWith(cible: CiblePlanning.adm)).libelle,
        'ADM',
      );
    });

    test('lignes du jour triées par heure', () {
      final l = lignesDuJour(etapesDemo, 2);
      expect(l.map((e) => e.id), ['e5', 'e6', 'e7']);
    });
  });

  group('statuts de prospect', () {
    test('groupes et segments', () {
      expect(StatutProspect.nouveau.groupe, GroupeProspect.aContacter);
      expect(StatutProspect.contacte.groupe, GroupeProspect.aContacter);
      expect(StatutProspect.proposition.groupe, GroupeProspect.enNego);
      expect(StatutProspect.perdu.groupe, isNull);
      expect(StatutProspect.negociation.segments, 4);
      expect(StatutProspect.gagne.segments, 5);
      expect(StatutProspect.depuisCode('VISITE'), StatutProspect.visite);
    });
  });
}
