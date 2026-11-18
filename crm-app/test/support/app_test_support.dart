import 'package:crm_app/app.dart';
import 'package:crm_app/core/auth/session.dart';
import 'package:crm_app/core/models/models.dart';
import 'package:crm_app/core/state/state.dart';
import 'package:crm_app/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Charge la police Inter de l'application : sans elle, les tests dessinent le texte en Ahem (chaque lettre est un
/// carré de la taille de la police), ce qui rend les lignes denses deux fois plus larges que sur un téléphone et
/// provoque de faux débordements. `pumpEcran` et `lancerApp` l'appellent ; un test qui monte sa propre `MaterialApp`
/// peut l'appeler dans un `setUpAll`.
Future<void> chargerInter() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final police = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  await police.load();
}

bool _interChargee = false;

/// Charge Inter une seule fois par fichier de test (hors de la zone simulée du test, où un chargement réel bloquerait).
Future<void> assurerInter(WidgetTester tester) async {
  if (_interChargee) return;
  await tester.runAsync(chargerInter);
  _interChargee = true;
}

/// Simule un téléphone de 390 × 780 dp (la taille de la maquette) pour éviter de faux débordements.
void utiliserTelephone(
  WidgetTester tester, {
  Size taille = const Size(390, 780),
}) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = taille * 3;
  addTearDown(tester.view.reset);
}

/// Monte un écran seul dans une `MaterialApp` du bon univers, avec le profil `role` déjà choisi.
///
/// ```dart
/// await pumpEcran(tester, const ClientsScreen(), role: Role.cs);
/// ```
/// `overrides` : providers à remplacer (ex. un store modifié).
Future<void> pumpEcran(
  WidgetTester tester,
  Widget ecran, {
  Role role = Role.promoteur,
  List<Override> overrides = const [],
}) async {
  await assurerInter(tester);
  utiliserTelephone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roleProvider.overrideWith(() => RoleNotifier(role)),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.pour(role.univers),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ecran,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Mode démonstration actif dès le lancement : l'application démarre sur l'écran de choix du profil de démo
/// (en production elle démarre sur la connexion).
class ModeDemoActif extends ModeDemoNotifier {
  @override
  bool build() => true;
}

/// Crée un conteneur Riverpod avec le profil `role` choisi, pour tester le store sans interface.
ProviderContainer conteneurPour(Role role) {
  final c = ProviderContainer(
    overrides: [roleProvider.overrideWith(() => RoleNotifier(role))],
  );
  addTearDown(c.dispose);
  return c;
}

/// Lance l'application complète (écran « Démo » puis coquille) avec le profil `role` choisi : pour tester une navigation
/// de bout en bout, une feuille ouverte par `AppRoutes` ou un parcours sur plusieurs écrans.
///
/// ```dart
/// await lancerApp(tester, Role.cs);
/// final ctx = tester.element(find.byType(ShellScreen));   // contexte de la coquille, pour `AppRoutes.xxx(ctx, …)`
/// ```
/// `overrides` : providers à remplacer (ex. le questionnaire de fin de visite, vide sans copie locale ni réseau).
Future<void> lancerApp(
  WidgetTester tester,
  Role role, {
  List<Override> overrides = const [],
}) async {
  await assurerInter(tester);
  utiliserTelephone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        modeDemoProvider.overrideWith(ModeDemoActif.new),
        ...overrides,
      ],
      child: const CrmApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(role.profil.libelle));
  await tester.pumpAndSettle();
}
