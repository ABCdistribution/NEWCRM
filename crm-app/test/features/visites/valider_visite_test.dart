import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/visites/state/actions_visite.dart';
import 'package:crm_app/features/visites/state/kilometrage.dart';
import 'package:crm_app/features/visites/visite_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_visites.dart';

Visite visite(WidgetTester tester, String id) =>
    storeApp(tester).visites.firstWhere((v) => v.id == id);

/// Parcourt les étapes avec « Suivant » puis touche « ✓ Terminer la visite » (la visite doit être complète).
Future<void> ouvrirValidation(WidgetTester tester) => terminerLeParcours(tester);

void main() {
  group('Valider la visite (svalider l.1397-1400, v-valider-ok l.1562-1567)', () {
    testWidgets('visite incomplète : ce qui reste à faire, au fil des étapes', (
      tester,
    ) async {
      final id = await demarrerVisiteChez(tester, Role.promoteur, 'm1');
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      AppRoutes.validerVisite(contexteCoquille(tester), id);
      await tester.pumpAndSettle();
      expect(find.text('Visite incomplète'), findsOneWidget);
      expect(find.text('Il reste à faire :'), findsOneWidget);
      // sans photo d'arrivée, sans photo du rayon, sans réponse sur la commande à mettre en rayon
      expect(find.byType(MessageErreur), findsNWidgets(3));
      expect(find.text("Prenez la photo d'arrivée sur site."), findsOneWidget);
      expect(find.text('Prenez la photo du rayon.'), findsOneWidget);
      expect(
        find.text("Indiquez s'il y a une commande à mettre en rayon."),
        findsOneWidget,
      );
      expect(find.text('Valider'), findsNothing);

      // la liste suit la visite : une fois tout renseigné, le dialogue propose de valider
      final actions = ActionsVisite(
        conteneurApp(tester).read(crmProvider.notifier),
        id,
      );
      actions.ajouterPhoto(EtapeDph.arrivee);
      await tester.pumpAndSettle();
      expect(find.byType(MessageErreur), findsNWidgets(2));
      actions.ajouterPhoto(EtapeDph.rayonArrivee);
      actions.definirCommandeEnRayon(oui: false);
      await tester.pumpAndSettle();
      expect(find.byType(MessageErreur), findsNothing);
      expect(find.text('Valider la visite ?'), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);
      expect(visite(tester, id).etat, EtatVisite.brouillon);
    });

    testWidgets(
      'visite complète : « Valider la visite ? », « Continuer » la laisse en brouillon',
      (tester) async {
        final id = await demarrerVisiteChez(tester, Role.promoteur, 'm1');
        await tester.tap(find.text('Plus tard'));
        await tester.pumpAndSettle();
        completerVisite(tester, id);
        await tester.pumpAndSettle();
        await ouvrirValidation(tester);
        expect(find.text('Valider la visite ?'), findsOneWidget);
        expect(
          find.text(
            "La visite est complète. Une fois validée, elle part dès que le réseau le permet et n'est plus modifiable.",
          ),
          findsOneWidget,
        );
        expect(find.text('Continuer'), findsOneWidget);
        expect(find.text('Valider'), findsOneWidget);
        expect(find.byType(MessageErreur), findsNothing);
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
        expect(find.text('Valider la visite ?'), findsNothing);
        expect(find.byType(VisiteScreen), findsOneWidget);
        expect(visite(tester, id).etat, EtatVisite.brouillon);
      },
    );

    testWidgets(
      'promoteur : valider termine la visite, revient à l’accueil, puis l’envoie',
      (tester) async {
        final id = await demarrerVisiteChez(tester, Role.promoteur, 'm1');
        await tester.tap(find.text('Plus tard'));
        await tester.pumpAndSettle();
        completerVisite(tester, id);
        await tester.pumpAndSettle();
        await ouvrirValidation(tester);
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Visite #218093 validée. Envoi dès que le réseau le permet.',
          ),
          findsOneWidget,
        );
        var v = visite(tester, id);
        expect(v.etat, EtatVisite.terminee);
        // 9 étapes déjà horodatées : la réception prend le 9e pas de l'horloge de la démo
        expect(v.recu, '04/11/2026 14h59');
        expect(find.byType(VisiteScreen), findsNothing);
        expect(find.text('Bonjour Julien'), findsOneWidget);
        expect(conteneurApp(tester).read(ongletProvider), OngletApp.accueil);
        // la tournée n'est pas finie (il reste Boulogne) : pas de kilométrage d'arrivée
        expect(find.text("Kilométrage d'arrivée"), findsNothing);

        // 3,5 s plus tard la visite est envoyée, et un message le dit
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        v = visite(tester, id);
        expect(v.etat, EtatVisite.envoyee);
        expect(find.text('Visite envoyée au serveur.'), findsOneWidget);
        await attendreToast(tester);
        expect(find.text('Visite envoyée au serveur.'), findsNothing);
      },
    );

    testWidgets(
      'la visite validée apparaît dans l’onglet Visites avec sa pastille',
      (tester) async {
        final id = await demarrerVisiteChez(tester, Role.promoteur, 'm1');
        await tester.tap(find.text('Plus tard'));
        await tester.pumpAndSettle();
        completerVisite(tester, id);
        await tester.pumpAndSettle();
        await ouvrirValidation(tester);
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();
        await tester.tap(ongletNav('Visites'));
        await tester.pumpAndSettle();
        expect(find.text('Mes visites · 5 résultats'), findsOneWidget);
        expect(find.text('À envoyer'), findsOneWidget);
        expect(find.text('4 nov. 14:23'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text('À envoyer'), findsNothing);
        expect(find.text('Envoyée'), findsNWidgets(5));
      },
    );

    testWidgets(
      'la dernière visite de la tournée propose le kilométrage d’arrivée',
      (tester) async {
        // tournée du promoteur : Ivry (déjà visité), Versailles, Boulogne
        final premier = await demarrerVisiteChez(tester, Role.promoteur, 'm1');
        await tester.tap(find.text('Plus tard'));
        await tester.pumpAndSettle();
        completerVisite(tester, premier);
        await tester.pumpAndSettle();
        await ouvrirValidation(tester);
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();
        expect(find.text("Kilométrage d'arrivée"), findsNothing);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        AppRoutes.demarrerVisite(contexteCoquille(tester), 'm8');
        await tester.pumpAndSettle();
        final second = storeApp(tester).visites.first.id;
        completerVisite(tester, second);
        await tester.pumpAndSettle();
        await ouvrirValidation(tester);
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();
        expect(find.text("Kilométrage d'arrivée"), findsOneWidget);
        expect(
          find.text(
            'Visite #218094 validée. Envoi dès que le réseau le permet.',
          ),
          findsOneWidget,
        );
        expect(
          conteneurApp(tester).read(kilometrageProvider).arriveePropose,
          isTrue,
        );
        await tester.tap(find.text('Plus tard'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(visite(tester, second).etat, EtatVisite.envoyee);
      },
    );

    testWidgets(
      'chef de secteur : valider revient à son onglet, sans kilométrage ni message d’envoi',
      (tester) async {
        final id = await demarrerVisiteChez(tester, Role.cs, 'm1');
        completerVisite(tester, id);
        await tester.pumpAndSettle();
        await ouvrirValidation(tester);
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Visite #218093 validée. Envoi dès que le réseau le permet.',
          ),
          findsOneWidget,
        );
        expect(find.byType(VisiteScreen), findsNothing);
        expect(find.text("Kilométrage d'arrivée"), findsNothing);
        expect(visite(tester, id).etat, EtatVisite.terminee);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(visite(tester, id).etat, EtatVisite.envoyee);
        expect(find.text('Visite envoyée au serveur.'), findsNothing);
      },
    );

    testWidgets('changer de profil annule l’envoi en attente', (tester) async {
      final id = await demarrerVisiteChez(tester, Role.promoteur, 'm1');
      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      completerVisite(tester, id);
      await tester.pumpAndSettle();
      await ouvrirValidation(tester);
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      conteneurApp(tester).read(roleProvider.notifier).choisir(Role.dir);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Visite envoyée au serveur.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('le dialogue n’existe pas pour une visite inconnue', (
      tester,
    ) async {
      await lancerApp(tester, Role.promoteur);
      AppRoutes.validerVisite(contexteCoquille(tester), 'inconnue');
      await tester.pumpAndSettle();
      expect(find.byType(DialogueBase), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
