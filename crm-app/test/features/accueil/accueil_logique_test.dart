import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/accueil/accueil_logique.dart';
import 'package:flutter_test/flutter_test.dart';

/// Calculs de l'accueil : `etatTournee` l.1114-1118, `salesAccueil` l.1138-1156, `blocProspectsCS` l.665-670,
/// `prochaineAction` l.716-719, `det` de `pageAccueil` l.679.
void main() {
  Visite visite(
    String id,
    String magasinId, {
    EtatVisite etat = EtatVisite.envoyee,
    String date = '4 nov. 15:00',
  }) => Visite(
    id: id,
    num: 1,
    magasinId: magasinId,
    par: 'Julien M.',
    etat: etat,
    date: date,
    age: 0,
    chrono: const {},
    photos: const {},
  );

  group('etatTournee', () {
    test('sans visite aujourd’hui : à faire', () {
      expect(etatTournee(const [], 'm1'), EtatTournee.aFaire);
      // Une visite d'un autre jour ne compte pas, ni celle d'un autre client.
      expect(
        etatTournee([visite('a', 'm1', date: '3 nov. 10:00')], 'm1'),
        EtatTournee.aFaire,
      );
      expect(etatTournee([visite('a', 'm2')], 'm1'), EtatTournee.aFaire);
    });

    test(
      'un brouillon du jour est en cours, une visite finie est réalisée',
      () {
        expect(
          etatTournee([visite('a', 'm1', etat: EtatVisite.brouillon)], 'm1'),
          EtatTournee.enCours,
        );
        expect(etatTournee([visite('a', 'm1')], 'm1'), EtatTournee.realisee);
        expect(
          etatTournee([visite('a', 'm1', etat: EtatVisite.terminee)], 'm1'),
          EtatTournee.realisee,
        );
      },
    );

    test(
      '« 14 nov. » n’est pas aujourd’hui (le test porte sur « 4 nov. »)',
      () {
        expect(
          etatTournee([visite('a', 'm1', date: '14 nov. 10:00')], 'm1'),
          EtatTournee.aFaire,
        );
      },
    );

    test('la visite la plus récente du client l’emporte', () {
      expect(
        etatTournee([
          visite('b', 'm1', etat: EtatVisite.brouillon),
          visite('a', 'm1'),
        ], 'm1'),
        EtatTournee.enCours,
      );
    });
  });

  group('lignesTournee (promoteur)', () {
    final etat = CrmEtat.initial(Role.promoteur);

    test('m4 est faite, m1 est la prochaine à démarrer', () {
      final l = lignesTournee(etat);
      expect(l.map((x) => x.magasin.id), ['m4', 'm1', 'm8']);
      expect(l.map((x) => x.etat), [
        EtatTournee.realisee,
        EtatTournee.aFaire,
        EtatTournee.aFaire,
      ]);
      expect(l.map((x) => x.demarrer), [false, true, false]);
      expect(l.map((x) => x.visite.type), [
        'Planifiée',
        'Planifiée',
        'Passage opportunité',
      ]);
    });

    test('une visite en cours : « Reprendre », plus aucun « Démarrer »', () {
      final avec = etat.copyWith(
        visites: [
          visite('b', 'm8', etat: EtatVisite.brouillon),
          ...etat.visites,
        ],
      );
      final l = lignesTournee(avec);
      expect(l.map((x) => x.etat), [
        EtatTournee.realisee,
        EtatTournee.aFaire,
        EtatTournee.enCours,
      ]);
      expect(l.any((x) => x.demarrer), isFalse);
    });

    test('toutes faites : personne à démarrer', () {
      final avec = etat.copyWith(
        visites: [visite('b', 'm1'), visite('c', 'm8'), ...etat.visites],
      );
      final l = lignesTournee(avec);
      expect(l.every((x) => x.etat == EtatTournee.realisee), isTrue);
      expect(l.any((x) => x.demarrer), isFalse);
    });

    test('sans tournée : aucune ligne', () {
      expect(lignesTournee(etat.copyWith(tournee: const [])), isEmpty);
    });
  });

  group('livraisonsEnCours', () {
    test('promoteur : CDE-2039 (m8) puis CDE-2027 (m1), pas les livrées', () {
      final l = livraisonsEnCours(CrmEtat.initial(Role.promoteur));
      expect(l.map((c) => c.id), ['CDE-2039', 'CDE-2027']);
      expect(l.every((c) => c.statut == StatutLivraison.pasLivree), isTrue);
    });

    test('directeur : toutes les commandes pas livrées de la région', () {
      final l = livraisonsEnCours(CrmEtat.initial(Role.dir));
      expect(l.map((c) => c.id), [
        'CDE-2041',
        'CDE-2039',
        'CDE-2027',
        'CDE-2033',
        'CDE-2036',
      ]);
    });
  });

  group('detailEtape', () {
    EtapePlanning etape({
      CiblePlanning cible = CiblePlanning.client,
      String heure = '09:00',
      bool rdv = false,
      String note = '',
    }) => EtapePlanning(
      id: 'x',
      jour: 2,
      heure: heure,
      cible: cible,
      titre: 'T',
      rdv: rdv,
      note: note,
    );

    test('heure, nature, RDV et note séparés par « · »', () {
      expect(detailEtape(etape()), '09:00 · Client');
      expect(
        detailEtape(etape(cible: CiblePlanning.prospect, rdv: true)),
        '09:00 · Prospect · RDV',
      );
      expect(
        detailEtape(
          etape(cible: CiblePlanning.adm, heure: '16:00', note: 'Compte rendu'),
        ),
        '16:00 · ADM · Compte rendu',
      );
      expect(
        detailEtape(
          etape(cible: CiblePlanning.libre, rdv: true, note: 'Salon'),
        ),
        '09:00 · Libre · RDV · Salon',
      );
    });

    test('sans heure, les parties vides sont omises', () {
      expect(detailEtape(etape(heure: '')), 'Client');
    });
  });

  group('prospectsASuivre', () {
    final prospects = CrmEtat.initial(Role.cs).prospects;

    test('négo d’abord, puis potentiel × probabilité, trois au plus', () {
      expect(prospectsASuivre(prospects).map((p) => p.id), [
        'p1', // 180 × 60
        'p17', // 160 × 60
        'p14', // 130 × 55
      ]);
    });

    test('référencés et perdus sont exclus', () {
      final base = prospects.firstWhere((p) => p.id == 'p1');
      final liste = [
        base.copyWith(statut: StatutProspect.gagne),
        ...prospects.where((p) => p.id != 'p1'),
      ];
      expect(prospectsASuivre(liste).map((p) => p.id), ['p17', 'p14', 'p5']);
      final perdu = [
        base.copyWith(statut: StatutProspect.perdu),
        ...prospects.where((p) => p.id != 'p1'),
      ];
      expect(prospectsASuivre(perdu).map((p) => p.id), ['p17', 'p14', 'p5']);
    });

    test('sans prospect en négo, le potentiel × probabilité décide', () {
      final sansNego = prospects
          .where((p) => p.groupe != GroupeProspect.enNego)
          .toList();
      expect(prospectsASuivre(sansNego).map((p) => p.id), [
        'p18', // 80 × 40
        'p6', // 70 × 40
        'p9', // 95 × 20
      ]);
    });

    test('moins de trois prospects : tous, aucun sans prospect', () {
      expect(prospectsASuivre(prospects.take(2).toList()), hasLength(2));
      expect(prospectsASuivre(const []), isEmpty);
    });

    test('à score égal, l’ordre d’origine est conservé', () {
      Prospect p(String id) => Prospect(
        id: id,
        nom: id,
        raison: id,
        classe: 'A',
        cp: '',
        statut: StatutProspect.visite,
        pot: 100,
        proba: 40,
        timeline: const [],
      );
      expect(
        prospectsASuivre([p('a'), p('b'), p('c'), p('d')]).map((x) => x.id),
        ['a', 'b', 'c'],
      );
    });
  });

  group('prochaineAction', () {
    final etat = CrmEtat.initial(Role.cs);
    Prospect p(String id) => etat.prospects.firstWhere((x) => x.id == id);

    test('RDV prévu : jour abrégé et heure', () {
      expect(prochaineAction(p('p1'), etat.etapes), '📅 RDV · Jeu 10:00');
      expect(prochaineAction(p('p2'), etat.etapes), '📅 RDV · Mer 11:30');
    });

    test('étape sans RDV : « Visite »', () {
      final etapes = [
        const EtapePlanning(
          id: 'v',
          jour: 4,
          heure: '14:00',
          cible: CiblePlanning.prospect,
          ref: 'p17',
          titre: 'E.Leclerc – Mantes-la-Jolie',
        ),
      ];
      expect(prochaineAction(p('p17'), etapes), '📅 Visite · Ven 14:00');
    });

    test('aucune étape, ou étape déjà faite : rien', () {
      expect(prochaineAction(p('p17'), etat.etapes), isNull);
      final faite = [
        for (final e in etat.etapes) e.id == 'e8' ? e.copyWith(fait: true) : e,
      ];
      expect(prochaineAction(p('p1'), faite), isNull);
    });

    test('seules les étapes sur un prospect comptent', () {
      final etapes = [
        const EtapePlanning(
          id: 'c',
          jour: 1,
          heure: '10:00',
          cible: CiblePlanning.client,
          ref: 'p1',
          titre: 'Client dont l’id ressemble',
        ),
      ];
      expect(prochaineAction(p('p1'), etapes), isNull);
    });
  });

  test('promoteur : objectif en euros de la démo (4 200 € sur 4 900 €)', () {
    final moi = promoteurParNom(CrmEtat.initial(Role.promoteur).nomProfil)!;
    expect([moi.real, moi.cible], [4200, 4900]);
  });

  group('prochaineVisitePrevue', () {
    final base = CrmEtat.initial(Role.promoteur);
    final m = base.magasins.first;
    EtapePlanning ligne(
      String id,
      int jour, {
      String heure = '',
      int? sem,
      bool fait = false,
      bool visite = true,
    }) => EtapePlanning(
      id: id,
      jour: jour,
      heure: heure,
      cible: CiblePlanning.client,
      ref: m.id,
      titre: m.nom,
      sem: sem,
      fait: fait,
      visite: visite,
    );

    test('la première ligne à faire après aujourd’hui (mercredi en démo)', () {
      final e = base.copyWith(
        etapes: [
          ligne('a', 1),
          ligne('b', 4, heure: '14:00'),
          ligne('c', 3, heure: '10:00'),
          ligne('d', 3, heure: '09:00', fait: true),
        ],
      );
      final p = prochaineVisitePrevue(e)!;
      expect(p.heure, '10:00');
      expect(p.date, 'jeu. 5 nov.');
      expect(p.magasin.id, m.id);
    });

    test('la semaine suivante passe après la semaine courante, rien sinon', () {
      final e = base.copyWith(
        etapes: [ligne('a', 0, sem: 1), ligne('b', 4)],
      );
      expect(prochaineVisitePrevue(e)!.date, 'ven. 6 nov.');
      expect(
        prochaineVisitePrevue(
          base.copyWith(
            etapes: [ligne('a', 2), ligne('b', 4, visite: false)],
          ),
        ),
        isNull,
      );
    });
  });
}
