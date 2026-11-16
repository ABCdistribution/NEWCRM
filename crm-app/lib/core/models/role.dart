/// Profils de démonstration (maquette : `ROLES`) et univers visuel associé.
library;

/// Rôle simulé par la démo : promoteur, chef de secteur, directeur régional.
enum Role { promoteur, cs, dir }

/// Univers visuel : « sales » (bleu, promoteur) ou « pilot » (violet, encadrement).
enum Univers { sales, pilot }

/// Identité affichée d'un profil de démonstration.
class Profil {
  const Profil({
    required this.role,
    required this.prenom,
    required this.nom,
    required this.initiales,
    required this.libelle,
    required this.pilot,
  });

  final Role role;
  final String prenom;

  /// Nom court affiché et utilisé comme clé de rattachement (« Julien M. »).
  final String nom;
  final String initiales;
  final String libelle;

  /// Vrai pour l'encadrement (chef de secteur, directeur) : univers violet.
  final bool pilot;

  Univers get univers => pilot ? Univers.pilot : Univers.sales;
}

/// Les trois profils de la maquette (`ROLES`).
const Map<Role, Profil> profilsDemo = {
  Role.promoteur: Profil(
    role: Role.promoteur,
    prenom: 'Julien',
    nom: 'Julien M.',
    initiales: 'JM',
    libelle: 'Promoteur',
    pilot: false,
  ),
  Role.cs: Profil(
    role: Role.cs,
    prenom: 'Nadia',
    nom: 'Nadia H.',
    initiales: 'NH',
    libelle: 'Chef de secteur',
    pilot: true,
  ),
  Role.dir: Profil(
    role: Role.dir,
    prenom: 'Cindy',
    nom: 'Cindy R.',
    initiales: 'CR',
    libelle: 'Directeur régional',
    pilot: true,
  ),
};

extension RoleProfil on Role {
  Profil get profil => profilsDemo[this]!;
  Univers get univers => profil.univers;

  /// Maquette : `peutPilot()` (vrai pour le chef de secteur et le directeur).
  bool get peutPilot => profil.pilot;
}
