import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/auth/session.dart';
import 'core/db/base_provider.dart';
import 'core/db/cle_base.dart';
import 'core/db/envois_base.dart';
import 'core/db/ouverture_base.dart';
import 'core/state/state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final base = await ouvrirBaseLocale();
  // Les visites en cours ne survivent pas à un redémarrage : leurs photos restées sans visite sont effacées, sinon une
  // nouvelle visite qui reprend le même numéro les récupérerait.
  await base.purgerPhotosOrphelines();
  // Session enregistrée : relue sans réseau, l'utilisateur retrouve directement son application.
  final utilisateur = await const StockageSession(
    StockageSecretSysteme(),
  ).lire();
  runApp(
    ProviderScope(
      overrides: [
        baseLocaleProvider.overrideWithValue(base),
        sessionProvider.overrideWith(() => SessionNotifier(utilisateur)),
        roleProvider.overrideWith(() => RoleNotifier(utilisateur?.role)),
      ],
      child: const CrmApp(),
    ),
  );
}
