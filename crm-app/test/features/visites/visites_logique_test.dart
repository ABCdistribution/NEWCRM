import 'package:crm_app/core/data/data.dart';
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
  group('données du lot (KITS, KIT_PRODUITS, RAISONS_PEM)', () {
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

    test('raisons PEM et portées', () {
      expect(raisonsPem, [
        'Pas de rayon PEM',
        'Rayon fermé ou en travaux',
        'Autre',
      ]);
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

  group('manquants (l.1255)', () {
    test('un brouillon neuf doit tout faire, PEM comprise', () {
      final m = manquants(brouillon({EtapeDph.debut: 'x'}));
      expect(m.length, 9);
      expect(m.first, "Photos d'arrivée sur site");
      expect(m.last, 'Visite PEM (réalisée, ou raison de son absence)');
    });

    test('PEM non réalisée sans raison manque, avec raison non', () {
      final tout = {for (final e in EtapeDph.values) e: 'x'};
      expect(manquants(brouillon(tout)), [
        'Visite PEM (réalisée, ou raison de son absence)',
      ]);
      final v = brouillon(tout).copyWith(pem: const VisitePem(realisee: false));
      expect(manquants(v), ['Visite PEM (réalisée, ou raison de son absence)']);
      expect(
        manquants(
          v.copyWith(pem: const VisitePem(realisee: false, raison: 'Autre')),
        ),
        isEmpty,
      );
      expect(
        manquants(v.copyWith(pem: const VisitePem(realisee: true))),
        isEmpty,
      );
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

  group('messages d’enregistrement d’une étape', () {
    test('contrôles de la maquette (v-etape-ok)', () {
      final v = brouillon({EtapeDph.debut: 'x'});
      expect(
        erreurEnregistrement(v, EtapeDph.dn),
        'Sélectionnez au moins un kit pour la vérification DN.',
      );
      expect(
        erreurEnregistrement(v, EtapeDph.concurrence),
        'Ajoutez au moins une marque concurrente, ou cochez « Aucune marque concurrente ».',
      );
      expect(
        erreurEnregistrement(v, EtapeDph.bilan),
        'Validez les objectifs pour enregistrer le bilan.',
      );
      expect(
        erreurEnregistrement(v, EtapeDph.promos),
        'Indiquez si les promotions sont conformes.',
      );
      expect(erreurEnregistrement(v, EtapeDph.face), isNull);
      expect(
        erreurEnregistrement(
          v.copyWith(concurrence: const Concurrence(aucune: true)),
          EtapeDph.concurrence,
        ),
        isNull,
      );
      expect(
        erreurEnregistrement(
          v.copyWith(promosConformes: false),
          EtapeDph.promos,
        ),
        isNull,
      );
    });

    test('messages de réussite et libellés des boutons', () {
      expect(
        messageEtapeEnregistree(EtapeDph.dn),
        'Vérification DN enregistrée.',
      );
      expect(
        messageEtapeEnregistree(EtapeDph.bilan),
        'Bilan de visite enregistré.',
      );
      expect(
        messageEtapeEnregistree(EtapeDph.concurrence),
        'Concurrence enregistrée.',
      );
      expect(
        messageEtapeEnregistree(EtapeDph.promos),
        'Vérification Promos enregistrée.',
      );
      expect(objetEnregistrement(EtapeDph.dn), 'la vérification DN');
      expect(objetEnregistrement(EtapeDph.concurrence), 'la concurrence');
      expect(objetEnregistrement(EtapeDph.bilan), 'le bilan de visite');
      expect(objetEnregistrement(EtapeDph.promos), 'la vérification Promos');
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
