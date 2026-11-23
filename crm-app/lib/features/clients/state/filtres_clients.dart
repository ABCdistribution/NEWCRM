/// État propre au lot « clients » : recherche, portée, enseigne et tri de la liste des clients (maquette : `S.mf`),
/// et calcul de la liste affichée (`baseMagasins`, `magasinsListe`).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data.dart';
import '../../../core/logic/logic.dart';
import '../../../core/models/models.dart';
import '../../../core/state/state.dart';

/// Quels clients afficher : « mes clients » (portefeuille du promoteur, toute la société pour le directeur)
/// ou « tous » (secteur du promoteur, région du directeur). Maquette : `f.portee` = `mes` ou `tous`.
enum PorteeClients { mes, tous }

/// Tri de la liste : par nom (A → Z) ou par classification (A++ → G).
enum TriClients { nom, classe }

/// Portée par défaut : le promoteur voit son portefeuille, l'encadrement tout son périmètre (`defautPortee`).
PorteeClients porteeParDefaut(Role role) =>
    role == Role.promoteur ? PorteeClients.mes : PorteeClients.tous;

/// Filtres de la liste des clients (`S.mf` : `q`, `portee`, `tri`, `ens`).
@immutable
class FiltresClients {
  const FiltresClients({
    required this.portee,
    this.q = '',
    this.tri = TriClients.nom,
    this.ens,
  });

  /// Texte recherché dans le nom et l'adresse.
  final String q;
  final PorteeClients portee;
  final TriClients tri;

  /// Enseigne choisie ; nulle = « Toutes les enseignes ».
  final String? ens;

  FiltresClients copyWith({
    String? q,
    PorteeClients? portee,
    TriClients? tri,
  }) => FiltresClients(
    q: q ?? this.q,
    portee: portee ?? this.portee,
    tri: tri ?? this.tri,
    ens: ens,
  );

  /// Même filtres avec une autre enseigne (`null` pour toutes).
  FiltresClients avecEnseigne(String? enseigne) =>
      FiltresClients(q: q, portee: portee, tri: tri, ens: enseigne);
}

/// Filtres de la liste des clients ; revient à l'état initial quand le profil change (comme `etatInitial`).
class FiltresClientsNotifier extends Notifier<FiltresClients> {
  @override
  FiltresClients build() =>
      FiltresClients(portee: porteeParDefaut(ref.watch(roleActifProvider)));

  void rechercher(String q) => state = state.copyWith(q: q);

  void choisirPortee(PorteeClients portee) =>
      state = state.copyWith(portee: portee);

  void choisirTri(TriClients tri) => state = state.copyWith(tri: tri);

  void choisirEnseigne(String? enseigne) =>
      state = state.avecEnseigne(enseigne);

  /// « Réinitialiser » (`mag-reset`) : portée par défaut, tri par nom, toutes les enseignes ; la recherche est conservée.
  void reinitialiser() => state = FiltresClients(
    q: state.q,
    portee: porteeParDefaut(ref.read(roleActifProvider)),
  );
}

final filtresClientsProvider =
    NotifierProvider<FiltresClientsNotifier, FiltresClients>(
      FiltresClientsNotifier.new,
    );

/// Clients parmi lesquels on cherche (`baseMagasins`) : pour le directeur « mes » = toute la société (région et
/// hors région), sinon le portefeuille ; « tous » = secteur ou région.
List<Magasin> baseClients(CrmEtat etat, PorteeClients portee) {
  if (etat.role == Role.dir) {
    return portee == PorteeClients.mes
        ? [...etat.tousMagasins, ...autresClientsActuels()]
        : etat.tousMagasins;
  }
  return portee == PorteeClients.mes ? etat.magasins : etat.tousMagasins;
}

/// Nombre de clients de la portée « mes » (`nbMesClients`).
int nbClientsMes(CrmEtat etat) => baseClients(etat, PorteeClients.mes).length;

/// Liste affichée (`magasinsListe`) : recherche dans « nom adresse », enseigne, puis tri (classe puis nom, ou nom).
List<Magasin> clientsFiltres(CrmEtat etat, FiltresClients f) {
  final q = f.q.toLowerCase();
  final retenus = baseClients(etat, f.portee).where(
    (m) =>
        '${m.nom} ${m.adresse}'.toLowerCase().contains(q) &&
        (f.ens == null || m.enseigne == f.ens),
  );
  return triStable(retenus, (a, b) {
    if (f.tri == TriClients.classe) {
      final c = classeRang(a.classe) - classeRang(b.classe);
      if (c != 0) return c;
    }
    return compareFr(a.nom, b.nom);
  });
}

/// Enseignes proposées dans la feuille de filtres : celles de la base courante, triées.
List<String> enseignesDe(Iterable<Magasin> clients) {
  final noms = {for (final m in clients) m.enseigne}.toList();
  noms.sort(compareFr);
  return noms;
}

/// Nombre de filtres actifs affiché sur la pastille du bouton (`nbF`) : tri, portée (sauf chef de secteur,
/// qui n'a pas ce choix) et enseigne.
int nbFiltresClients(Role role, FiltresClients f) =>
    (f.tri != TriClients.nom ? 1 : 0) +
    (role != Role.cs && f.portee != porteeParDefaut(role) ? 1 : 0) +
    (f.ens != null ? 1 : 0);

/// Sous-titre de l'entête : portée, nombre de clients et tri.
String sousTitreClients(Role role, FiltresClients f, int nb) {
  final portee = switch (role) {
    Role.promoteur =>
      f.portee == PorteeClients.mes
          ? 'Mon portefeuille'
          : 'Tous les clients du secteur',
    Role.cs => 'Clients de votre secteur',
    Role.dir =>
      f.portee == PorteeClients.mes
          ? 'Tous les clients'
          : 'Clients de ma région',
  };
  final tri = f.tri == TriClients.classe ? ' · triés par classe' : '';
  return '$portee · ${pluriel(nb, 'client')}$tri';
}

/// Clients affichés dans l'onglet (liste filtrée et triée).
final clientsAffichesProvider = Provider<List<Magasin>>(
  (ref) =>
      clientsFiltres(ref.watch(crmProvider), ref.watch(filtresClientsProvider)),
);
