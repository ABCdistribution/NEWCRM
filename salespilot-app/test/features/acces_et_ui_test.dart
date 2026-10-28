import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salespilot/core/auth/role.dart';
import 'package:salespilot/core/providers.dart';
import 'package:salespilot/core/theme/app_theme.dart';
import 'package:salespilot/features/shell/app_shell.dart';
import 'package:salespilot/features/tournee/tournee_page.dart';
import 'package:salespilot/features/tournee/tournee_repository.dart';
import 'package:salespilot/core/db/app_database.dart';

void main() {
  group('accès aux espaces par rôle (CDC §3.0)', () {
    test('le promoteur, l\'ADV et le Marketing n\'ont qu\'ABC Sales et pas de sélecteur', () {
      for (final r in [Role.commercial, Role.adv, Role.marketing]) {
        expect(r.spaces, {Space.sales}, reason: r.api);
        expect(r.canSwitchSpace, isFalse, reason: r.api);
      }
    });

    test('l\'encadrement, la direction et l\'admin ont les deux espaces et le sélecteur', () {
      for (final r in [Role.chefSecteur, Role.directeurRegional, Role.direction, Role.admin]) {
        expect(r.spaces, {Space.sales, Space.pilot}, reason: r.api);
        expect(r.canSwitchSpace, isTrue, reason: r.api);
      }
    });

    test('les valeurs de rôle de l\'API sont reconnues', () {
      expect(Role.fromApi('CHEF_SECTEUR'), Role.chefSecteur);
      expect(Role.fromApi('DIRECTEUR_REGIONAL'), Role.directeurRegional);
      expect(Role.fromApi('ADV'), Role.adv);
    });

    test('un promoteur ne peut pas sélectionner ABC Pilot, un chef de secteur le peut', () {
      final promoteur = ProviderContainer(overrides: [currentRoleProvider.overrideWithValue(Role.commercial)]);
      addTearDown(promoteur.dispose);
      promoteur.read(spaceProvider.notifier).select(Space.pilot);
      expect(promoteur.read(spaceProvider), Space.sales);

      final cs = ProviderContainer(overrides: [currentRoleProvider.overrideWithValue(Role.chefSecteur)]);
      addTearDown(cs.dispose);
      cs.read(spaceProvider.notifier).select(Space.pilot);
      expect(cs.read(spaceProvider), Space.pilot);
    });

    test('ABC Sales est l\'espace d\'ouverture pour tous', () {
      final c = ProviderContainer(overrides: [currentRoleProvider.overrideWithValue(Role.admin)]);
      addTearDown(c.dispose);
      expect(c.read(spaceProvider), Space.sales);
    });
  });

  group('état d\'une visite planifiée dans la tournée du jour', () {
    PlanningItem planning({bool fait = false}) => PlanningItem(
          id: 'p1',
          datePassage: DateTime(2026, 10, 26, 9),
          fait: fait,
          client: const MagasinRef(id: 'c1', codeAs400: '1', enseigne: 'Carrefour'),
        );
    VisiteDraft draft(String state) => VisiteDraft(
          id: 'd1',
          userId: 'u1',
          planningId: 'p1',
          libelle: '',
          state: state,
          dataJson: '{}',
          createdAt: DateTime(2026, 10, 26),
          updatedAt: DateTime(2026, 10, 26),
        );

    test('sans saisie : à faire', () => expect(etatDe(planning(), const []), EtatVisite.aFaire));
    test('brouillon : en cours', () => expect(etatDe(planning(), [draft('brouillon')]), EtatVisite.enCours));
    test('terminée : en attente d\'envoi', () => expect(etatDe(planning(), [draft('terminee')]), EtatVisite.enAttenteEnvoi));
    test('synchronisée : réalisée', () => expect(etatDe(planning(), [draft('synchronisee')]), EtatVisite.realisee));
    test('soldée côté serveur : réalisée', () => expect(etatDe(planning(fait: true), const []), EtatVisite.realisee));
  });

  group('pastille d\'éléments en attente (CDC §4.3)', () {
    Future<Color> couleur(WidgetTester t, {required int count, DateTime? oldest}) async {
      await t.pumpWidget(ProviderScope(
        overrides: [
          pendingCountProvider.overrideWith((ref) => Stream.value(count)),
          oldestPendingProvider.overrideWith((ref) => Stream.value(oldest)),
        ],
        child: const MaterialApp(home: Scaffold(body: PendingBadge())),
      ));
      await t.pump();
      return t.widget<Icon>(find.byType(Icon)).color!;
    }

    testWidgets('rien en attente : vert, sans nombre', (t) async {
      expect(await couleur(t, count: 0), StatusColors.ok);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('en attente depuis peu : neutre, avec le nombre exact', (t) async {
      final c = await couleur(t, count: 3, oldest: DateTime.now().subtract(const Duration(hours: 2)));
      expect(c, Colors.white70);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('plus de 24 h : orange', (t) async {
      expect(await couleur(t, count: 2, oldest: DateTime.now().subtract(const Duration(hours: 30))), StatusColors.warn);
    });

    testWidgets('plus de 48 h : rouge', (t) async {
      expect(await couleur(t, count: 5, oldest: DateTime.now().subtract(const Duration(hours: 50))), StatusColors.alert);
    });
  });
}
