/// Rôles de la plateforme, avec les valeurs exactes renvoyées par l'API.
enum Role {
  commercial('COMMERCIAL', 'Promoteur des ventes'),
  chefSecteur('CHEF_SECTEUR', 'Chef de secteur'),
  directeurRegional('DIRECTEUR_REGIONAL', 'Directeur régional'),
  direction('DIRECTION', 'Direction'),
  admin('ADMIN', 'Administrateur'),
  adv('ADV', 'ADV'),
  marketing('MARKETING', 'Marketing');

  const Role(this.api, this.label);

  final String api;
  final String label;

  static Role fromApi(String? value) =>
      Role.values.firstWhere((r) => r.api == value, orElse: () => Role.commercial);
}

/// Les deux espaces de l'application, comme sur le web (CDC §3.0).
enum Space {
  sales('ABC Sales', 'Terrain'),
  pilot('ABC Pilot', 'Pilotage');

  const Space(this.label, this.subtitle);

  final String label;
  final String subtitle;
}

extension RoleAccess on Role {
  /// ABC Sales est accessible à tous les rôles ; ABC Pilot est réservé à l'encadrement (mêmes règles que le web).
  Set<Space> get spaces => switch (this) {
        Role.chefSecteur || Role.directeurRegional || Role.direction || Role.admin => {Space.sales, Space.pilot},
        _ => {Space.sales},
      };

  /// Le sélecteur d'espace n'existe que pour les rôles qui ont accès aux deux espaces.
  bool get canSwitchSpace => spaces.length > 1;

  /// Seul le promoteur est limité à son portefeuille par l'API ; les autres rôles consultent en lecture.
  bool get isFieldPromoter => this == Role.commercial;
}
