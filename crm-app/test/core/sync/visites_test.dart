import 'package:crm_app/core/data/commandes_serveur.dart';
import 'package:crm_app/core/data/visites_serveur.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/features/equipe/data/secteur_demo.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _visite(
  String id, {
  String? clientId = 'c1',
  String promoteurId = 'u1',
  String nom = 'Léa Petit',
  String cree = '2026-11-10T08:30:00.000Z',
  Object? raison,
  int photos = 0,
}) => {
  'id': id,
  'createdAt': cree,
  'client': clientId == null ? null : {'id': clientId, 'enseigne': 'CARREFOUR'},
  'promoteur': {'id': promoteurId, 'displayName': nom},
  'raisonAbsenceCommande': raison,
  '_count': {'photos': photos},
};

void main() {
  group('visites du CRM', () {
    test('une visite devient une visite envoyée au nom de son auteur', () {
      final v = visiteDepuisJson(
        _visite(
          'v1',
          photos: 3,
          raison: {'id': 'r1', 'libelle': 'Rayon plein'},
        ),
      )!;
      expect(v.id, 'v1');
      expect(v.magasinId, 'c1');
      expect(v.par, 'Léa Petit');
      expect(v.parId, 'u1');
      expect(v.etat, EtatVisite.envoyee);
      expect(v.num, 0);
      expect(v.photos[EtapeDph.arrivee], 3);
      expect(v.raisonAbsence, 'Rayon plein');
      expect(v.raisonAbsenceId, 'r1');
      expect(v.chrono.containsKey(EtapeDph.debut), isTrue);
    });

    test('sans client (visite de prospection) : ignorée', () {
      expect(visiteDepuisJson(_visite('v2', clientId: null)), isNull);
    });

    test('séparation entre mes visites et celles des autres', () {
      final r = visitesDepuisJson(
        [
          _visite('v1', promoteurId: 'moi'),
          _visite('v2', promoteurId: 'autre', nom: 'Paul Roux'),
          _visite('v3', clientId: null),
        ],
        moiId: 'moi',
        moiNom: 'Nadia H.',
      );
      expect(r.miennes.map((v) => v.id), ['v1']);
      expect(r.miennes.single.par, 'Nadia H.');
      expect(r.autres.map((v) => v.par), ['Paul Roux']);
    });
  });

  test('une commande garde son auteur quand le CRM le donne', () {
    final c = commandeDepuisJson({
      'id': 'c-1',
      'numero': 'CDE-1',
      'dateCommande': '2026-11-03T09:12:00.000Z',
      'statutLivraison': 'EN_PREPARATION',
      'total': 10,
      'client': {'id': 'c1'},
      'auteur': {'id': 'u1', 'displayName': 'Léa Petit'},
    })!;
    expect(c.auteurId, 'u1');
    expect(c.auteurNom, 'Léa Petit');
    final sans = commandeDepuisJson({
      'id': 'c-2',
      'numero': 'CDE-2',
      'auteur': null,
    })!;
    expect(sans.auteurId, isNull);
  });

  test('clé de tri des dates : le mois le plus récent d’abord', () {
    expect(cleDate('4 nov. 09:00'), greaterThan(cleDate('30 oct.')));
    expect(cleDate('4 nov. 09:00'), greaterThan(cleDate('3 nov. 09:00')));
    expect(cleDate('4 nov. 10:00'), greaterThan(cleDate('4 nov. 09:00')));
  });
}
