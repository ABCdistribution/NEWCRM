/// Périmètre de données par rôle : maquette `visM`, `visP`, `peutPilot`.
library;

import '../models/models.dart';

/// Un client est visible du promoteur s'il est dans son portefeuille (promoteur « j »),
/// du chef de secteur s'il est dans son secteur (« s1 »), du directeur toujours.
bool visM(Role role, Magasin m) =>
    role == Role.dir ||
    (role == Role.cs ? m.secteurId == 's1' : m.promoId == 'j');

/// Un prospect est visible du directeur (toute la région) et du chef de secteur (son secteur) ;
/// jamais du promoteur.
bool visP(Role role, Prospect p) =>
    role == Role.dir || (role == Role.cs && p.secteurId == 's1');

/// Vrai pour l'encadrement (chef de secteur, directeur) : univers « pilot ».
bool peutPilot(Role role) => role.peutPilot;
