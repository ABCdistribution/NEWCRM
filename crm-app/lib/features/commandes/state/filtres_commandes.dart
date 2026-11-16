import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/state/state.dart';

/// « Afficher » : mes commandes ou toutes celles du périmètre (`portee`).
enum PorteeCommandes { mes, toutes }

/// Type de commande (`type`) : toutes, EDI ou saisies dans l'appli.
enum TypeCommande { tous, edi, appli }

/// État de livraison filtré (`etat`).
enum EtatCommande {
  tous,
  pasLivree,
  livree;

  /// Le statut de livraison correspondant, nul pour « Tous les états ».
  StatutLivraison? get statut => switch (this) {
    EtatCommande.tous => null,
    EtatCommande.pasLivree => StatutLivraison.pasLivree,
    EtatCommande.livree => StatutLivraison.livree,
  };
}

/// Période (`periode`) : toutes les dates, aujourd'hui, 7 derniers jours.
enum PeriodeCommandes { toutes, jour, semaine }

/// Recherche et filtres de la liste des commandes (maquette : `S.cf`).
@immutable
class FiltresCommandes {
  const FiltresCommandes({
    required this.portee,
    this.q = '',
    this.etat = EtatCommande.tous,
    this.periode = PeriodeCommandes.toutes,
    this.type = TypeCommande.tous,
  });

  final PorteeCommandes portee;
  final String q;
  final EtatCommande etat;
  final PeriodeCommandes periode;
  final TypeCommande type;

  FiltresCommandes copyWith({
    PorteeCommandes? portee,
    String? q,
    EtatCommande? etat,
    PeriodeCommandes? periode,
    TypeCommande? type,
  }) => FiltresCommandes(
    portee: portee ?? this.portee,
    q: q ?? this.q,
    etat: etat ?? this.etat,
    periode: periode ?? this.periode,
    type: type ?? this.type,
  );

  /// Nombre de filtres actifs (pastille du bouton de filtres) : tout ce qui s'écarte des valeurs par défaut du rôle.
  int nbActifs(Role role) =>
      (portee != porteeParDefaut(role) ? 1 : 0) +
      (etat != EtatCommande.tous ? 1 : 0) +
      (periode != PeriodeCommandes.toutes ? 1 : 0) +
      (type != TypeCommande.tous ? 1 : 0);
}

/// Le promoteur voit ses commandes d'abord, l'encadrement toutes celles de son périmètre.
PorteeCommandes porteeParDefaut(Role role) =>
    role == Role.promoteur ? PorteeCommandes.mes : PorteeCommandes.toutes;

class FiltresCommandesNotifier extends Notifier<FiltresCommandes> {
  @override
  FiltresCommandes build() {
    final role = ref.watch(roleActifProvider);
    return FiltresCommandes(portee: porteeParDefaut(role));
  }

  void maj(FiltresCommandes Function(FiltresCommandes f) f) => state = f(state);

  /// `cf-reset` : portée par défaut, état, période et type remis à « tous » (la recherche est conservée).
  void reinitialiser() {
    final role = ref.read(roleActifProvider);
    state = FiltresCommandes(portee: porteeParDefaut(role), q: state.q);
  }
}

final filtresCommandesProvider =
    NotifierProvider<FiltresCommandesNotifier, FiltresCommandes>(
      FiltresCommandesNotifier.new,
    );
