import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/visites/state/filtres_visites.dart';
import 'package:crm_app/features/visites/visites_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Conteneur Riverpod d'un écran monté par `pumpEcran`.
ProviderContainer conteneurEcran(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(VisitesScreen)));

/// Nombre de cartes de visite affichées (une pastille d'état par carte, hors pastilles de classe du client).
int nbCartes(WidgetTester tester) => tester
    .widgetList<Pastille>(find.byType(Pastille))
    .where((p) => p.variante != VariantePastille.client)
    .length;

void main() {
  group('Onglet « Visites » du promoteur (salesVisites l.1180-1186)', () {
    testWidgets('entête, recherche et visites du promoteur puis des autres', (
      tester,
    ) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
      expect(find.text('Visites'), findsOneWidget);
      expect(find.text('Mes visites · 4 résultats'), findsOneWidget);
      expect(find.text('Client…'), findsOneWidget);
      // d0 puis les trois visites de Julien M. restées dans la liste des autres (x0, x1, x2).
      expect(find.text('Carrefour – Ivry-sur-Seine'), findsNWidgets(2));
      expect(find.text('4 nov. 09:30'), findsOneWidget);
      expect(find.text('3 nov. 10:00'), findsOneWidget);
      expect(find.text('Carrefour Market – Versailles'), findsOneWidget);
      expect(find.text('20 oct. 14:30'), findsOneWidget);
      expect(find.text('U Express – Boulogne-Billancourt'), findsOneWidget);
      expect(find.text('10 oct. 09:15'), findsOneWidget);
      expect(find.text('Envoyée'), findsNWidgets(4));
      // La classe du client s'affiche à côté de son nom quand elle est connue.
      expect(find.text('A++'), findsWidgets);
      expect(find.textContaining('par '), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Toutes les visites » ajoute celles des autres promoteurs', (
      tester,
    ) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
      conteneurEcran(tester)
          .read(filtresVisitesProvider.notifier)
          .maj((f) => f.avecPortee(PorteeVisites.toutes));
      await tester.pumpAndSettle();
      expect(
        find.text('Toutes les visites sur vos clients · 5 résultats'),
        findsOneWidget,
      );
      expect(find.text('12 oct. 11:00 · par Amine K.'), findsOneWidget);
      expect(nbCartes(tester), 5);
    });

    testWidgets('la recherche filtre sur le client et sur le promoteur', (
      tester,
    ) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
      conteneurEcran(tester)
          .read(filtresVisitesProvider.notifier)
          .maj((f) => f.avecPortee(PorteeVisites.toutes));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'versailles');
      await tester.pumpAndSettle();
      expect(
        find.text('Toutes les visites sur vos clients · 2 résultats'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), 'AMINE');
      await tester.pumpAndSettle();
      expect(
        find.text('Toutes les visites sur vos clients · 1 résultat'),
        findsOneWidget,
      );
      expect(find.text('12 oct. 11:00 · par Amine K.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Aucune visite pour ces filtres.'), findsOneWidget);
      expect(
        find.text('Toutes les visites sur vos clients · 0 résultat'),
        findsOneWidget,
      );
    });

    testWidgets('le bouton de filtres compte les filtres actifs', (
      tester,
    ) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
      expect(
        tester.widget<BoutonFiltre>(find.byType(BoutonFiltre)).nbFiltres,
        0,
      );
      conteneurEcran(tester)
          .read(filtresVisitesProvider.notifier)
          .maj(
            (f) => f
                .avecPortee(PorteeVisites.toutes)
                .avecEtat(EtatVisite.terminee)
                .avecPeriode(PeriodeVisites.jour)
                .avecRecherche('x'),
          );
      await tester.pumpAndSettle();
      // la recherche ne compte pas
      expect(
        tester.widget<BoutonFiltre>(find.byType(BoutonFiltre)).nbFiltres,
        3,
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('période « Aujourd’hui » et « 7 derniers jours »', (
      tester,
    ) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
      final notifier = conteneurEcran(
        tester,
      ).read(filtresVisitesProvider.notifier);
      notifier.maj(
        (f) =>
            f.avecPortee(PorteeVisites.toutes).avecPeriode(PeriodeVisites.jour),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Toutes les visites sur vos clients · 1 résultat'),
        findsOneWidget,
      );
      expect(find.text('4 nov. 09:30'), findsOneWidget);
      // âges : x0 = 1 jour (3 nov.), x1 = 15, x2 = 25, x3 = 23
      notifier.maj((f) => f.avecPeriode(PeriodeVisites.semaine));
      await tester.pumpAndSettle();
      expect(
        find.text('Toutes les visites sur vos clients · 2 résultats'),
        findsOneWidget,
      );
      expect(find.text('3 nov. 10:00'), findsOneWidget);
    });

    testWidgets(
      'filtre d’état : aucune visite « À envoyer » ni « Brouillon »',
      (tester) async {
        await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
        conteneurEcran(tester)
            .read(filtresVisitesProvider.notifier)
            .maj((f) => f.avecEtat(EtatVisite.terminee));
        await tester.pumpAndSettle();
        expect(find.text('Aucune visite pour ces filtres.'), findsOneWidget);
        expect(find.text('Mes visites · 0 résultat'), findsOneWidget);
      },
    );

    testWidgets('une visite à envoyer et un brouillon ont leur pastille', (
      tester,
    ) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
      final conteneur = conteneurEcran(tester);
      final id = conteneur.read(crmProvider.notifier).demarrerVisite('m1');
      conteneur
          .read(crmProvider.notifier)
          .majVisite('d0', (v) => v.copyWith(etat: EtatVisite.terminee));
      await tester.pumpAndSettle();
      expect(find.text('Brouillon'), findsOneWidget);
      expect(find.text('À envoyer'), findsOneWidget);
      expect(find.text('Mes visites · 5 résultats'), findsOneWidget);
      expect(id, 'v218093');
      expect(find.text('4 nov. 14:23'), findsOneWidget);
    });

    testWidgets(
      'une visite du promoteur s’ouvre, celle d’un autre en lecture seule',
      (tester) async {
        await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
        await tester.tap(find.text('4 nov. 09:30'));
        await tester.pumpAndSettle();
        expect(find.text('Visite #218082'), findsOneWidget);
        expect(
          find.text("Visite validée : elle n'est plus modifiable."),
          findsOneWidget,
        );
        await tester.tap(find.byType(BoutonRetour));
        await tester.pumpAndSettle();

        conteneurEcran(tester)
            .read(filtresVisitesProvider.notifier)
            .maj((f) => f.avecPortee(PorteeVisites.toutes));
        await tester.pumpAndSettle();
        await tester.tap(find.text('12 oct. 11:00 · par Amine K.'));
        await tester.pumpAndSettle();
        expect(find.text('Visite #218086'), findsOneWidget);
        expect(find.text('réalisée par Amine K.'), findsOneWidget);
        expect(
          find.text("Lecture seule : cette visite n'est pas la vôtre."),
          findsOneWidget,
        );
      },
    );

    testWidgets('changer de profil réinitialise les filtres', (tester) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.promoteur);
      final conteneur = conteneurEcran(tester);
      conteneur
          .read(filtresVisitesProvider.notifier)
          .maj((f) => f.avecPortee(PorteeVisites.toutes));
      expect(
        conteneur.read(filtresVisitesProvider).portee,
        PorteeVisites.toutes,
      );
      conteneur.read(roleProvider.notifier).choisir(Role.cs);
      expect(conteneur.read(filtresVisitesProvider).portee, PorteeVisites.mes);
    });
  });

  group('Onglet « Visites » vu par l’encadrement (placeholder et portée)', () {
    testWidgets('chef de secteur : visites de son secteur', (tester) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.cs);
      expect(find.text('Client ou promoteur…'), findsOneWidget);
      // d00 et d0 sont les siennes ; x0 à x5 sont sur ses clients.
      expect(find.text('Mes visites · 2 résultats'), findsOneWidget);
      expect(find.text('E.Leclerc – Paris'), findsOneWidget);
      conteneurEcran(tester)
          .read(filtresVisitesProvider.notifier)
          .maj((f) => f.avecPortee(PorteeVisites.toutes));
      await tester.pumpAndSettle();
      expect(
        find.text('Toutes les visites de votre secteur · 8 résultats'),
        findsOneWidget,
      );
      expect(find.text('3 nov. 10:00 · par Julien M.'), findsOneWidget);
      // les visites des clients de l'autre secteur (x6 à x9) n'y sont pas
      expect(find.textContaining('Léa P.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('directeur : toute sa région', (tester) async {
      await pumpEcran(tester, const VisitesScreen(), role: Role.dir);
      expect(find.text('Client ou promoteur…'), findsOneWidget);
      conteneurEcran(tester)
          .read(filtresVisitesProvider.notifier)
          .maj((f) => f.avecPortee(PorteeVisites.toutes));
      await tester.pumpAndSettle();
      expect(
        find.text('Toutes les visites de votre région · 12 résultats'),
        findsOneWidget,
      );
      conteneurEcran(tester)
          .read(filtresVisitesProvider.notifier)
          .maj((f) => f.avecEtat(EtatVisite.terminee));
      await tester.pumpAndSettle();
      expect(
        find.text('Toutes les visites de votre région · 1 résultat'),
        findsOneWidget,
      );
      expect(find.text('2 nov. 16:00 · par Léa P.'), findsOneWidget);
      expect(find.text('À envoyer'), findsOneWidget);
    });
  });
}
