import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

void main() {
  test('demarrerVisite crée un brouillon puis réutilise le même', () {
    final c = conteneurPour(Role.promoteur);
    final n = c.read(crmProvider.notifier);
    final id = n.demarrerVisite('m1');
    expect(id, 'v218093');
    var e = c.read(crmProvider);
    expect(e.visites.first.id, id);
    expect(e.visites.first.etat, EtatVisite.brouillon);
    expect(e.visites.first.par, 'Julien M.');
    expect(e.visites.first.etapeFaite(EtapeDph.debut), isTrue);
    expect(e.prochainNumVisite, 218094);
    expect(n.demarrerVisite('m1'), id);
    e = c.read(crmProvider);
    expect(
      e.visites.where((v) => v.etat == EtatVisite.brouillon),
      hasLength(1),
    );
  });

  test(
    'demarrerVisite garde le lien avec la visite planifiée du CRM (UUID)',
    () {
      const planning = '66666666-6666-4666-8666-666666666666';
      final c = conteneurPour(Role.promoteur);
      final n = c.read(crmProvider.notifier);
      // Identifiant de démonstration : ignoré.
      final id = n.demarrerVisite('m1', planningId: 'v3');
      expect(c.read(crmProvider).visites.first.planningId, isNull);
      // Reprise du brouillon depuis la tournée du CRM : le lien est acquis.
      expect(n.demarrerVisite('m1', planningId: planning), id);
      expect(c.read(crmProvider).visites.first.planningId, planning);
      // Visite démarrée ailleurs (fiche magasin) : le lien reste.
      expect(n.demarrerVisite('m1'), id);
      expect(c.read(crmProvider).visites.first.planningId, planning);
      // Nouveau brouillon depuis une étape du CRM.
      final autre = n.demarrerVisite('m2', planningId: planning);
      expect(
        c.read(crmProvider).visites.firstWhere((v) => v.id == autre).planningId,
        planning,
      );
    },
  );

  test('changerEtapeProspect met à jour statut, probabilité et timeline', () {
    final c = conteneurPour(Role.cs);
    final n = c.read(crmProvider.notifier);
    n.changerEtapeProspect('p1', StatutProspect.proposition);
    final p = c.read(crmProvider).prospectParId('p1')!;
    expect(p.statut, StatutProspect.proposition);
    expect(p.proba, 55);
    expect(p.timeline.first.titre, 'Étape → Proposition');
    expect(
      p.timeline.first.detail,
      'Passé de « En négociation » à « Proposition »',
    );
  });

  test('mutate : mutation générique', () {
    final c = conteneurPour(Role.dir);
    c.read(crmProvider.notifier).mutate((e) => e.copyWith(prospects: const []));
    expect(c.read(crmProvider).prospects, isEmpty);
    expect(c.read(prospectsProvider), isEmpty);
  });

  test('plannings composés par l’encadrement', () {
    final c = conteneurPour(Role.dir);
    final e = c.read(crmProvider);
    expect(e.planDe('Nadia H.'), same(e.etapes));
    final lea = e.planDe('Léa P.');
    expect(lea, hasLength(6));
    expect(lea.first.cible, CiblePlanning.client);
    expect(lea.first.ref, 'm3');
    expect(lea.first.fait, isTrue);

    c
        .read(crmProvider.notifier)
        .ajouterEtape(
          const EtapePlanning(
            id: 'n1',
            jour: 4,
            heure: '16:00',
            cible: CiblePlanning.libre,
            titre: 'Chez Marcel',
          ),
          pour: 'Léa P.',
        );
    expect(c.read(crmProvider).planDe('Léa P.'), hasLength(7));
    expect(c.read(crmProvider).etapes, hasLength(8));

    c.read(crmProvider.notifier).supprimerEtape('n1', pour: 'Léa P.');
    expect(c.read(crmProvider).planDe('Léa P.'), hasLength(6));
  });

  test('ajouterCommande et identifiant suivant', () {
    final c = conteneurPour(Role.promoteur);
    final n = c.read(crmProvider.notifier);
    expect(n.prochainIdCommande, 'CDE-2044');
    n.ajouterCommande(
      const Commande(
        id: 'CDE-2044',
        magasinId: 'm1',
        date: '4 nov.',
        ht: '100,00 €',
        lignes: 1,
        statut: StatutLivraison.pasLivree,
        eta: 'ven. 6 nov.',
        colis: 1,
        evenements: [EvenementTransport('Commande reçue', '4 nov. 14:23')],
        src: 'Appli',
        par: 'Julien M.',
      ),
    );
    expect(c.read(crmProvider).commandes.first.id, 'CDE-2044');
    expect(n.prochainIdCommande, 'CDE-2045');
    expect(c.read(commandeParIdProvider('CDE-2044')), isNotNull);
  });

  test('changer de profil réinitialise le store', () {
    final c = conteneurPour(Role.promoteur);
    c.read(crmProvider.notifier).demarrerVisite('m1');
    expect(c.read(crmProvider).visites, hasLength(2));
    c.read(roleProvider.notifier).choisir(Role.dir);
    expect(c.read(crmProvider).role, Role.dir);
    expect(c.read(crmProvider).visites, hasLength(2));
    expect(
      c.read(crmProvider).visites.any((v) => v.etat == EtatVisite.brouillon),
      isFalse,
    );
    expect(c.read(profilActifProvider).nom, 'Cindy R.');
  });

  test('retrouver un client hors portefeuille ou hors région', () {
    final c = conteneurPour(Role.promoteur);
    final e = c.read(crmProvider);
    expect(e.magasinParId('m1'), isNotNull);
    expect(e.magasinParId('m9'), isNotNull); // secteur du promoteur
    expect(e.magasinParId('m2'), isNull); // autre secteur
    expect(e.magasinParId('x3c')!.nom, 'Auchan – Rouen'); // hors région
  });
}
