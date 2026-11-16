import 'package:crm_app/core/data/commandes_serveur.dart';
import 'package:crm_app/core/data/magasins_demo.dart';
import 'package:crm_app/core/logic/logic.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/crm_etat.dart';
import 'package:flutter_test/flutter_test.dart';

Magasin _m(int i) => Magasin(
  id: 'c$i',
  nom: 'Client $i',
  statut: i.isEven ? 'Client actif' : 'Client inactif',
  classe: 'B',
  adresse: '',
  ca: '—',
  evo: '',
  cde: '—',
  cdeDate: '',
  visites: 0,
  objectif: 0,
  actif: i.isEven,
  reel: true,
);

void main() {
  test(
    'gros volumes réels : accès par id et alertes en quelques millisecondes',
    () {
      final clients = [for (var i = 0; i < 5000; i++) _m(i)];
      definirClientsServeur(clients);
      addTearDown(() => definirClientsServeur(null));
      final base = CrmEtat.initial(Role.cs);
      final cmds = [
        for (var i = 0; i < 1000; i++)
          commandeDepuisJson({
            'numero': 'CDE-$i',
            'client': {'id': 'c${i * 5}'},
            'statutLivraison': 'EN_PREPARATION',
          })!,
      ];
      final etat = base.copyWith(commandes: cmds);
      final t = Stopwatch()..start();
      expect(etat.commandesVisibles, hasLength(1000));
      for (var i = 0; i < 5000; i++) {
        expect(etat.magasinParId('c$i'), isNotNull);
      }
      final alertes = calculerAlertes(
        role: Role.cs,
        magasins: etat.magasins,
        prospects: etat.prospects,
        etapes: etat.etapes,
        visites: etat.visites,
        visitesAutres: etat.visitesAutres,
        commandes: etat.commandes,
        jour: 2,
      );
      t.stop();
      // Les clients inactifs réels ne produisent plus d'alerte inventée.
      expect(alertes.where((a) => a.icone == '💤'), isEmpty);
      expect(t.elapsedMilliseconds, lessThan(1500));
    },
  );
}
