import 'package:crm_app/core/data/data.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Valeurs obtenues en exécutant la maquette (`calcEcarts`, `ecartsListe`, `resumeEcarts`, `fixE`, `alertes`, `objMag`).
void main() {
  ResultatEcarts? ecarts(Role r, {required bool valide}) {
    final e = conteneurPour(r).read(crmProvider);
    return calculerEcarts(
      prevu: previsionDemo(
        e.etapes,
        magasins: e.magasins,
        prospects: e.prospects,
      ),
      etapes: e.etapes,
      valide: valide,
    );
  }

  List<List<String>> liste(ResultatEcarts r) => [
    for (final l in ecartsTries(r.lignes)) [l.titre, l.sousTitre],
  ];

  test('directeur, semaine en cours : 3 réalisées sur 8 prévues (38 %)', () {
    final r = ecarts(Role.dir, valide: false)!;
    expect(
      [r.prevues, r.realisees, r.pct, r.ajoutees, r.retirees, r.deplacees],
      [8, 3, 38, 1, 1, 1],
    );
    expect(liste(r), [
      [
        'Carrefour Market – Rouen',
        'Retiré du planning, non réalisé · prévu Jeu 14:00',
      ],
      [
        'Carrefour Market – Versailles',
        'Déplacé · prévu Mar 14:00 → planifié Mar 15:10',
      ],
      ['Administratif', 'Ajouté (non prévu) · Mer 16:00'],
      ['Carrefour – Rouen', 'À faire · Mer 09:00'],
      ['Carrefour – Paris', 'À faire · Mer 11:30'],
      ['Super U – Versailles', 'À faire · Jeu 10:00'],
      ['Carrefour – Ivry-sur-Seine', 'Réalisé comme prévu · Lun 09:30'],
      ['Auchan – Rouen', 'Réalisé comme prévu · Lun 14:00'],
      ['Carrefour Market – Rouen', 'Réalisé comme prévu · Mar 10:00'],
    ]);
  });

  test('rapport validé : les lignes à faire deviennent « Non réalisé »', () {
    final r = ecarts(Role.dir, valide: true)!;
    expect(r.non, 3);
    expect(liste(r).sublist(1, 4), [
      ['Carrefour – Rouen', 'Non réalisé · Mer 09:00'],
      ['Carrefour – Paris', 'Non réalisé · Mer 11:30'],
      ['Super U – Versailles', 'Non réalisé · Jeu 10:00'],
    ]);
  });

  test(
    'chef de secteur et promoteur : prévision limitée aux clients visibles',
    () {
      final cs = ecarts(Role.cs, valide: false)!;
      expect([cs.prevues, cs.realisees, cs.pct], [4, 1, 25]);
      final p = ecarts(Role.promoteur, valide: false)!;
      expect([p.prevues, p.realisees, p.pct], [2, 1, 50]);
    },
  );

  test('sans prévision : aucune comparaison', () {
    expect(
      calculerEcarts(prevu: null, etapes: etapesDemo, valide: false),
      isNull,
    );
  });

  test('résumés d’écarts (équipe)', () {
    expect(
      resumeEcarts([
        GenreEcart.ajoute,
        GenreEcart.retire,
        GenreEcart.retire,
        GenreEcart.deplace,
        GenreEcart.non,
      ]),
      '+1 ajoutée · 2 retirées · 1 déplacée · 1 non réalisée',
    );
    expect(resumeEcarts(const []), 'aucun écart');
    final l = ecartsTries([
      EcartPlanning.resume(
        GenreEcart.ajoute,
        'Auchan – Rouen',
        'visite non prévue',
      ),
      EcartPlanning.resume(GenreEcart.retire, 'Monoprix – Caen', 'prévu mardi'),
    ]);
    expect(
      [
        for (final x in l) [x.titre, x.sousTitre],
      ],
      [
        ['Monoprix – Caen', 'Retiré du planning, non réalisé · prévu mardi'],
        ['Auchan – Rouen', 'Ajouté (non prévu) · visite non prévue'],
      ],
    );
  });

  test('alertes de la cloche par rôle (maquette : alertes())', () {
    List<String> titres(Role r) => [
      for (final a in conteneurPour(r).read(alertesProvider))
        '${a.icone} ${a.titre} (${a.rang})',
    ];
    expect(titres(Role.promoteur), [
      '📍 Carrefour Market – Versailles (-2)',
      '📍 U Express – Boulogne-Billancourt (10)',
      '💤 U Express – Paris (90)',
    ]);
    expect(titres(Role.dir), [
      '📍 Carrefour Market – Versailles (-2)',
      '📍 U Express – Boulogne-Billancourt (10)',
      '🚚 Monoprix – Caen (50)',
      '💤 U Express – Paris (90)',
    ]);
    final cs = conteneurPour(Role.cs).read(alertesProvider);
    expect(cs, hasLength(7));
    expect(cs[1].detail, 'RDV prospect aujourd’hui à 11:30 · À contacter');
    expect(
      cs[3].detail,
      'Prospect en négo sans action prévue depuis 6 jours · à relancer (120 k€/an)',
    );
  });

  test('objectifs et OP d’un magasin (maquette : objMag)', () {
    final m1 = objectifMagasin(magasinsDemo.firstWhere((m) => m.id == 'm1'));
    expect([m1.ca, m1.obj, m1.ops.length], [4570, 5250, 2]);
    final m2 = objectifMagasin(magasinsDemo.firstWhere((m) => m.id == 'm2'));
    expect([m2.ca, m2.obj, m2.ops.length], [5420, 5700, 3]);
  });
}
