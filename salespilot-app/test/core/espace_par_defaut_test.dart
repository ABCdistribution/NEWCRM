import 'package:flutter_test/flutter_test.dart';
import 'package:salespilot/core/auth/role.dart';

void main() {
  test("l'encadrement ouvre ABC Pilot, les autres rôles ABC Sales", () {
    for (final r in [Role.chefSecteur, Role.directeurRegional, Role.direction, Role.admin]) {
      expect(r.defaultSpace, Space.pilot, reason: r.api);
    }
    for (final r in [Role.commercial, Role.adv, Role.marketing]) {
      expect(r.defaultSpace, Space.sales, reason: r.api);
    }
  });

  test("l'espace par défaut fait toujours partie des espaces autorisés du rôle", () {
    for (final r in Role.values) {
      expect(r.spaces, contains(r.defaultSpace), reason: r.api);
    }
  });
}
