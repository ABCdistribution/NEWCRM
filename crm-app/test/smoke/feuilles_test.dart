import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/shell/shell_screen.dart';
import 'package:crm_app/features/visites/kilometrage_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_support.dart';

/// Une feuille ou un dialogue de la maquette, son appel `AppRoutes` et un texte qu'il doit afficher.
class _Cas {
  const _Cas(this.modale, this.ouvrir, this.texte);

  /// Type de la modale dans la maquette (`S.modale.type`).
  final String modale;
  final Future<void> Function(BuildContext) ouvrir;
  final String texte;
}

/// Chaque feuille et dialogue de `docs/ECRANS.md` §3 doit avoir une fonction `AppRoutes` qui l'ouvre, et afficher son
/// vrai titre (celui de la maquette : nom du kit, du produit, semaine du rapport…).
final List<_Cas> _cas = [
  _Cas('cloche', AppRoutes.alertes, 'Alertes clients'),
  _Cas('formulaire', (c) => AppRoutes.formulaireRdv(c), 'Nouveau RDV'),
  _Cas(
    'slivraison',
    (c) => AppRoutes.detailLivraison(c, 'CDE-2041'),
    'CDE-2041 · E.Leclerc – Paris',
  ),
  _Cas('mfiltres', AppRoutes.filtresClients, 'Filtres'),
  _Cas('note', (c) => AppRoutes.noteClient(c, 'm1'), 'Nouvelle note'),
  _Cas(
    'feuille-etape',
    (c) => AppRoutes.changerEtapeProspect(c, 'p1'),
    "Changer d'étape",
  ),
  _Cas(
    'confirm',
    (c) => AppRoutes.passerEnClient(c, 'p1'),
    'Passer en client ?',
  ),
  _Cas('note', (c) => AppRoutes.noteProspect(c, 'p1'), 'Nouvelle note'),
  _Cas('pv-filtres', AppRoutes.filtresProspects, 'Filtres'),
  _Cas(
    'rapport-detail',
    (c) => AppRoutes.detailRapport(c, 45),
    'Semaine 45 · 2 – 6 novembre',
  ),
  _Cas(
    'sec-filtres',
    (c) => AppRoutes.filtresSecteur(c, GenreSecteur.visites),
    'Filtres',
  ),
  _Cas(
    'sec-client',
    (c) => AppRoutes.choixClientSecteur(c, GenreSecteur.commandes),
    'Choisir un client',
  ),
  _Cas('eq-filtres', AppRoutes.filtresEquipe, 'Filtres'),
  _Cas(
    'cs-filtres',
    (c) => AppRoutes.filtresSemainesChefSecteur(c, 'n'),
    'Filtrer les semaines',
  ),
  _Cas('vfiltres', AppRoutes.filtresVisites, 'Filtres'),
  _Cas(
    'km',
    (c) => AppRoutes.kilometrage(c, PhaseKilometrage.depart),
    'Kilométrage de départ',
  ),
  _Cas('kits', (c) => AppRoutes.kitsDuRayon(c, 'd0'), 'Kits du rayon'),
  _Cas(
    'kit-detail',
    (c) => AppRoutes.detailKit(c, 'COSMIA-01'),
    'COSMIA ZIPPED PLANE KIT',
  ),
  _Cas(
    'svalider',
    (c) => AppRoutes.validerVisite(c, 'd0'),
    'Valider la visite ?',
  ),
  _Cas('cfiltres', AppRoutes.filtresCommandes, 'Filtres'),
  _Cas('cmd-pas', AppRoutes.nePasLivrerAvant, 'Ne pas livrer avant…'),
  _Cas('cmd-scan', AppRoutes.scannerProduit, 'Scanner un produit'),
  _Cas('cmd-filtres', AppRoutes.filtresPriseCommande, 'Filtres'),
  _Cas(
    'cmd-remp',
    (c) => AppRoutes.produitsRemplacement(c, 'a13'),
    'Produits de remplacement',
  ),
  _Cas('sfiltres', AppRoutes.filtresCatalogue, 'Filtres'),
  _Cas(
    'sproduit',
    (c) => AppRoutes.ficheProduit(c, 'a1'),
    'Shampooing doux usage fréquent',
  ),
  _Cas('news', (c) => AppRoutes.detailNews(c, 'n1'), 'Nouveautés HQ Mai'),
];

/// Laisse finir les animations. « Scanner un produit » (`cmd-scan`) a une ligne de scan qui va et vient sans fin :
/// `pumpAndSettle` n'y arriverait jamais, on avance donc le temps d'une durée fixe.
Future<void> _laisserFinir(WidgetTester tester, _Cas cas) async {
  if (cas.modale == 'cmd-scan') {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'toutes les feuilles et dialogues de la maquette s’ouvrent (AppRoutes)',
    (tester) async {
      await lancerApp(tester, Role.dir);
      BuildContext ctx() =>
          tester.element(find.byType(ShellScreen, skipOffstage: false));

      for (final cas in _cas) {
        final futur = cas.ouvrir(ctx());
        await _laisserFinir(tester, cas);
        expect(
          // `findRichText` : le titre des alertes est un texte riche (titre + pastille du nombre).
          find.textContaining(cas.texte, findRichText: true),
          findsWidgets,
          reason: 'modale « ${cas.modale} » : texte « ${cas.texte} »',
        );
        expect(tester.takeException(), isNull, reason: cas.modale);
        await tester.tapAt(const Offset(195, 20)); // le voile ferme la feuille
        await _laisserFinir(tester, cas);
        await futur;
        // La modale s'est bien refermée : plus de feuille ni de dialogue à l'écran.
        expect(find.byType(FeuilleBase), findsNothing, reason: cas.modale);
        expect(find.byType(DialogueBase), findsNothing, reason: cas.modale);
      }
    },
  );
}
