import 'package:crm_app/core/data/referentiels_visite.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

final _auj = DateTime(2026, 11, 16);

Magasin _magasin({
  String id = 'c1',
  String nom = 'Auchan – Rouen',
  String classe = 'A',
  String evo = '',
}) => Magasin(
  id: id,
  nom: nom,
  statut: 'Client actif',
  classe: classe,
  adresse: '',
  ca: '—',
  evo: evo,
  cde: '—',
  cdeDate: '',
  visites: 0,
  objectif: 0,
  reel: true,
);

PromoOp _promo(String id, {DateTime? debut, DateTime? fin}) =>
    PromoOp(id: id, libelle: 'Promo $id', debut: debut, fin: fin);

Alerte _alerte({
  String? magasinId,
  String icone = '📍',
  String titre = 'T',
  String detail = 'D',
  NiveauAlerte niveau = NiveauAlerte.moy,
}) => Alerte(
  niveau: niveau,
  magasinId: magasinId,
  icone: icone,
  titre: titre,
  classe: '',
  detail: detail,
  rang: 10,
);

void main() {
  group('objectif du mois', () {
    test('taux d’atteinte arrondi, 0 sans objectif', () {
      expect(tauxAtteinte(1250, 2000), 63);
      expect(tauxAtteinte(2400, 2000), 120);
      expect(tauxAtteinte(500, 0), 0);
    });

    test('l’objectif mensuel est le douzième de l’objectif annuel', () {
      expect(objectifMensuel(24000), 2000);
      expect(objectifMensuel(null), isNull);
      expect(objectifMensuel(0), isNull);
    });

    test('CA du mois sur objectif mensuel ; nul si l’un des deux manque', () {
      final o = objectifDuMois(caMois: 1500, objectifAnnuel: 24000)!;
      expect(o.ca, 1500);
      expect(o.objectif, 2000);
      expect(o.taux, 75);
      expect(objectifDuMois(caMois: null, objectifAnnuel: 24000), isNull);
      expect(objectifDuMois(caMois: 1500, objectifAnnuel: null), isNull);
    });
  });

  group('operationsBriefing', () {
    test('en cours avant à venir, terminées écartées', () {
      final ops = operationsBriefing([
        _promo('venir-tard', debut: DateTime(2026, 12, 20)),
        _promo(
          'finie',
          debut: DateTime(2026, 10, 1),
          fin: DateTime(2026, 11, 15),
        ),
        _promo(
          'venir',
          debut: DateTime(2026, 11, 20),
          fin: DateTime(2026, 12, 5),
        ),
        _promo(
          'cours-longue',
          debut: DateTime(2026, 11, 1),
          fin: DateTime(2026, 12, 31),
        ),
        _promo('cours-courte', fin: DateTime(2026, 11, 18)),
      ], _auj);
      expect(ops.map((o) => o.nom), [
        'Promo cours-courte',
        'Promo cours-longue',
        'Promo venir',
        'Promo venir-tard',
      ]);
      expect(ops.map((o) => o.etat), [
        EtatOp.enCours,
        EtatOp.enCours,
        EtatOp.aVenir,
        EtatOp.aVenir,
      ]);
    });

    test('une promotion qui finit aujourd’hui est encore en cours', () {
      final ops = operationsBriefing([_promo('a', fin: _auj)], _auj);
      expect(ops.single.etat, EtatOp.enCours);
    });

    test('sans date de fin, elle passe après celles qui ont une fin', () {
      final ops = operationsBriefing([
        _promo('sans'),
        _promo('avec', fin: DateTime(2026, 12, 1)),
      ], _auj);
      expect(ops.map((o) => o.nom), ['Promo avec', 'Promo sans']);
    });

    test('dates mises en forme', () {
      final op = operationsBriefing([
        _promo('a', debut: DateTime(2026, 11, 2), fin: DateTime(2026, 11, 30)),
      ], _auj).single;
      expect(op.du, '2 nov.');
      expect(op.au, '30 nov.');
      expect(periodeOperation(op), '2 nov. → 30 nov.');
    });

    test('liste vide, période partielle', () {
      expect(operationsBriefing(const [], _auj), isEmpty);
      expect(
        periodeOperation(
          const OperationPromo('x', '', '30 nov.', EtatOp.enCours),
        ),
        'jusqu’au 30 nov.',
      );
      expect(
        periodeOperation(
          const OperationPromo('x', '2 nov.', '', EtatOp.aVenir),
        ),
        'à partir du 2 nov.',
      );
      expect(
        periodeOperation(const OperationPromo('x', '', '', EtatOp.enCours)),
        '',
      );
    });

    test(
      'opérations de démonstration : terminées écartées, en cours d’abord',
      () {
        final ops = operationsAVenir(const [
          OperationPromo('b', '', '', EtatOp.aVenir),
          OperationPromo('c', '', '', EtatOp.terminee),
          OperationPromo('a', '', '', EtatOp.enCours),
        ]);
        expect(ops.map((o) => o.nom), ['a', 'b']);
      },
    );
  });

  group('alertes du magasin', () {
    test('périodicité du CRM en jours', () {
      expect(joursPeriodicite('2 fois par semaine'), 4);
      expect(joursPeriodicite('1 fois par semaine'), 7);
      expect(joursPeriodicite('Toutes les 2 semaines'), 14);
      expect(joursPeriodicite('Toutes les 3 semaines'), 21);
      expect(joursPeriodicite('1 fois par mois'), 30);
      expect(joursPeriodicite('Trimestriel'), 90);
      expect(joursPeriodicite('?'), isNull);
      expect(joursPeriodicite(null), isNull);
    });

    test('visite en retard selon la périodicité, sinon la classe', () {
      final m = _magasin();
      final a = alerteVisiteEnRetard(
        m,
        derniereVisite: DateTime(2026, 10, 20),
        periodicite: '2 semaines',
        auj: _auj,
      )!;
      expect(
        a.detail,
        'Pas visité depuis 27 jours · visite attendue tous les 14 jours',
      );
      expect(a.icone, '📍');
      expect(
        alerteVisiteEnRetard(
          m,
          derniereVisite: DateTime(2026, 11, 10),
          periodicite: '2 semaines',
          auj: _auj,
        ),
        isNull,
      );
      // sans périodicité : classe A = 14 jours
      expect(
        alerteVisiteEnRetard(
          m,
          derniereVisite: DateTime(2026, 11, 5),
          periodicite: null,
          auj: _auj,
        ),
        isNull,
      );
      expect(
        alerteVisiteEnRetard(
          m,
          derniereVisite: DateTime(2026, 10, 1),
          periodicite: null,
          auj: _auj,
        )!.detail,
        contains('tous les 14 jours'),
      );
      // jamais visité ou fréquence inconnue : pas d'alerte inventée
      expect(
        alerteVisiteEnRetard(
          m,
          derniereVisite: null,
          periodicite: null,
          auj: _auj,
        ),
        isNull,
      );
      expect(
        alerteVisiteEnRetard(
          _magasin(classe: '—'),
          derniereVisite: DateTime(2025, 1, 1),
          periodicite: null,
          auj: _auj,
        ),
        isNull,
      );
    });

    test('livraisons : en retard, du jour, à venir ignorée', () {
      final l = alertesLivraison(_magasin(), [
        LivraisonAttendue(numero: 'CDE-1', prevue: DateTime(2026, 11, 12)),
        LivraisonAttendue(numero: 'CDE-2', prevue: DateTime(2026, 11, 16, 14)),
        LivraisonAttendue(numero: 'CDE-3', prevue: DateTime(2026, 11, 20)),
        const LivraisonAttendue(numero: 'CDE-4'),
      ], _auj);
      expect(l.map((a) => a.detail), [
        'Livraison en retard : commande CDE-1 prévue le 12 nov.',
        "Livraison prévue aujourd'hui : commande CDE-2",
      ]);
      expect(l.first.niveau, NiveauAlerte.haut);
      expect(l.last.niveau, NiveauAlerte.moy);
    });

    test('client en baisse : variation négative seulement', () {
      expect(alerteBaisse(_magasin(), -14)!.detail, contains('-14 %'));
      expect(alerteBaisse(_magasin(), 0), isNull);
      expect(alerteBaisse(_magasin(), 8), isNull);
      expect(alerteBaisse(_magasin(), null), isNull);
    });

    test('variation du CA et lecture du libellé de démonstration', () {
      expect(variationCa(900, 1000), -10);
      expect(variationCa(1100, 1000), 10);
      expect(variationCa(100, 0), isNull);
      expect(variationCa(null, 100), isNull);
      expect(variationDepuisLibelle('−14 %'), -14);
      expect(variationDepuisLibelle('+3 %'), 3);
      expect(variationDepuisLibelle(''), isNull);
    });

    test(
      'filtre des alertes de la cloche : celles du magasin et ses notifications',
      () {
        final m = _magasin();
        final liste = alertesDuMagasin([
          _alerte(magasinId: 'c1', detail: 'visite'),
          _alerte(magasinId: 'c2', detail: 'autre magasin'),
          _alerte(
            icone: '💬',
            titre: 'Relance visite',
            detail:
                "Julie · AUCHAN — ROUEN : la visite du 10 nov. n'a pas été effectuée.",
          ),
          _alerte(
            icone: '💬',
            titre: 'Relance visite',
            detail: 'Julie · AUCHAN — LILLE : la visite du 10 nov.',
          ),
          _alerte(
            icone: '💬',
            titre: 'Relance',
            detail: 'Mettez à jour votre planning',
          ),
        ], m);
        expect(liste, hasLength(2));
        expect(liste.first.detail, 'visite');
        expect(liste.last.detail, contains('ROUEN'));
      },
    );

    test('briefing : cloche + CRM, visite non doublée, urgentes d’abord', () {
      final m = _magasin();
      final donnees = DonneesMagasin(
        derniereVisite: DateTime(2026, 10, 1),
        periodicite: '2 semaines',
        livraisons: [
          LivraisonAttendue(numero: 'CDE-1', prevue: DateTime(2026, 11, 12)),
        ],
        variationCaPct: -20,
      );
      final sans = alertesBriefing(
        magasin: m,
        cloche: const [],
        donnees: donnees,
        auj: _auj,
      );
      // la livraison en retard (urgente) passe en tête
      expect(sans.map((a) => a.icone), ['🚚', '📍', '📉']);

      // la visite en retard du CRM remplace celle que la cloche déduit des visites de l'appli
      final avec = alertesBriefing(
        magasin: m,
        cloche: [_alerte(magasinId: 'c1', detail: 'cloche')],
        donnees: donnees,
        auj: _auj,
      );
      expect(avec.where((a) => a.icone == '📍'), hasLength(1));
      expect(
        avec.singleWhere((a) => a.icone == '📍').detail,
        contains('46 jours'),
      );

      // sans date de visite du CRM, l'alerte de la cloche reste
      final sansDate = alertesBriefing(
        magasin: m,
        cloche: [_alerte(magasinId: 'c1', detail: 'cloche')],
        donnees: const DonneesMagasin(),
        auj: _auj,
      );
      expect(sansDate.single.detail, 'cloche');
    });

    test('briefing sans donnée : aucune alerte', () {
      expect(
        alertesBriefing(magasin: _magasin(), cloche: const [], auj: _auj),
        isEmpty,
      );
    });

    test('briefing d’un client de démonstration : baisse lue dans « évo »', () {
      final l = alertesBriefing(
        magasin: _magasin(evo: '−14 %'),
        cloche: const [],
        auj: _auj,
      );
      expect(l.single.detail, contains('-14 %'));
    });

    test('BriefingMagasin vide', () {
      expect(const BriefingMagasin().vide, isTrue);
      expect(BriefingMagasin(alertes: [_alerte()]).vide, isFalse);
    });
  });
}
