import 'package:crm_app/core/envoi/corps_visite.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/features/commandes/logic/attente_crm_corps.dart';
import 'package:crm_app/features/commandes/state/commande_en_cours.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/faux_serveur_envoi.dart';

const _client = '11111111-1111-4111-8111-111111111111';
const _q1 = '22222222-2222-4222-8222-222222222221';
const _q2 = '22222222-2222-4222-8222-222222222222';
const _art1 = '33333333-3333-4333-8333-333333333331';
const _art2 = '33333333-3333-4333-8333-333333333332';
const _raison = '44444444-4444-4444-8444-444444444444';
const _prop = '55555555-5555-4555-8555-555555555555';
const _planning = '66666666-6666-4666-8666-666666666666';

Visite _visite({
  TypeVisite type = TypeVisite.commerciale,
  CommandeLiee? cmd,
  String? raisonId,
  String? planningId,
}) => Visite(
  id: 'v218093',
  num: 218093,
  magasinId: _client,
  par: 'Jean DUPONT',
  etat: EtatVisite.terminee,
  date: '4 nov. 14:23',
  age: 0,
  chrono: const {
    EtapeDph.debut: '04/11/2026 14h23',
    EtapeDph.arrivee: '04/11/2026 14h27',
    EtapeDph.rayonFin: '04/11/2026 15h02',
  },
  photos: const {EtapeDph.arrivee: 1, EtapeDph.rayonArrivee: 1},
  commandeEnRayon: true,
  kits: const ['KIT91265', 'KIT2'],
  dn: const {'KIT91265': 5, 'KIT2': 0},
  reponses: const {_q1: 'true', _q2: '', 'q-demo': 'x'},
  indispensables: const {_art1: true, _art2: false, 'a-demo': true},
  raisonAbsenceId: raisonId,
  raisonAbsence: raisonId == null ? '' : 'Magasin fermé',
  cmd: cmd,
  typeVisite: type,
  propositionPemId: type == TypeVisite.pem ? _prop : null,
  planningId: planningId,
  articlesPem: type == TypeVisite.pem
      ? const {
          _art1: (present: true, misEnAvant: true),
          _art2: (present: false, misEnAvant: true),
        }
      : const {},
);

void main() {
  group('horodatageIso', () {
    test("l'heure locale du téléphone devient une date UTC ISO 8601", () {
      final iso = horodatageIso('04/11/2026 14h23')!;
      expect(DateTime.parse(iso).isUtc, isTrue);
      expect(DateTime.parse(iso).toLocal(), DateTime(2026, 11, 4, 14, 23));
    });

    test('texte illisible ou date impossible : refusé', () {
      expect(horodatageIso('4 nov. 14:23'), isNull);
      expect(horodatageIso('31/02/2026 14h23'), isNull);
      expect(horodatageIso(''), isNull);
    });
  });

  group('genererIdVisite', () {
    test('64 caractères au plus, alphanumérique, différent à chaque appel', () {
      final a = genererIdVisite();
      final b = genererIdVisite();
      expect(a, isNot(b));
      expect(a.length, lessThanOrEqualTo(64));
      expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(a), isTrue);
    });
  });

  group('corpsVisite commerciale', () {
    test("noms de champs et valeurs conformes au DTO de l'API", () {
      final c = corpsVisite(
        _visite(
          cmd: const CommandeLiee(
            id: '2042',
            ht: '10 €',
            liv: '06/11/2026',
            idApk: 'AbC123xYz9',
          ),
        ),
        idApk: 'Vabc',
      );
      expect(erreursCorpsVisite(c), isEmpty);
      expect(c['idApk'], 'Vabc');
      expect(c['clientId'], _client);
      expect(c['typeVisite'], 'COMMERCIALE');
      expect(c['commandeEnRayon'], isTrue);
      expect(c['idCommandeApk'], 'AbC123xYz9');
      expect(c.containsKey('raisonAbsenceCommandeId'), isFalse);
      expect(c.containsKey('propositionPemId'), isFalse);
      expect(c.containsKey('articlesPem'), isFalse);
      expect(c['kits'], [
        {'code': 'KIT91265', 'references': 5},
        {'code': 'KIT2', 'references': 0},
      ]);
      // Réponse vide et question de la démonstration (pas un UUID) écartées.
      expect(c['reponses'], [
        {'questionId': _q1, 'valeur': 'true'},
      ]);
      expect(c['indispensables'], [
        {'articleId': _art1, 'present': true},
        {'articleId': _art2, 'present': false},
      ]);
    });

    test("le chrono part en ISO 8601, avec l'étape de l'API", () {
      final c = corpsVisite(_visite(), idApk: 'Vabc');
      final etapes = (c['etapes']! as List).cast<Map<String, Object?>>();
      expect(etapes.map((e) => e['etape']), ['debut', 'arrivee', 'rayonFin']);
      for (final e in etapes) {
        expect(DateTime.tryParse(e['horodatage']! as String), isNotNull);
        expect(e['horodatage'], endsWith('Z'));
      }
    });

    test("sans commande : la raison d'absence part, jamais les deux", () {
      final c = corpsVisite(_visite(raisonId: _raison), idApk: 'Vabc');
      expect(c['raisonAbsenceCommandeId'], _raison);
      expect(c.containsKey('idCommandeApk'), isFalse);
      expect(erreursCorpsVisite(c), isEmpty);
      // Commande liée ET raison restée en mémoire : la commande l'emporte.
      final deux = corpsVisite(
        _visite(
          raisonId: _raison,
          cmd: const CommandeLiee(
            id: '1',
            ht: '1 €',
            liv: '-',
            idApk: 'AbC123xYz9',
          ),
        ),
        idApk: 'Vabc',
      );
      expect(deux.containsKey('raisonAbsenceCommandeId'), isFalse);
      expect(deux['idCommandeApk'], 'AbC123xYz9');
    });

    test("une commande liée sans identifiant mobile n'est pas envoyée", () {
      final c = corpsVisite(
        _visite(
          cmd: const CommandeLiee(id: '2018', ht: '1 €', liv: '-'),
        ),
        idApk: 'Vabc',
      );
      expect(c.containsKey('idCommandeApk'), isFalse);
    });

    test('visite partie du planning du CRM : planningId envoyé', () {
      final c = corpsVisite(_visite(planningId: _planning), idApk: 'Vabc');
      expect(c['planningId'], _planning);
      expect(erreursCorpsVisite(c), isEmpty);
    });

    test('visite hors planning : pas de planningId', () {
      final c = corpsVisite(_visite(), idApk: 'Vabc');
      expect(c.containsKey('planningId'), isFalse);
    });

    test(
      "un identifiant d'étape qui n'est pas un UUID (démo) n'est pas envoyé",
      () {
        final c = corpsVisite(_visite(planningId: 'v3'), idApk: 'Vabc');
        expect(c.containsKey('planningId'), isFalse);
        expect(erreursCorpsVisite(c), isEmpty);
      },
    );

    test('« commande en rayon » non répondue : champ absent', () {
      const v = Visite(
        id: 'v1',
        num: 1,
        magasinId: _client,
        par: 'x',
        etat: EtatVisite.terminee,
        date: '',
        age: 0,
        chrono: {},
        photos: {},
      );
      final c = corpsVisite(v, idApk: 'Vabc');
      expect(c.containsKey('commandeEnRayon'), isFalse);
      expect(c.containsKey('etapes'), isFalse);
      expect(erreursCorpsVisite(c), isEmpty);
    });
  });

  group('corpsVisite PEM', () {
    test('typeVisite PEM, proposition réalisée et articles relevés', () {
      final c = corpsVisite(_visite(type: TypeVisite.pem), idApk: 'Vabc');
      expect(erreursCorpsVisite(c), isEmpty);
      expect(c['typeVisite'], 'PEM');
      expect(c['propositionPemId'], _prop);
      // Un article absent n'est jamais « mis en avant ».
      expect(c['articlesPem'], [
        {'articleId': _art1, 'present': true, 'misEnAvant': true},
        {'articleId': _art2, 'present': false, 'misEnAvant': false},
      ]);
      expect(c.containsKey('indispensables'), isFalse);
    });
  });

  group('corps de commande validée', () {
    test('POST /commandes/apk en statut VALIDEE, conforme au DTO', () {
      const cmd = CommandeEnCours(
        magasinId: _client,
        lignes: [LigneCommande(_art1, 12), LigneCommande(_art2, 0)],
        note: ' Prévenir le chef de rayon ',
        pas: true,
        dateMin: '2026-12-01',
        motifPas: 'Impératif',
      );
      final c = corpsCreation(
        cmd,
        idApk: 'AbC123xYz9',
        maintenant: DateTime.utc(2026, 11, 23, 9, 30),
        prixDe: (id) => id == _art1 ? 22.62 : null,
        statut: 'VALIDEE',
      );
      expect(erreursCorpsCommande(c), isEmpty);
      expect(c['statut'], 'VALIDEE');
      expect(c['idCommandeApk'], 'AbC123xYz9');
      expect(c['clientId'], _client);
      expect(c['dateCommande'], '2026-11-23T09:30:00.000Z');
      expect(c['commentaire'], 'Prévenir le chef de rayon');
      expect(c['nePasLivrerAvant'], '2026-12-01');
      expect(c['motifNePasLivrerAvant'], 'Impératif');
      expect(c['lignes'], [
        {'articleId': _art1, 'quantite': 12, 'prixIndicatif': 22.62},
      ]);
    });

    test('la mise en attente reste en EN_ATTENTE par défaut', () {
      const cmd = CommandeEnCours(
        magasinId: _client,
        lignes: [LigneCommande(_art1, 1)],
      );
      final c = corpsCreation(
        cmd,
        idApk: 'AbC123xYz9',
        maintenant: DateTime.utc(2026, 11, 23),
        prixDe: (_) => null,
      );
      expect(c['statut'], 'EN_ATTENTE');
    });
  });
}
