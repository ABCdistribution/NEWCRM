import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/planning/data/rapports_demo.dart';
import 'package:crm_app/features/planning/logic/logique_planning.dart';
import 'package:crm_app/features/planning/state/planning_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// État et calculs du lot planning : prévision enregistrée, phases, écarts, rapports (maquette l.487-492, l.953-1008).
void main() {
  group('rapports de la démo (S.rapports)', () {
    test('quatre semaines, de la 44 à la 41', () {
      expect(rapportsDemo.map((r) => r.numero), [44, 43, 42, 41]);
      expect(rapportsDemo.map((r) => r.periode), [
        '26 – 30 octobre',
        '19 – 23 octobre',
        '12 – 16 octobre',
        '5 – 9 octobre',
      ]);
      expect(rapportsDemo.map((r) => r.visites), [14, 12, 15, 11]);
      expect(rapportsDemo.map((r) => r.pct), [93, 86, 100, 85]);
      expect(rapportsDemo.map((r) => r.rdv), [4, 2, 3, 1]);
      expect(rapportsDemo.map((r) => r.prevues), [15, 14, 15, 13]);
      expect(rapportsDemo.every((r) => r.auto), isTrue);
      expect(rapportsDemo.map((r) => r.ecarts.length), [2, 3, 0, 2]);
      expect(
        rapportsDemo.first.pied,
        'Validé automatiquement le lun. 2 nov. à 04:00',
      );
      expect(
        rapportsDemo.last.pied,
        'Validé automatiquement le lun. 12 oct. à 04:00',
      );
    });

    test('genres et textes des écarts', () {
      final e44 = rapportsDemo[0].ecarts;
      expect(e44.map((e) => e.genre), [GenreEcart.ajoute, GenreEcart.retire]);
      expect(e44.map((e) => e.titre), ['Auchan – Rouen', 'Monoprix – Caen']);
      expect(e44.map((e) => e.detail), ['visite non prévue', 'prévu mardi']);
      final e43 = rapportsDemo[1].ecarts;
      expect(e43.map((e) => e.genre), [
        GenreEcart.retire,
        GenreEcart.retire,
        GenreEcart.deplace,
      ]);
      expect(e43.last.detail, 'prévu mardi, réalisé jeudi');
      final e41 = rapportsDemo[3].ecarts;
      expect(e41.map((e) => e.genre), [GenreEcart.non, GenreEcart.non]);
    });
  });

  group('prévision et phase', () {
    test('état initial : rapport en cours et prévision de démo', () {
      final cs = conteneurPour(Role.cs).read(planningProvider);
      expect(cs.phase, PhasePlanning.rapport);
      expect(cs.prevision!.map((e) => e.id), ['e1', 'e4', 'e6', 'e8']);
      expect(cs.ecartsOuverts, isFalse);
      expect(cs.verrouillee, isFalse);

      final dir = conteneurPour(Role.dir).read(planningProvider);
      expect(dir.prevision!.length, 8);
      expect(dir.prevision!.last.id, 'e9');

      final promoteur = conteneurPour(Role.promoteur).read(planningProvider);
      expect(promoteur.prevision!.map((e) => e.id), ['e1', 'e4']);
    });

    test('changer de profil réinitialise les réglages', () {
      final c = conteneurPour(Role.cs);
      c.read(planningProvider.notifier).basculerEcarts();
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
      expect(c.read(planningProvider).verrouillee, isTrue);
      c.read(roleProvider.notifier).choisir(Role.dir);
      final etat = c.read(planningProvider);
      expect(etat.phase, PhasePlanning.rapport);
      expect(etat.ecartsOuverts, isFalse);
      expect(etat.prevision!.length, 8);
    });

    test('phase « prévision » : la prévision est à saisir', () {
      final c = conteneurPour(Role.cs);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.prevision);
      final etat = c.read(planningProvider);
      expect(etat.phase, PhasePlanning.prevision);
      expect(etat.prevision, isNull);
      expect(etat.previsionVue, isTrue);
      // Repasser en « rapport » ne rend pas la prévision de démo : une semaine à prévoir a été ouverte.
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.rapport);
      expect(c.read(planningProvider).prevision, isNull);
    });

    test('phase « validé » verrouille la semaine', () {
      final c = conteneurPour(Role.cs);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
      expect(c.read(planningProvider).verrouillee, isTrue);
      expect(c.read(planningProvider).prevision, isNotNull);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.rapport);
      expect(c.read(planningProvider).verrouillee, isFalse);
    });

    test('enregistrer la prévision copie le planning, lignes non faites', () {
      final c = conteneurPour(Role.cs);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.prevision);
      final etapes = c.read(crmProvider).etapes;
      c.read(planningProvider.notifier).enregistrerPrevision(etapes);
      final etat = c.read(planningProvider);
      expect(etat.prevision!.map((e) => e.id), etapes.map((e) => e.id));
      expect(etat.prevision!.every((e) => !e.fait), isTrue);
      expect(etat.ecartsOuverts, isTrue);
      expect(previsionModifiee(etat.prevision, etapes), isFalse);
    });

    test('basculer le détail des écarts', () {
      final c = conteneurPour(Role.cs);
      c.read(planningProvider.notifier).basculerEcarts();
      expect(c.read(planningProvider).ecartsOuverts, isTrue);
      c.read(planningProvider.notifier).basculerEcarts();
      expect(c.read(planningProvider).ecartsOuverts, isFalse);
    });
  });

  group('écarts de la semaine', () {
    test('chef de secteur : 25 % de 4 lignes prévues', () {
      final c = conteneurPour(Role.cs);
      final e = c.read(ecartsSemaineProvider)!;
      expect(e.prevues, 4);
      expect(e.realisees, 1);
      expect(e.pct, 25);
      expect([e.ajoutees, e.retirees, e.deplacees, e.non], [1, 0, 1, 0]);
    });

    test('les écarts suivent le planning du profil', () {
      final c = conteneurPour(Role.cs);
      c
          .read(crmProvider.notifier)
          .majEtape('e6', (e) => e.copyWith(fait: true));
      expect(c.read(ecartsSemaineProvider)!.pct, 50);
      c.read(crmProvider.notifier).supprimerEtape('e8');
      final e = c.read(ecartsSemaineProvider)!;
      expect(e.retirees, 1);
      expect(e.pct, 50);
    });

    test('semaine validée : les lignes non faites sont « non réalisées »', () {
      final c = conteneurPour(Role.cs);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
      final e = c.read(ecartsSemaineProvider)!;
      expect(e.non, 2);
    });

    test('sans prévision : aucune comparaison', () {
      final c = conteneurPour(Role.cs);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.prevision);
      expect(c.read(ecartsSemaineProvider), isNull);
    });

    test('rapports précédents : la semaine 45 s’ajoute une fois validée', () {
      final c = conteneurPour(Role.cs);
      expect(c.read(rapportsPrecedentsProvider).map((r) => r.numero), [
        44,
        43,
        42,
        41,
      ]);
      c.read(planningProvider.notifier).choisirPhase(PhasePlanning.valide);
      final l = c.read(rapportsPrecedentsProvider);
      expect(l.map((r) => r.numero), [45, 44, 43, 42, 41]);
      final r = l.first;
      expect(r.periode, '2 – 6 novembre');
      expect(r.visites, 4);
      expect(r.rdv, 4);
      expect(r.prevues, 4);
      expect(r.pct, 25);
      expect(r.pied, 'Validé automatiquement le lun. 9 nov. à 04:00');
      expect(
        resumeEcarts(r.ecarts.map((e) => e.genre)),
        '+1 ajoutée · 1 déplacée · 2 non réalisées',
      );
    });
  });

  group('calculs purs', () {
    const base = EtapePlanning(
      id: 'a',
      jour: 1,
      heure: '10:00',
      cible: CiblePlanning.client,
      titre: 'Client',
    );

    test(
      'signature : id, jour, heure, titre, visite, accompagnement, rdv, soirée',
      () {
        expect(signatureLigne(base), 'a|1|10:00|Client|true|false|false|false');
      },
    );

    test('la prévision est « sale » quand une ligne change', () {
      final prevision = [base];
      expect(previsionModifiee(prevision, [base]), isFalse);
      expect(
        previsionModifiee(prevision, [base.copyWith(heure: '11:00')]),
        isTrue,
      );
      expect(previsionModifiee(prevision, [base.copyWith(rdv: true)]), isTrue);
      // Une ligne faite ou une note modifiée ne changent pas la signature.
      expect(
        previsionModifiee(prevision, [base.copyWith(fait: true, note: 'x')]),
        isFalse,
      );
      expect(previsionModifiee(prevision, [base, base.copyWith()]), isTrue);
      expect(previsionModifiee(null, [base]), isFalse);
    });

    test('détail d’une carte', () {
      expect(detailLigne(base, lectureSeule: false), 'Visite simple');
      expect(detailLigne(base, lectureSeule: true), '');
      expect(
        detailLigne(
          base.copyWith(
            acc: true,
            rdv: true,
            appel: true,
            remp: true,
            soiree: true,
            soireeLieu: 'Lyon',
            note: 'Négo',
          ),
          lectureSeule: false,
        ),
        'Accompagnement · RDV · Appel téléphonique · Visite de remplacement · Soirée étape (Lyon) · Négo',
      );
      expect(
        detailLigne(
          const EtapePlanning(
            id: 'b',
            jour: 0,
            heure: '',
            cible: CiblePlanning.adm,
            titre: 'Administratif',
            visite: false,
            note: 'Compte rendu',
          ),
          lectureSeule: false,
        ),
        'Compte rendu',
      );
    });

    test('nombre de lignes', () {
      expect(nbLignes(0), '0 ligne');
      expect(nbLignes(1), '1 ligne');
      expect(nbLignes(2), '2 lignes');
    });

    test('clients proposés pour le planning d’un promoteur', () {
      final dir = conteneurPour(Role.dir).read(crmProvider).magasins;
      expect(clientsDe('Léa P.', dir).map((m) => m.id), ['m2', 'm3', 'm5']);
      expect(clientsDe('Julien M.', dir).map((m) => m.id), [
        'm1',
        'm8',
        'm10',
        'm4',
      ]);
      // Moins de deux clients correspondants : tous les clients du profil.
      final cs = conteneurPour(Role.cs).read(crmProvider).magasins;
      expect(clientsDe('Léa P.', cs).length, cs.length);
    });
  });
}
