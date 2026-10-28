import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // Pas de nouvel essai automatique des fournisseurs en erreur : les erreurs réseau sont gérées à l'écran
    // (copie locale, bouton « Réessayer »).
    ProviderScope(retry: (_, _) => null, child: const SalesPilotApp()),
  );
}
