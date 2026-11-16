import 'package:crm_app/core/data/detail_produit.dart';
import 'package:crm_app/core/data/detail_prospect.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('détail produit', () {
    test('tarifs, promos, remplaçants, stock exact, descriptif', () {
      final d = detailProduitDepuisJson({
        'stock': 120,
        'details': ' Crème hydratante ',
        'avantages': null,
        'tarifs': [
          {'codeTarif': '01', 'montant': 12.5},
          {'codeTarif': null, 'montant': 10},
          {'codeTarif': '03', 'montant': 'x'},
        ],
        'promos': [
          {
            'libelle': '-20 %',
            'dateDebut': '2026-11-01T00:00:00.000Z',
            'dateFin': null,
          },
        ],
        'remplacements': [
          {
            'seuil': null,
            'article': {
              'libelle': 'Crème B',
              'codeAs400': 'B1',
              'stock': 0,
              'marque': {'nom': 'ABC'},
            },
          },
        ],
      });
      expect(d.stock, 120);
      expect(d.details, 'Crème hydratante');
      expect(d.avantages, isNull);
      expect(d.tarifs.map((t) => t.montant), [12.5, 10]);
      expect(d.tarifs.first.code, '01');
      expect(d.promos.single.libelle, '-20 %');
      expect(d.promos.single.du, '01/11/2026');
      expect(d.promos.single.au, '');
      final r = d.remplacements.single;
      expect(r.nom, 'Crème B');
      expect(r.stock, 0);
      expect(r.marque, 'ABC');
    });

    test('réponse vide : listes vides', () {
      final d = detailProduitDepuisJson({});
      expect(d.tarifs, isEmpty);
      expect(d.remplacements, isEmpty);
      expect(d.stock, isNull);
    });
  });

  group('détail prospect', () {
    test('contact et timeline de tous les types', () {
      final d = detailProspectDepuisJson(
        {
          'contacts': [
            {'prenom': 'Paul', 'nom': 'Durand', 'poste': 'Gérant'},
          ],
        },
        {
          'data': [
            {
              'type': 'ETAPE',
              'date': '2026-11-10T10:00:00.000Z',
              'etape': {
                'de': 'NOUVEAU',
                'vers': 'CONTACTE',
                'commentaire': null,
              },
            },
            {
              'type': 'APPEL',
              'date': '2026-11-09T10:00:00.000Z',
              'appel': {
                'auteur': {'displayName': 'Nadia H.'},
                'resultat': 'Joint',
                'commentaire': 'RDV à fixer',
              },
            },
            {
              'type': 'NOTE',
              'date': '2026-11-08T10:00:00.000Z',
              'note': {'remarque': 'Intéressé'},
            },
            {
              'type': 'VISITE',
              'date': '2026-11-07T10:00:00.000Z',
              'visite': {
                'promoteur': {'displayName': 'Julien M.'},
                'motif': 'Découverte',
              },
            },
            {'type': 'INCONNU', 'date': '2026-11-06T10:00:00.000Z'},
          ],
        },
      );
      expect(d.contact, 'Paul Durand (Gérant)');
      expect(d.timeline.map((e) => e.titre), [
        'Étape → Contacté',
        'Appel',
        'Note',
        'Visite',
      ]);
      expect(
        d.timeline.first.detail,
        'Passé de « Fiche créée » à « Contacté »',
      );
      expect(d.timeline[1].detail, 'Nadia H. · Joint · RDV à fixer');
      expect(d.timeline[1].icone, IconeEvenement.tel);
      expect(d.timeline.first.date, '10 nov.');
    });

    test('sans contact ni historique', () {
      final d = detailProspectDepuisJson({'contacts': []}, null);
      expect(d.contact, isNull);
      expect(d.timeline, isEmpty);
    });
  });
}
