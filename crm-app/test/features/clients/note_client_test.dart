import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/nav/nav.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/features/clients/note_client_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_support.dart';
import 'aide_clients.dart';

/// Dialogue « Nouvelle note » d'un client : modale `note` l.1836-1838, action `note-ok` l.2032.
void main() {
  const toast = 'Note enregistrée. Envoi dès que le réseau le permet.';

  /// Écran vide avec un bouton qui ouvre le dialogue par `AppRoutes`, comme depuis une fiche.
  Future<void> monter(WidgetTester tester, Role role) async {
    await pumpEcran(
      tester,
      Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => AppRoutes.noteClient(ctx, 'm1'),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
      role: role,
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  for (final role in Role.values) {
    group(role.profil.libelle, () {
      testWidgets('le dialogue et ses textes', (tester) async {
        await monter(tester, role);
        expect(find.byType(NoteClientDialog), findsOneWidget);
        expect(find.text('Nouvelle note'), findsOneWidget);
        expect(find.text('Votre remarque'), findsOneWidget);
        expect(find.text('Annuler'), findsOneWidget);
        expect(find.text('Enregistrer'), findsOneWidget);
        // Zone de texte d'au moins 72 px, déjà active (`autofocus`).
        expect(tester.getSize(find.byType(TextField)).height, 72);
        expect(
          tester.widget<TextField>(find.byType(TextField)).autofocus,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Annuler ferme le dialogue sans toast', (tester) async {
        await monter(tester, role);
        await tester.enterText(find.byType(TextField), 'Une remarque');
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(find.byType(NoteClientDialog), findsNothing);
        expect(find.text(toast), findsNothing);
      });

      testWidgets(
        'Enregistrer : ferme, affiche le toast, ne touche pas au store',
        (tester) async {
          await monter(tester, role);
          final avant = conteneurDe(tester).read(crmProvider);
          await tester.enterText(
            find.byType(TextField),
            '  Chef de rayon à rappeler  ',
          );
          await tester.tap(find.text('Enregistrer'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(NoteClientDialog), findsNothing);
          expect(find.text(toast), findsOneWidget);
          // La maquette ne range pas la note d'un client dans une timeline : rien ne change dans le store.
          expect(
            identical(conteneurDe(tester).read(crmProvider), avant),
            isTrue,
          );
          await laisserPasserToast(tester);
          expect(find.text(toast), findsNothing);
        },
      );

      testWidgets(
        'une note vide n’est pas enregistrée : le dialogue reste ouvert',
        (tester) async {
          await monter(tester, role);
          await tester.tap(find.text('Enregistrer'));
          await tester.pumpAndSettle();
          expect(find.byType(NoteClientDialog), findsOneWidget);
          expect(find.text(toast), findsNothing);

          // Des espaces seuls ne comptent pas non plus ; la zone est vidée.
          await tester.enterText(find.byType(TextField), '    ');
          await tester.tap(find.text('Enregistrer'));
          await tester.pumpAndSettle();
          expect(find.byType(NoteClientDialog), findsOneWidget);
          expect(find.text(toast), findsNothing);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
        },
      );
    });
  }

  testWidgets('un appui sur le voile ferme le dialogue', (tester) async {
    await monter(tester, Role.promoteur);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    expect(find.byType(NoteClientDialog), findsNothing);
  });
}
