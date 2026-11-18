import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/data/referentiels_visite.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/visites/data/visites_data.dart';
import 'package:crm_app/features/visites/logic/visites_logique.dart';
import 'package:crm_app/features/visites/state/filtres_visites.dart';
import 'package:flutter_test/flutter_test.dart';

Visite brouillon(Map<EtapeDph, String> chrono) => Visite(
  id: 'v1',
  num: 1,
  magasinId: 'm1',
  par: 'Julien M.',
  etat: EtatVisite.brouillon,
  date: '4 nov. 14:23',
  age: 0,
  chrono: chrono,
  photos: const {},
);

void main() {
  testsCodeColis();
  group('données du lot (KITS, KIT_PRODUITS, portées)', () {
    test('quatre kits, dans l’ordre de la maquette', () {
      expect(kitsDemo.map((k) => k.code), [
        'COSMIA-01',
        'KIT91265',
        'KIT91267',
        '900024',
      ]);
      expect(kitsDemo.map((k) => k.refs), [5, 5, 5, 6]);
      expect(kitsDemo.first.nom, 'COSMIA ZIPPED PLANE KIT');
      expect(kitsDemo.first.marque, 'Cosmia');
      expect(kitsDemo[1].marque, '');
    });

    test('composition : 5, 5, 5 et 4 produits', () {
      expect(compositionKitsDemo.keys, [
        'COSMIA-01',
        'KIT91265',
        'KIT91267',
        '900024',
      ]);
      expect(compositionKitsDemo.values.map((l) => l.length), [5, 5, 5, 4]);
      expect(compositionKitsDemo['KIT91265']!.first.qte, 12);
      expect(compositionKitsDemo['900024']!.map((c) => c.qte).toSet(), {3});
    });

    test('kitDe retombe sur un kit sans marque nommé par son code', () {
      expect(kitDe('900024').nom, 'Kit racines brun');
      final k = kitDe('ZZZ');
      expect((k.code, k.nom, k.marque, k.refs), ('ZZZ', 'ZZZ', '', 0));
    });

    test('portées', () {
      expect(porteeVisites[Role.promoteur], 'sur vos clients');
      expect(porteeVisites[Role.cs], 'de votre secteur');
      expect(porteeVisites[Role.dir], 'de votre région');
    });

    test(
      'les produits des kits sont ceux du catalogue (sauf trois lignes)',
      () {
        final codes = produitsCatalogue.map((p) => p.code).toSet();
        final inconnus = [
          for (final l in compositionKitsDemo.values)
            for (final c in l)
              if (!codes.contains(c.code)) c.code,
        ];
        expect(inconnus, ['900025', '900019', '900025']);
      },
    );
  });

  group('horloge de la démo (horloge l.1251)', () {
    test('chaque horodatage avance de 4, 5, 4, 5… minutes', () {
      final attendu = [
        '04/11/2026 14h27',
        '04/11/2026 14h32',
        '04/11/2026 14h36',
        '04/11/2026 14h41',
        '04/11/2026 14h45',
        '04/11/2026 14h50',
        '04/11/2026 14h54',
        '04/11/2026 14h59',
        '04/11/2026 15h03',
      ];
      final chrono = <EtapeDph, String>{EtapeDph.debut: '04/11/2026 14h23'};
      for (var i = 0; i < 8; i++) {
        final stamp = prochainHorodatage(brouillon(chrono));
        expect(stamp, attendu[i], reason: 'horodatage ${i + 1}');
        chrono[EtapeDph.values[i + 1]] = stamp;
      }
      // le neuvième est celui de la validation de la visite (heure de réception)
      expect(prochainHorodatage(brouillon(chrono)), attendu[8]);
    });
  });

  group('parcours de visite', () {
    test('huit étapes, sans le début, dans l’ordre', () {
      expect(EtapeDph.values, hasLength(9));
      expect(EtapeDph.parcours, hasLength(8));
      expect(EtapeDph.parcours, isNot(contains(EtapeDph.debut)));
      expect(EtapeDph.parcours.map((e) => e.cle), [
        'arrivee',
        'rayonArrivee',
        'colis',
        'dn',
        'commande',
        'questionnaire',
        'op',
        'rayonFin',
      ]);
      expect(EtapeDph.colis.libelle, 'Commande à mettre en rayon');
      expect(EtapeDph.commande.libelle, 'Commande liée à la visite');
      expect(EtapeDph.op.libelle, 'Pointage OP');
      expect({for (final e in EtapeDph.values) if (e.estPhoto) e}, {
        EtapeDph.arrivee,
        EtapeDph.rayonArrivee,
        EtapeDph.rayonFin,
      });
    });
  });

  group('erreurEtape : ce que « Suivant » exige', () {
    const obligatoire = QuestionFin(
      id: 'q1',
      libelle: 'Rayon propre ?',
      type: TypeQuestionFin.caseACocher,
      obligatoire: true,
    );
    const facultative = QuestionFin(
      id: 'q2',
      libelle: 'Remarque',
      type: TypeQuestionFin.texte,
      obligatoire: false,
    );

    test('photo d’arrivée et photo du rayon obligatoires', () {
      final v = brouillon({EtapeDph.debut: 'x'});
      expect(
        erreurEtape(v, EtapeDph.arrivee),
        "Prenez la photo d'arrivée sur site.",
      );
      expect(erreurEtape(v, EtapeDph.rayonArrivee), 'Prenez la photo du rayon.');
      final avecPhotos = v.copyWith(
        photos: {EtapeDph.arrivee: 1, EtapeDph.rayonArrivee: 2},
      );
      expect(erreurEtape(avecPhotos, EtapeDph.arrivee), isNull);
      expect(erreurEtape(avecPhotos, EtapeDph.rayonArrivee), isNull);
      // une photo supprimée (compteur à 0) ne compte plus
      final retiree = v.copyWith(photos: {EtapeDph.arrivee: 0});
      expect(erreurEtape(retiree, EtapeDph.arrivee), isNotNull);
    });

    test('la photo du rayon de fin n’est pas exigée', () {
      expect(erreurEtape(brouillon({}), EtapeDph.rayonFin), isNull);
    });

    test('il faut répondre à « commande à mettre en rayon », oui ou non', () {
      final v = brouillon({});
      const message = "Indiquez s'il y a une commande à mettre en rayon.";
      expect(erreurEtape(v, EtapeDph.colis), message);
      expect(erreurEtape(v.copyWith(commandeEnRayon: false), EtapeDph.colis), isNull);
      // « oui » sans colis saisi est accepté
      expect(erreurEtape(v.copyWith(commandeEnRayon: true), EtapeDph.colis), isNull);
    });

    test('commande liée ou raison d’absence, seulement quand le CRM en propose', () {
      final v = brouillon({});
      const message =
          "Prenez la commande, ou choisissez la raison de l'absence de commande.";
      expect(erreurEtape(v, EtapeDph.commande), isNull);
      expect(
        erreurEtape(v, EtapeDph.commande, raisonsDisponibles: true),
        message,
      );
      final avecRaison = v.copyWith(
        raisonAbsenceId: 'r1',
        raisonAbsence: 'Stock suffisant',
      );
      expect(
        erreurEtape(avecRaison, EtapeDph.commande, raisonsDisponibles: true),
        isNull,
      );
      final avecCommande = v.copyWith(
        cmd: const CommandeLiee(id: '1', ht: '10,00 €', liv: '06/11/2026'),
      );
      expect(
        erreurEtape(avecCommande, EtapeDph.commande, raisonsDisponibles: true),
        isNull,
      );
    });

    test('questions obligatoires du questionnaire', () {
      final v = brouillon({});
      const message = 'Répondez aux questions obligatoires.';
      expect(erreurEtape(v, EtapeDph.questionnaire), isNull);
      expect(
        erreurEtape(v, EtapeDph.questionnaire, questions: [facultative]),
        isNull,
      );
      expect(
        erreurEtape(v, EtapeDph.questionnaire, questions: [obligatoire, facultative]),
        message,
      );
      // une réponse vide ne compte pas, « false » est une vraie réponse
      expect(
        erreurEtape(
          v.copyWith(reponses: {'q1': ''}),
          EtapeDph.questionnaire,
          questions: [obligatoire],
        ),
        message,
      );
      expect(
        erreurEtape(
          v.copyWith(reponses: {'q1': 'false'}),
          EtapeDph.questionnaire,
          questions: [obligatoire, facultative],
        ),
        isNull,
      );
    });

    test('le début, le DN et le pointage OP n’ont pas d’exigence', () {
      final v = brouillon({});
      for (final e in [EtapeDph.debut, EtapeDph.dn, EtapeDph.op]) {
        expect(erreurEtape(v, e), isNull, reason: e.cle);
      }
    });
  });

  group('manquants : toutes les étapes du parcours', () {
    test('un brouillon neuf doit prendre les photos et répondre pour le rayon', () {
      final m = manquants(brouillon({EtapeDph.debut: 'x'}));
      expect(m, [
        "Prenez la photo d'arrivée sur site.",
        'Prenez la photo du rayon.',
        "Indiquez s'il y a une commande à mettre en rayon.",
      ]);
    });

    test('un brouillon complet n’a plus rien à faire', () {
      final v = brouillon({
        for (final e in EtapeDph.values) e: 'x',
      }).copyWith(
        photos: {EtapeDph.arrivee: 1, EtapeDph.rayonArrivee: 1},
        commandeEnRayon: false,
      );
      expect(manquants(v), isEmpty);
    });

    test('les exigences du CRM s’ajoutent dans l’ordre du parcours', () {
      const q = QuestionFin(
        id: 'q1',
        libelle: 'Rayon propre ?',
        type: TypeQuestionFin.caseACocher,
        obligatoire: true,
      );
      final m = manquants(
        brouillon({}),
        questions: const [q],
        raisonsDisponibles: true,
      );
      expect(m, [
        "Prenez la photo d'arrivée sur site.",
        'Prenez la photo du rayon.',
        "Indiquez s'il y a une commande à mettre en rayon.",
        "Prenez la commande, ou choisissez la raison de l'absence de commande.",
        'Répondez aux questions obligatoires.',
      ]);
    });
  });

  group('lecture des saisies', () {
    test('lireDecimal reprend parseFloat avec la virgule décimale', () {
      expect(lireDecimal('1,5'), 1.5);
      expect(lireDecimal('2'), 2);
      expect(lireDecimal(' 3.25 m'), 3.25);
      expect(lireDecimal('.5'), 0.5);
      expect(lireDecimal('abc'), isNull);
      expect(lireDecimal(''), isNull);
      expect(lireDecimal('-1'), -1);
    });

    test('lireEntierKm ignore tout sauf les chiffres', () {
      expect(lireEntierKm('48 215 km'), 48215);
      expect(lireEntierKm('12,5'), 125);
      expect(lireEntierKm('abc'), isNull);
      expect(lireEntierKm(''), isNull);
    });

    test('nombreFr écrit comme String(n) avec une virgule', () {
      expect(nombreFr(3), '3');
      expect(nombreFr(3.0), '3');
      expect(nombreFr(1.5), '1,5');
      expect(nombreFr(3.5), '3,5');
    });

    test('milliersEspaces et pluriel', () {
      expect(milliersEspaces(48215), '48 215');
      expect(milliersEspaces(999), '999');
      expect(sPluriel(0), '');
      expect(sPluriel(1), '');
      expect(sPluriel(2), 's');
    });
  });

  group('visitesFiltrees (visitesListe l.1172)', () {
    int nb(Role role, FiltresVisites f) =>
        visitesFiltrees(CrmEtat.initial(role), f).length;
    const toutes = FiltresVisites(portee: PorteeVisites.toutes);

    test('mes visites, toutes les visites', () {
      expect(nb(Role.promoteur, const FiltresVisites()), 4);
      expect(nb(Role.promoteur, toutes), 5);
      expect(nb(Role.cs, const FiltresVisites()), 2);
      expect(nb(Role.cs, toutes), 8);
      expect(nb(Role.dir, const FiltresVisites()), 2);
      expect(nb(Role.dir, toutes), 12);
    });

    test('ordre : les visites du profil d’abord', () {
      final l = visitesFiltrees(CrmEtat.initial(Role.dir), toutes);
      expect(l.take(2).map((v) => v.id), ['d00', 'd0']);
      expect(l.skip(2).first.id, 'x0');
      expect(l.take(2).every((v) => v.propre && v.par == 'Cindy R.'), isTrue);
      expect(l.skip(2).every((v) => !v.propre), isTrue);
    });

    test('état, période et recherche', () {
      expect(nb(Role.dir, toutes.avecEtat(EtatVisite.terminee)), 1);
      expect(nb(Role.dir, toutes.avecEtat(EtatVisite.brouillon)), 0);
      expect(nb(Role.dir, toutes.avecPeriode(PeriodeVisites.jour)), 2);
      expect(nb(Role.dir, toutes.avecPeriode(PeriodeVisites.semaine)), 9);
      expect(nb(Role.dir, toutes.avecRecherche('LÉA')), 2);
      expect(nb(Role.dir, toutes.avecRecherche('rouen')), 2);
      expect(nb(Role.dir, toutes.avecRecherche('amine versailles')), 0);
    });

    test('compteur de filtres actifs', () {
      expect(const FiltresVisites().nbActifs, 0);
      expect(const FiltresVisites(q: 'abc').nbActifs, 0);
      expect(
        const FiltresVisites(
          portee: PorteeVisites.toutes,
          etat: EtatVisite.envoyee,
          periode: PeriodeVisites.semaine,
        ).nbActifs,
        3,
      );
    });

    test('tournée restante : une visite du 4 nov. par client suffit', () {
      final e = CrmEtat.initial(Role.promoteur);
      expect(tourneeRestante(e), isTrue);
      final tout = e.copyWith(
        visites: [
          for (final t in e.tournee)
            visiteDemo(
              id: 'z${t.magasinId}',
              num: 1,
              magasinId: t.magasinId,
              par: 'Julien M.',
              jour: 4,
              mois: 'nov',
              heure: 9,
              minute: 0,
            ),
        ],
      );
      expect(tourneeRestante(tout), isFalse);
    });
  });
}

void testsCodeColis() {
  group('codeColisValide', () {
    test('enlève les espaces autour du code', () {
      expect(codeColisValide('  0123456789 '), '0123456789');
    });
    test('refuse vide, nul et trop long', () {
      expect(codeColisValide(null), isNull);
      expect(codeColisValide('   '), isNull);
      expect(codeColisValide('x' * 65), isNull);
      expect(codeColisValide('x' * 64), 'x' * 64);
    });
  });
}
