import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// Base locale ouverte au démarrage (`main.dart` la fournit). Non fournie dans les tests qui n'en ont pas besoin.
final baseLocaleProvider = Provider<AppDatabase>(
  (ref) => throw StateError(
    "La base locale n'est pas ouverte : la fournir par ProviderScope.overrides.",
  ),
);
