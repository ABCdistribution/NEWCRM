/// Droits d'écriture sur un magasin pour le rôle connecté.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../../../core/logic/dates.dart';
import '../logic/actions_magasin.dart';

/// Connecté, vrai pour les rôles dont l'API accepte les notes, contacts, périodicité et journal d'un magasin ; faux en
/// démonstration, où rien n'est envoyé.
final peutEcrireMagasinProvider = Provider<bool>(
  (ref) =>
      DemoTemps.reel &&
      peutEcrireMagasin(ref.watch(sessionProvider.select((u) => u?.roleApi))),
);
