import 'package:flutter_test/flutter_test.dart';
import 'package:salespilot/features/pilot/pilot_prospect_fiche_page.dart';
import 'package:salespilot/features/pilot/pilot_rapports_page.dart';
import 'package:salespilot/features/pilot/tournee_etapes.dart';

void main() {
  final lundi = DateTime(2026, 11, 2);

  group('phase de la semaine : prévision jusqu\'au lundi soir inclus, rapport dès le mardi', () {
    test('le lundi (même tard) on est encore en prévision', () {
      expect(phaseDeSemaine(lundi, DateTime(2026, 11, 2, 23, 30)), PhaseSemaine.prevision);
    });
    test('dès le mardi on est en rapport', () {
      expect(phaseDeSemaine(lundi, DateTime(2026, 11, 3, 0, 5)), PhaseSemaine.rapport);
    });
    test('une semaine à venir est en prévision, une semaine passée en rapport', () {
      expect(phaseDeSemaine(DateTime(2026, 11, 9), DateTime(2026, 11, 4)), PhaseSemaine.prevision);
      expect(phaseDeSemaine(DateTime(2026, 10, 26), DateTime(2026, 11, 4)), PhaseSemaine.rapport);
    });
  });

  group('état du rapport', () {
    test('avant le mardi : prévision modifiable, pas de validation', () {
      final e = EtatSemaine.fromJson({'prevuAt': null, 'valideAt': null}, lundi, DateTime(2026, 11, 2, 10));
      expect(e.previsionModifiable, isTrue);
      expect(e.peutValider, isFalse);
      expect(e.verrouillee, isFalse);
    });

    test('dès le mardi sans prévision enregistrée : « non renseignée », validation possible', () {
      final e = EtatSemaine.fromJson({'prevuAt': null, 'valideAt': null}, lundi, DateTime(2026, 11, 3, 9));
      expect(e.previsionNonRenseignee, isTrue);
      expect(e.previsionModifiable, isFalse);
      expect(e.peutValider, isTrue);
    });

    test('dès le mardi avec prévision : figée, pas « non renseignée »', () {
      final e = EtatSemaine.fromJson({'prevuAt': '2026-11-02T08:00:00.000Z', 'nbEtapesPrevues': 3}, lundi, DateTime(2026, 11, 4));
      expect(e.previsionNonRenseignee, isFalse);
      expect(e.nbEtapesPrevues, 3);
    });

    test('rapport validé : verrouillé, rien à valider ni à enregistrer, « Validé auto » conservé', () {
      final e = EtatSemaine.fromJson({'valideAt': '2026-11-09T03:00:00.000Z', 'valideAuto': true}, lundi, DateTime(2026, 11, 10));
      expect(e.verrouillee, isTrue);
      expect(e.valideAuto, isTrue);
      expect(e.peutValider, isFalse);
      expect(e.previsionModifiable, isFalse);
    });

    test('la phase est recalculée sur le téléphone, même avec une copie ancienne', () {
      // Copie locale prise le lundi, relue le mercredi : la phase n'est plus « prévision ».
      final e = EtatSemaine.fromJson({'prevuAt': null, 'valideAt': null}, lundi, DateTime(2026, 11, 4));
      expect(e.phase, PhaseSemaine.rapport);
    });
  });

  group('mes rapports (historique)', () {
    test('lit les chiffres du mois et les semaines, validées ou non', () {
      final h = HistoriqueRapports.fromJson({
        'mois': '2026-10',
        'visitesMois': 58,
        'pourcentPrevuMois': 91,
        'references': 3,
        'semaines': [
          {'semaine': '2026-11-02', 'numero': 45, 'statut': 'EN_COURS', 'valideAt': null, 'nbPrevues': 13, 'nbLignes': 13, 'visites': 0, 'rdv': 0, 'pourcentPrevu': 0},
          {'semaine': '2026-10-19', 'numero': 43, 'statut': 'VALIDE_AUTO', 'valideAt': '2026-10-26T03:00:00.000Z', 'nbPrevues': 12, 'nbLignes': 12, 'visites': 12, 'rdv': 2, 'pourcentPrevu': 100},
        ],
      });
      expect(h.mois, 10);
      expect(h.visitesMois, 58);
      expect(h.pourcentMois, 91);
      expect(h.semaines.first.validee, isFalse);
      expect(h.semaines.last.auto, isTrue);
      expect(h.semaines.last.lundi, DateTime(2026, 10, 19));
    });

    test('sans prévision, le pourcentage du prévu reste vide', () {
      final s = RapportSemaine.fromJson({'semaine': '2026-10-12', 'numero': 42, 'statut': 'VALIDE', 'nbLignes': 4, 'visites': 4, 'rdv': 1});
      expect(s.pourcentPrevu, isNull);
      expect(s.nbPrevues, isNull);
    });
  });

  group('fiche prospect', () {
    test('lit la fiche, le contact principal et la timeline', () {
      final f = FicheProspect.fromJson(
        {
          'id': 'p1',
          'enseigne': 'Hyper Plaine',
          'raisonSociale': 'HYPER PLAINE SAS',
          'ville': 'Noisy-le-Grand',
          'statut': 'NEGOCIATION',
          'probabilite': 60,
          'potentielCaAnnuel': '42000',
          'createdAt': '2026-10-02T08:00:00.000Z',
          // Du plus récent au plus ancien : le contact principal est le dernier de la liste.
          'contacts': [
            {'nom': 'Autre', 'prenom': 'Zoé'},
            {'nom': 'Petit', 'prenom': 'M.', 'poste': 'directeur', 'portable': '0600000000'},
          ],
        },
        {
          'data': [
            {'type': 'NOTE', 'date': '2026-10-30T10:00:00.000Z', 'note': {'remarque': 'À rappeler'}},
            {'type': 'ETAPE', 'date': '2026-10-20T10:00:00.000Z', 'etape': {'de': 'VISITE', 'vers': 'NEGOCIATION'}},
            {'type': 'INCONNU', 'date': '2026-10-01T10:00:00.000Z'},
          ],
        },
      );
      expect(f.segments, 4);
      expect(f.potentiel, 42000);
      expect(f.contact, 'M. Petit, directeur');
      expect(f.contactTelephone, '0600000000');
      expect(f.evenements.length, 3); // note, étape, « Fiche créée » ; un type inconnu est ignoré
      expect(f.evenements[1].titre, 'Étape → En négociation');
      expect(f.evenements.last.titre, 'Fiche créée');
    });
  });

  group('lignes du rapport', () {
    test('une ligne libre garde son texte comme titre et son adresse', () {
      final e = EtapeTournee.fromApi({
        'id': 'e1',
        'adm': false,
        'libelle': 'Chez Marcel',
        'adresse': '12 rue du Port, Lyon',
        'datePassage': '2026-11-04T09:30:00.000Z',
        'client': null,
        'prospect': null,
        'rdv': true,
        'soireeEtape': true,
        'soireeLieu': 'Lyon',
        'soireeAdresse': '3 place Bellecour',
      });
      expect(e.type, 'LIBRE');
      expect(e.titre, 'Chez Marcel');
      expect(e.adresse, '12 rue du Port, Lyon');
      expect(e.heure, '09:30');
      expect(e.soireeAdresse, '3 place Bellecour');
      expect(e.aUneAdresse, isTrue);
    });

    test('l\'adresse saisie sur la ligne prime sur celle du magasin', () {
      final e = EtapeTournee.fromApi({
        'id': 'e2',
        'adm': false,
        'adresse': 'Entrepôt nord',
        'datePassage': '2026-11-04T00:00:00.000Z',
        'client': {'id': 'c1', 'enseigne': 'Super Lac', 'ville': 'Créteil', 'adresse1': '1 av. X', 'codePostal': '94000'},
        'prospect': null,
      });
      expect(e.type, 'CLIENT');
      expect(e.adresse, 'Entrepôt nord');
      expect(e.heure, isNull);
    });

    test('une ligne de la tournée prévue se lit comme une étape', () {
      final e = EtapeTournee.fromLigne(
        {'jour': '2026-11-03', 'heure': '14:00', 'adm': true, 'titre': 'ADM', 'rdv': false, 'soireeEtape': false},
        0,
      );
      expect(e.type, 'ADM');
      expect(e.titre, 'Administratif');
      expect(e.heure, '14:00');
    });
  });
}
