import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/ui/ui.dart';
import 'package:crm_app/features/prospects/logic/vue_prospects.dart';
import 'package:crm_app/features/prospects/prospects_screen.dart';
import 'package:crm_app/features/prospects/state/prospects_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';

/// Page « Prospects » : maquette `pageProspects` l.697-715 et `prochaineAction` l.716-719.
/// Les nombres attendus viennent des 23 prospects de la maquette (12 pour le secteur s1 de Nadia H.).
ProviderContainer _store(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ProspectsScreen)));

/// Le compteur de la tuile d'un groupe du pipeline.
Finder _tuile(String groupe) => find.byKey(ValueKey('compteur-$groupe'));

/// Les quatre compteurs des tuiles, dans l'ordre À contacter, RDV pris, En négo, Référencé.
List<String> _compteurs(WidgetTester tester) => [
  for (final g in ['À contacter', 'RDV pris', 'En négo', 'Référencé'])
    tester
        .widget<Text>(
          find.descendant(of: _tuile(g), matching: find.byType(Text)),
        )
        .data!,
];

void main() {
  group('chef de secteur', () {
    testWidgets('« Mes prospects » : entête, tuiles, une seule carte', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.cs);
      // Entête : titre et sous-titre de la maquette.
      expect(
        find.text('Mes prospects'),
        findsNWidgets(2),
      ); // h1 et titre de section
      expect(
        find.text('1 point de vente · potentiel 180 k€/an'),
        findsOneWidget,
      );
      // Quatre tuiles : seul Super U – Versailles (« par Nadia H. ») est à elle, en négociation.
      expect(_compteurs(tester), ['0', '0', '1', '0']);
      expect(find.text('☰ Mes prospects'), findsOneWidget);
      expect(find.text('👥 Tout le secteur'), findsOneWidget);
      expect(find.text('Trié par potentiel'), findsOneWidget);
      // Carte du prospect : nom, classe, pastille, potentiel, prochaine action du planning (jeudi 10:00).
      expect(find.text('Super U – Versailles'), findsOneWidget);
      expect(find.text('Classe A'), findsOneWidget);
      expect(find.text('En négo'), findsNWidgets(2)); // tuile et pastille
      expect(find.text('Potentiel 180 k€/an'), findsOneWidget);
      expect(find.text('📅 RDV · Jeu 10:00'), findsOneWidget);
      expect(find.text('Carrefour – Paris'), findsNothing);
      // Bouton flottant.
      expect(find.text('＋ Nouveau prospect'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '« Tout le secteur » : 12 prospects triés par potentiel, avec le chef de secteur',
      (tester) async {
        await pumpEcran(tester, const ProspectsScreen(), role: Role.cs);
        await tester.tap(find.text('👥 Tout le secteur'));
        await tester.pumpAndSettle();
        expect(
          find.text('12 points de vente · potentiel 1140 k€/an'),
          findsOneWidget,
        );
        expect(_compteurs(tester), ['6', '2', '4', '0']);
        expect(find.text('Mon secteur'), findsOneWidget);
        // Chaque carte rappelle le chef de secteur après la classe.
        expect(find.text('Classe A · Nadia H.'), findsWidgets);
        // Tri par potentiel décroissant : Super U (180) avant E.Leclerc – Mantes (160), Intermarché – Évreux (65 k€) tout en bas.
        double y(String nom) => tester.getTopLeft(find.text(nom)).dy;
        expect(
          y('Super U – Versailles'),
          lessThan(y('E.Leclerc – Mantes-la-Jolie')),
        );
        expect(
          y('E.Leclerc – Mantes-la-Jolie'),
          lessThan(y('Carrefour HM – Barentin')),
        );
        // La prochaine action du planning n'apparaît que sur les prospects concernés.
        expect(find.text('📅 RDV · Mer 11:30'), findsOneWidget);
        expect(find.text('📅 RDV · Jeu 10:00'), findsOneWidget);
      },
    );

    testWidgets('une tuile filtre par groupe, la retoucher enlève le filtre', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.cs);
      await tester.tap(find.text('👥 Tout le secteur'));
      await tester.pumpAndSettle();
      await tester.tap(_tuile('RDV pris'));
      await tester.pumpAndSettle();
      expect(_store(tester).read(filtreGroupeProvider), GroupeProspect.rdvPris);
      // Les deux prospects « RDV pris » : Dreux (80 k€) avant Évreux (70 k€) ; les autres groupes disparaissent.
      expect(find.text('E.Leclerc – Dreux'), findsOneWidget);
      expect(find.text('Intermarché – Évreux'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('E.Leclerc – Dreux')).dy,
        lessThan(tester.getTopLeft(find.text('Intermarché – Évreux')).dy),
      );
      expect(find.text('Super U – Versailles'), findsNothing);
      // L'entête garde les nombres de toute la vue (les tuiles ne dépendent pas du filtre).
      expect(_compteurs(tester), ['6', '2', '4', '0']);
      await tester.tap(_tuile('RDV pris'));
      await tester.pumpAndSettle();
      expect(_store(tester).read(filtreGroupeProvider), isNull);
      expect(find.text('Super U – Versailles'), findsOneWidget);
    });

    testWidgets('une colonne vide affiche le message de la maquette', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.cs);
      await tester.tap(_tuile('Référencé'));
      await tester.pumpAndSettle();
      expect(find.text('Aucun prospect dans cette colonne.'), findsOneWidget);
      expect(find.text('Super U – Versailles'), findsNothing);
    });

    testWidgets(
      'le compteur d’une tuile rejoint sa nouvelle valeur en 450 ms',
      (tester) async {
        await pumpEcran(tester, const ProspectsScreen(), role: Role.cs);
        await tester.tap(find.text('👥 Tout le secteur'));
        await tester.pump(); // le compteur « À contacter » part de 0
        expect(_compteurs(tester)[0], '0');
        await tester.pump(const Duration(milliseconds: 225));
        final milieu = int.parse(_compteurs(tester)[0]);
        expect(
          milieu,
          inInclusiveRange(1, 5),
        ); // easeOutCubic : déjà bien avancé à mi-parcours
        await tester.pumpAndSettle();
        expect(_compteurs(tester)[0], '6');
      },
    );

    testWidgets('le bouton flottant ouvre « Nouveau prospect »', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.cs);
      await tester.tap(find.text('＋ Nouveau prospect'));
      await tester.pumpAndSettle();
      expect(find.text('* champs obligatoires'), findsOneWidget);
    });

    testWidgets('toucher une carte ouvre la fiche du prospect', (tester) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.cs);
      await tester.tap(find.text('Super U – Versailles'));
      await tester.pumpAndSettle();
      expect(find.text('Prospect · En négo'), findsOneWidget);
      expect(find.text('Étape de prospection'), findsOneWidget);
    });

    testWidgets('un prospect en attente d’envoi n’a pas de fiche', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.cs);
      _store(tester)
          .read(crmProvider.notifier)
          .majProspect('p1', (p) => p.copyWith(attente: true));
      await tester.pumpAndSettle();
      expect(find.text("📤 En attente d'envoi"), findsOneWidget);
      await tester.tap(find.text('Super U – Versailles'));
      await tester.pump();
      expect(
        find.text(
          "Ce prospect n'est pas encore envoyé : sa fiche s'ouvrira dès son envoi.",
        ),
        findsOneWidget,
      );
      expect(find.text('Étape de prospection'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'pas de sélecteur de chefs de secteur pour le chef de secteur',
      (tester) async {
        await pumpEcran(tester, const ProspectsScreen(), role: Role.cs);
        await tester.tap(find.text('👥 Tout le secteur'));
        await tester.pumpAndSettle();
        expect(find.text('Tous les chefs de secteur'), findsNothing);
        expect(find.byType(BoutonFiltre), findsNothing);
      },
    );
  });

  group('directeur régional', () {
    testWidgets('« Mes prospects » : Prospects, 2 prospects à lui', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.dir);
      expect(find.text('Prospects'), findsOneWidget);
      expect(
        find.text('2 points de vente · potentiel 150 k€/an'),
        findsOneWidget,
      );
      expect(_compteurs(tester), ['1', '1', '0', '0']);
      expect(find.text('Mes prospects'), findsOneWidget); // titre de section
      expect(find.text('👥 Tous les prospects'), findsOneWidget);
      expect(find.text('Carrefour – Paris'), findsOneWidget);
      expect(find.text('Auchan – Rouen'), findsOneWidget);
      expect(find.text('📅 RDV · Mer 11:30'), findsOneWidget);
      expect(find.text('Tous les chefs de secteur'), findsNothing);
    });

    testWidgets('« Tous les prospects » : 23 prospects, sélecteur et filtre', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.dir);
      await tester.tap(find.text('👥 Tous les prospects'));
      await tester.pumpAndSettle();
      expect(
        find.text('23 points de vente · potentiel 2135 k€/an'),
        findsOneWidget,
      );
      expect(_compteurs(tester), ['9', '5', '8', '1']);
      expect(
        find.text('Tous les prospects'),
        findsOneWidget,
      ); // titre de section
      expect(find.text('Tous les chefs de secteur'), findsOneWidget);
      expect(find.byType(BoutonFiltre), findsOneWidget);
      expect(find.text('Classe B · Karim B.'), findsWidgets);
      expect(find.text('Classe A · Nadia H.'), findsWidgets);
    });

    testWidgets('le sélecteur et le compteur du filtre suivent les choix', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.dir);
      await tester.tap(find.text('👥 Tous les prospects'));
      await tester.pumpAndSettle();
      final c = _store(tester);
      c.read(chefsSecteurRetenusProvider.notifier).basculer('Karim B.');
      await tester.pumpAndSettle();
      expect(find.text('Karim B.'), findsOneWidget); // sélecteur
      expect(
        find.text('11 points de vente · potentiel 995 k€/an'),
        findsOneWidget,
      );
      expect(_compteurs(tester), ['3', '3', '4', '1']);
      expect(find.text('1'), findsWidgets); // compteur du bouton de filtres
      c.read(filtreGroupeProvider.notifier).definir(GroupeProspect.enNego);
      await tester.pumpAndSettle();
      expect(find.text('Karim B. · En négo'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // deux filtres actifs
      c.read(chefsSecteurRetenusProvider.notifier).basculer('Nadia H.');
      await tester.pumpAndSettle();
      expect(find.text('Karim B., Nadia H. · En négo'), findsOneWidget);
    });

    testWidgets('le sélecteur et le bouton ouvrent la feuille de filtres', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.dir);
      await tester.tap(find.text('👥 Tous les prospects'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tous les chefs de secteur'));
      await tester.pumpAndSettle();
      expect(find.text('Filtres'), findsOneWidget);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BoutonFiltre));
      await tester.pumpAndSettle();
      expect(find.text('Filtres'), findsOneWidget);
    });
  });

  group('autres profils', () {
    testWidgets('le changement de profil remet les filtres à zéro', (
      tester,
    ) async {
      await pumpEcran(tester, const ProspectsScreen(), role: Role.dir);
      final c = _store(tester);
      c.read(vueProspectsProvider.notifier).choisir(VueProspects.tous);
      c.read(filtreGroupeProvider.notifier).definir(GroupeProspect.rdvPris);
      c.read(chefsSecteurRetenusProvider.notifier).basculer('Karim B.');
      c.read(roleProvider.notifier).choisir(Role.cs);
      expect(c.read(vueProspectsProvider), VueProspects.liste);
      expect(c.read(filtreGroupeProvider), isNull);
      expect(c.read(chefsSecteurRetenusProvider), isEmpty);
    });

    testWidgets(
      'profil sans encadrement : « Mes prospects » et « Timeline », sans prospect',
      (tester) async {
        await pumpEcran(tester, const ProspectsScreen(), role: Role.promoteur);
        expect(find.text('Mes prospects'), findsNWidgets(2));
        expect(find.text('☰ Mes prospects'), findsOneWidget);
        expect(find.text('▥ Timeline'), findsOneWidget);
        expect(
          find.text('0 point de vente · potentiel 0 k€/an'),
          findsOneWidget,
        );
        expect(find.text('Aucun prospect dans cette colonne.'), findsOneWidget);
        await tester.tap(find.text('▥ Timeline'));
        await tester.pumpAndSettle();
        expect(find.text('Timeline'), findsOneWidget); // titre de section
        expect(find.text('Par étape'), findsOneWidget);
      },
    );
  });
}
