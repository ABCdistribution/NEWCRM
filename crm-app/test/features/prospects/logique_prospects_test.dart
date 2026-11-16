import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/prospects/data/villes_a_prospecter.dart';
import 'package:crm_app/features/prospects/logic/magasins_enseigne.dart';
import 'package:crm_app/features/prospects/logic/nouveau_prospect.dart';
import 'package:crm_app/features/prospects/logic/vue_prospects.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Logique pure du lot : valeurs attendues relues dans la maquette (l.697-719, l.1757-1767, l.2005-2021).
void main() {
  group('villes à prospecter (VILLES_A_PROSPECTER, l.1758)', () {
    test('six villes, dans l’ordre de la maquette', () {
      expect(villesAProspecter.map((v) => '${v.ville} ${v.codePostal}'), [
        'Le Havre 76600',
        'Dieppe 76200',
        'Pont-Audemer 27500',
        'Saint-Lô 50000',
        'Bayeux 14400',
        'Fécamp 76400',
      ]);
    });
  });

  group('magasins de l’enseigne (magasinsProspect)', () {
    List<MagasinEnseigne> pour(Role role, String id) {
      final etat = conteneurPour(role).read(crmProvider);
      return magasinsDeLEnseigne(
        etat.prospectParId(id)!,
        prospects: etat.prospects,
        clients: [...etat.tousMagasins, ...autresClients],
      );
    }

    test(
      'l’enseigne est la partie avant « – », sans « HM », en minuscules',
      () {
        Prospect p(String nom) => prospectsDemo.firstWhere((x) => x.nom == nom);
        expect(enseigneDuProspect(p('Super U – Versailles')), 'super u');
        expect(enseigneDuProspect(p('Carrefour HM – Cergy')), 'carrefour');
        expect(enseigneDuProspect(p('E.Leclerc – Caen')), 'e.leclerc');
      },
    );

    test(
      'Super U : deux clients hors secteur puis six villes décalées de 2',
      () {
        final l = pour(Role.cs, 'p1');
        expect(l, hasLength(8));
        expect(l.take(2).map((x) => x.nom), [
          'Super U – Amiens',
          'Super U – Avignon',
        ]);
        expect(l.first.type, TypeMagasinEnseigne.client);
        expect(l.first.ville, '82 avenue Jean Jaurès, 80000 Amiens');
        expect(l.first.detail, 'Classe C');
        expect(l.first.magasinId, isNotNull);
        expect(l.skip(2).map((x) => x.nom), [
          'Super U – Pont-Audemer',
          'Super U – Saint-Lô',
          'Super U – Bayeux',
          'Super U – Fécamp',
          'Super U – Le Havre',
          'Super U – Dieppe',
        ]);
        expect(
          l.skip(2).every((x) => x.type == TypeMagasinEnseigne.aProspecter),
          isTrue,
        );
        expect(l.skip(2).first.ville, '27500');
        expect(l.skip(2).first.prospectId, isNull);
        expect(l.skip(2).first.magasinId, isNull);
      },
    );

    test('Carrefour HM : clients, prospects et villes ; 8 lignes au total', () {
      final l = pour(Role.cs, 'p5');
      expect(l.map((x) => x.type), [
        TypeMagasinEnseigne.client,
        TypeMagasinEnseigne.client,
        TypeMagasinEnseigne.prospect,
        TypeMagasinEnseigne.prospect,
        ...List.filled(4, TypeMagasinEnseigne.aProspecter),
      ]);
      expect(l.map((x) => x.nom).take(4), [
        'Carrefour Market – Versailles',
        'Carrefour – Versailles',
        'Carrefour – Paris',
        'Carrefour HM – Cergy',
      ]);
      expect(l[2].detail, 'À contacter'); // groupe du prospect
      expect(l[2].ville, '75011 Paris');
      expect(l[2].prospectId, 'p2');
      expect(l.last.nom, 'Carrefour HM – Fécamp');
    });

    test('deux clients et deux prospects : quatre magasins à prospecter', () {
      final p = prospectsDemo.first;
      Magasin client(int i) => Magasin(
        id: 'x$i',
        nom: 'Super U – Ville $i',
        statut: 'Client actif',
        classe: 'B',
        adresse: 'rue $i',
        ca: '',
        evo: '',
        cde: '',
        cdeDate: '',
        visites: 0,
        objectif: 0,
      );
      final autres = [
        for (var i = 0; i < 3; i++)
          prospectsDemo[1].copyWith(nom: 'Super U – Autre $i'),
      ];
      final l = magasinsDeLEnseigne(
        p,
        prospects: autres,
        clients: [for (var i = 0; i < 5; i++) client(i)],
      );
      // Les clients et les prospects de l'enseigne sont limités à deux chacun.
      expect(
        l.where((x) => x.type == TypeMagasinEnseigne.client),
        hasLength(2),
      );
      expect(
        l.where((x) => x.type == TypeMagasinEnseigne.prospect),
        hasLength(2),
      );
      expect(
        l.where((x) => x.type == TypeMagasinEnseigne.aProspecter),
        hasLength(4),
      );
    });

    test('un prospect perdu s’affiche avec son étape « Perdu »', () {
      final perdu = prospectsDemo[1].copyWith(
        nom: 'Super U – Perdu',
        statut: StatutProspect.perdu,
      );
      final l = magasinsDeLEnseigne(
        prospectsDemo.first,
        prospects: [perdu],
        clients: const [],
      );
      expect(l.first.detail, 'Perdu');
    });
  });

  group('vue Prospects (pageProspects)', () {
    List<Prospect> vue(
      Role role,
      VueProspects v, [
      List<String> chefs = const [],
    ]) => prospectsDeLaVue(
      prospects: conteneurPour(role).read(crmProvider).prospects,
      role: role,
      nomProfil: role.profil.nom,
      vue: v,
      chefsSecteur: chefs,
    );

    test('« Mes prospects » : ceux dont la timeline porte « par {nom} »', () {
      expect(vue(Role.cs, VueProspects.liste).map((p) => p.id), ['p1']);
      expect(vue(Role.dir, VueProspects.liste).map((p) => p.id), ['p2', 'p3']);
    });

    test('« Tout le secteur » et « Tous les prospects »', () {
      expect(vue(Role.cs, VueProspects.tous), hasLength(12));
      expect(vue(Role.dir, VueProspects.tous), hasLength(23));
    });

    test(
      'le directeur peut se limiter à des chefs de secteur ; le chef de secteur non',
      () {
        expect(vue(Role.dir, VueProspects.tous, ['Karim B.']), hasLength(11));
        expect(
          vue(Role.dir, VueProspects.tous, ['Karim B.', 'Nadia H.']),
          hasLength(23),
        );
        expect(vue(Role.dir, VueProspects.tous, ['Inconnu']), isEmpty);
        expect(vue(Role.cs, VueProspects.tous, ['Karim B.']), hasLength(12));
        // Les chefs de secteur ne jouent pas dans « Mes prospects ».
        expect(vue(Role.dir, VueProspects.liste, ['Karim B.']), hasLength(2));
      },
    );

    test('hors encadrement, toute la liste est montrée', () {
      final tous = prospectsDemo;
      expect(
        prospectsDeLaVue(
          prospects: tous,
          role: Role.promoteur,
          nomProfil: 'Julien M.',
          vue: VueProspects.liste,
          chefsSecteur: const [],
        ),
        hasLength(23),
      );
    });

    test('compteurs par groupe et potentiel total arrondi au dixième', () {
      final tous = vue(Role.dir, VueProspects.tous);
      expect(
        [for (final g in GroupeProspect.values) compterGroupe(tous, g)],
        [9, 5, 8, 1],
      );
      expect(potentielTotal(tous), 2135);
      expect(potentielTotal(vue(Role.cs, VueProspects.tous)), 1140);
      expect(potentielTotal(const []), 0);
      Prospect avecPot(double pot) => prospectsDemo.first.copyWith(pot: pot);
      expect(potentielTotal([avecPot(0.04), avecPot(0.04)]), 0.1); // 0,08 → 0,1
      expect(potentielTotal([avecPot(1.2), avecPot(2.4)]), 3.6);
    });

    test(
      'la liste est triée par potentiel décroissant, à égalité dans l’ordre d’origine',
      () {
        final liste = listeAffichee(vue(Role.cs, VueProspects.tous), null);
        expect(liste.map((p) => p.pot).toList(), [
          180,
          160,
          130,
          120,
          95,
          90,
          80,
          70,
          65,
          60,
          50,
          40,
        ]);
        final deux = [
          prospectsDemo[0].copyWith(pot: 50),
          prospectsDemo[1].copyWith(pot: 50),
        ];
        expect(listeAffichee(deux, null).map((p) => p.id), ['p1', 'p2']);
      },
    );

    test('un groupe retenu ne garde que ses prospects', () {
      final tous = vue(Role.cs, VueProspects.tous);
      expect(listeAffichee(tous, GroupeProspect.rdvPris).map((p) => p.id), [
        'p18',
        'p6',
      ]);
      expect(listeAffichee(tous, GroupeProspect.reference), isEmpty);
      // Un prospect perdu est dans la liste complète, mais dans aucun groupe.
      final perdu = [
        prospectsDemo.first.copyWith(statut: StatutProspect.perdu),
      ];
      expect(listeAffichee(perdu, null), hasLength(1));
      for (final g in GroupeProspect.values) {
        expect(listeAffichee(perdu, g), isEmpty);
        expect(compterGroupe(perdu, g), 0);
      }
      expect(libelleGroupeProspect(perdu.first), 'Perdu');
    });

    test(
      'prochaine action : première ligne non faite du planning sur ce prospect',
      () {
        final etapes = conteneurPour(Role.dir).read(crmProvider).etapes;
        expect(prochaineEtape(etapes, 'p1')?.heure, '10:00');
        expect(prochaineEtape(etapes, 'p2')?.jour, 2);
        expect(prochaineEtape(etapes, 'p3'), isNull); // la ligne est déjà faite
        expect(prochaineEtape(etapes, 'p9'), isNull);
      },
    );
  });

  group('formulaire Nouveau prospect', () {
    BrouillonProspect valide() =>
        const BrouillonProspect(enseigne: 'Super Proxi', raison: 'Dupont');

    test('un formulaire minimal est valide', () {
      expect(validerProspect(valide()), isEmpty);
    });

    test('enseigne et raison sociale requises', () {
      expect(validerProspect(const BrouillonProspect()), {
        'enseigne': 'Enseigne requise',
        'raison': 'Raison sociale requise',
      });
      expect(
        validerProspect(
          const BrouillonProspect(enseigne: '  ', raison: ' '),
        ).keys,
        ['enseigne', 'raison'],
      );
    });

    test('email : une forme a@b.c', () {
      for (final bon in ['a@b.c', ' contact@superproxi.fr ', 'x.y@z.fr']) {
        expect(
          validerProspect(valide().copyWith(email: bon)),
          isEmpty,
          reason: bon,
        );
      }
      for (final mauvais in ['a@b', 'a b@c.d', '@b.c', 'a@@b.c', 'abc']) {
        expect(validerProspect(valide().copyWith(email: mauvais)), {
          'email': 'Email invalide',
        }, reason: mauvais);
      }
      expect(validerProspect(valide().copyWith(email: '  ')), isEmpty);
    });

    test('probabilité : entier de 0 à 100', () {
      for (final bon in ['0', '7', '100', '007', ' 55 ']) {
        expect(
          validerProspect(valide().copyWith(proba: bon)),
          isEmpty,
          reason: bon,
        );
      }
      for (final mauvais in [
        '101',
        '-1',
        '12,5',
        '12.5',
        'abc',
        '99999999999999999999',
      ]) {
        expect(validerProspect(valide().copyWith(proba: mauvais)), {
          'proba': 'Entre 0 et 100',
        }, reason: mauvais);
      }
    });

    test('potentiel : nombre, virgule ou point décimal', () {
      expect(lirePotentiel(''), isNull);
      expect(lirePotentiel('   '), isNull);
      expect(lirePotentiel('4500'), 4500);
      expect(lirePotentiel('1500,5'), 1500.5);
      expect(lirePotentiel('1500.5'), 1500.5);
      expect(lirePotentiel(' 12 '), 12);
      expect(lirePotentiel('.5'), 0.5);
      expect(lirePotentiel('abc')!.isNaN, isTrue);
      expect(lirePotentiel('1 500')!.isNaN, isTrue);
      expect(lirePotentiel('1,5,5')!.isNaN, isTrue);
      expect(validerProspect(valide().copyWith(pot: 'abc')), {
        'pot': 'Montant invalide',
      });
      expect(validerProspect(valide().copyWith(pot: '')), isEmpty);
    });

    test('plusieurs erreurs à la fois', () {
      expect(
        validerProspect(
          const BrouillonProspect(email: 'x', proba: '200', pot: 'y'),
        ).keys,
        ['enseigne', 'raison', 'email', 'proba', 'pot'],
      );
    });

    test(
      'identifiant : p suivi du nombre de prospects plus un, décalé s’il existe',
      () {
        expect(prochainIdProspect(prospectsDemo), 'p24');
        expect(prochainIdProspect(const []), 'p1');
        final cs = prospectsDemo.where((p) => p.secteurId == 's1').toList();
        expect(cs, hasLength(12));
        expect(prochainIdProspect(cs), 'p13');
        expect(prochainIdProspect(prospectsDemo.take(3).toList()), 'p4');
        // « p4 » est pris : on prend « p5 ».
        expect(
          prochainIdProspect([
            prospectsDemo[3],
            prospectsDemo[0],
            prospectsDemo[1],
          ]),
          'p5',
        );
      },
    );

    test('construction complète du prospect', () {
      final p = construireProspect(
        const BrouillonProspect(
          enseigne: ' Super Proxi ',
          raison: 'Supermarché Dupont SAS',
          ville: ' Lunel ',
          cp: '34400',
          classe: 'B',
          source: 'WEB',
          etape: StatutProspect.proposition,
          pot: '125',
        ),
        id: 'p30',
        creePar: 'Nadia H.',
      );
      expect(p.id, 'p30');
      expect(p.nom, 'Super Proxi – Lunel');
      expect(p.raison, 'SUPERMARCHÉ DUPONT SAS');
      expect(p.classe, 'B');
      expect(p.cp, '34400 Lunel');
      expect(p.statut, StatutProspect.proposition);
      expect(p.proba, 55);
      expect(p.pot, 0.1); // 125 € = 0,125 k€ → 0,1
      expect(p.attente, isTrue);
      expect(p.secteurId, 's1');
      expect(p.cs, 'Nadia H.');
      expect(p.contact, isNull);
      expect(p.timeline.single.detail, 'Source : web · par Nadia H.');
    });

    test('code postal ou ville seuls : sans espace en trop', () {
      final seul = construireProspect(
        valide().copyWith(cp: '34400'),
        id: 'p30',
        creePar: 'x',
      );
      expect(seul.cp, '34400');
      final ville = construireProspect(
        valide().copyWith(ville: 'Lunel'),
        id: 'p30',
        creePar: 'x',
      );
      expect(ville.cp, 'Lunel');
      expect(ville.nom, 'Super Proxi – Lunel');
    });

    test('arrondi du potentiel en k€ : Math.round de la maquette', () {
      double pot(String euros) => construireProspect(
        valide().copyWith(pot: euros),
        id: 'p30',
        creePar: 'x',
      ).pot;
      expect(pot('4500'), 4.5);
      expect(pot('4549'), 4.5);
      expect(pot('4550'), 4.6); // la moitié est arrondie vers le haut
      expect(pot('50'), 0.1); // 0,05 k€ → 0,1
      expect(pot('49'), 0);
      expect(pot('0'), 0);
      expect(pot(''), 0);
    });

    test('probabilité saisie ou, à défaut, celle de l’étape', () {
      int proba(StatutProspect e, [String saisie = '']) => construireProspect(
        valide().copyWith(etape: e, proba: saisie),
        id: 'p30',
        creePar: 'x',
      ).proba;
      expect(proba(StatutProspect.nouveau), 10);
      expect(proba(StatutProspect.contacte), 20);
      expect(proba(StatutProspect.visite), 40);
      expect(proba(StatutProspect.proposition), 55);
      expect(proba(StatutProspect.negociation), 60);
      expect(proba(StatutProspect.gagne), 100);
      expect(proba(StatutProspect.gagne, '0'), 0);
      expect(proba(StatutProspect.nouveau, ' 33 '), 33);
    });

    test('les choix proposés sont ceux de la maquette', () {
      expect(etapesCreation.values, [
        'Nouveau',
        'Contacté',
        'Visite',
        'Proposition',
        'Négociation',
        'Gagné',
      ]);
      expect(classesCreation, ['A', 'B', 'C', 'D', 'E', 'F', 'G']);
      expect(sourcesProspect.values, [
        'Salon',
        'Recommandation',
        'Terrain',
        'Web',
      ]);
      expect(secteursDemo.values, [
        'Île-de-France',
        'Normandie / Hauts-de-France',
        'Sud-Est',
      ]);
    });
  });
}
