import 'package:crm_app/core/data/prospects_serveur.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/features/catalogue/data/news_serveur.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prospectDepuisJson', () {
    final base = {
      'id': 'p1',
      'enseigne': 'PHARMACIE DU CENTRE',
      'raisonSociale': 'PHARMACIE DU CENTRE SARL',
      'ville': 'VERSAILLES',
      'codePostal': '78000',
      'statut': 'NEGOCIATION',
      'probabilite': 60,
      'potentielCaAnnuel': '48000.00',
      'niveauClass': 'b',
      'secteur': {'id': 's1', 'code': '78', 'nom': 'Yvelines'},
      'assignedTo': {'id': 'u1', 'displayName': 'Nadia H.'},
    };

    test(
      'champs repris, montant en k€, classe en majuscule, timeline vide',
      () {
        final p = prospectDepuisJson(base)!;
        expect(p.nom, 'Pharmacie Du Centre');
        expect(p.cp, '78000 Versailles');
        expect(p.statut, StatutProspect.negociation);
        expect(p.pot, 48);
        expect(p.proba, 60);
        expect(p.classe, 'B');
        expect(p.secteurId, 's1');
        expect(p.cs, 'Nadia H.');
        expect(p.timeline, isEmpty);
      },
    );

    test('statut inconnu : fiche créée ; classe absente : tiret', () {
      final p = prospectDepuisJson({
        ...base,
        'statut': 'AUTRE',
        'niveauClass': null,
        'potentielCaAnnuel': null,
        'probabilite': null,
      })!;
      expect(p.statut, StatutProspect.nouveau);
      expect(p.classe, '—');
      expect(p.pot, 0);
      expect(p.proba, StatutProspect.nouveau.probaParDefaut);
    });

    test('sans identifiant ou enseigne : ignoré', () {
      expect(prospectDepuisJson({...base, 'id': null}), isNull);
      expect(prospectDepuisJson({...base, 'enseigne': ' '}), isNull);
    });
  });

  group('newsDepuisJson', () {
    test('date jj/mm/aaaa, HTML retiré, un paragraphe par ligne', () {
      final n = newsDepuisJson({
        'id': 'n1',
        'titre': ' Nouveautés ',
        'publiee': true,
        'publieeAt': '2026-05-26T08:00:00.000Z',
        'contenu': '<p>Bonjour à tous,</p><p>Trois nouveautés&nbsp;:</p>',
      })!;
      expect(n.titre, 'Nouveautés');
      expect(n.date, '26/05/2026');
      expect(n.texte, ['Bonjour à tous,', 'Trois nouveautés :']);
    });

    test('brouillon ou sans titre : ignoré', () {
      expect(
        newsDepuisJson({'id': 'n', 'titre': 'x', 'publiee': false}),
        isNull,
      );
      expect(newsDepuisJson({'id': 'n', 'titre': ''}), isNull);
    });

    test('sans données du CRM : les news de la démonstration', () {
      definirNewsServeur(null);
      expect(newsActuelles(), isNotEmpty);
      expect(newsParIdActuelle('n1'), isNotNull);
    });
  });
}
